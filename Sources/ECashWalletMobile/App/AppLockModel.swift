// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse   // @Observable must drive the Android (Compose) UI in Fuse
import WalletService

/// App-lock state: requires device authentication (biometric/passcode) to enter the app on a
/// cold launch and after returning from the background (CLAUDE.md §7). Toggleable in Settings.
///
/// Pure + testable: device auth and persistence are injected seams, so the lock state machine is
/// unit-tested without LocalAuthentication / BiometricPrompt / UserDefaults. `AppState` wires the
/// real `DeviceAuth` + `UserDefaults`.
///
/// Pass-through note: `DeviceAuth` returns true when the device has no biometric/passcode enrolled
/// (nothing to check against). So enabling app-lock on a credential-less device/emulator is a
/// no-op gate — correct, since such a device can't be protected by one.
@MainActor
@Observable
final class AppLockModel {
    /// Whether the gate is armed (persisted). Default ON for a wallet.
    private(set) var enabled: Bool
    /// Whether the app is currently locked (auth required to proceed).
    private(set) var isLocked: Bool
    /// True while an auth prompt is in flight (drives the Unlock button's spinner; re-entrancy guard).
    private(set) var authenticating = false
    /// How long the app may sit in the background before it re-locks, in seconds (persisted).
    /// `0` = lock immediately. A short grace lets you pop out to copy an address / check a faucet
    /// and come right back without re-authenticating. Configurable in Settings.
    private(set) var graceSeconds: Int

    private let authenticate: (String) async -> Bool
    private let persist: (Bool) -> Void
    private let persistGrace: (Int) -> Void
    /// Wall-clock moment the app last left the foreground; `nil` on a cold launch. Used to measure
    /// the grace window on return. Not persisted — only a real in-session backgrounding counts.
    private var backgroundedAt: Date?

    init(enabled: Bool,
         startLocked: Bool,
         graceSeconds: Int,
         authenticate: @escaping (String) async -> Bool,
         persist: @escaping (Bool) -> Void,
         persistGrace: @escaping (Int) -> Void) {
        self.enabled = enabled
        self.isLocked = startLocked
        self.graceSeconds = graceSeconds
        self.authenticate = authenticate
        self.persist = persist
        self.persistGrace = persistGrace
    }

    /// Toggle the setting (from Settings). Turning it ON takes effect on the next background/launch
    /// — it never locks you out mid-session. Turning it OFF clears any active lock immediately.
    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        persist(on)
        if !on { isLocked = false }
    }

    /// Set the background grace window (from Settings) and persist it.
    func setGraceSeconds(_ seconds: Int) {
        guard seconds != graceSeconds else { return }
        graceSeconds = seconds
        persistGrace(seconds)
    }

    /// Note the moment the app leaves the foreground (scenePhase → background). Does NOT lock yet —
    /// the grace window is measured on return, so a quick round-trip skips re-auth.
    func markBackgrounded() {
        guard enabled else { return }
        backgroundedAt = Date()
    }

    /// On returning to the foreground (scenePhase → active), lock only if the app was armed AND sat
    /// in the background longer than the grace window. A return within the window stays unlocked.
    func applyForegroundLock() {
        guard enabled, let leftAt = backgroundedAt else { return }
        backgroundedAt = nil
        if Date().timeIntervalSince(leftAt) >= Double(graceSeconds) {
            isLocked = true
        }
    }

    /// Attempt to clear the lock via device auth. No-op if already unlocked or mid-prompt
    /// (so the auto-attempt on appear and a manual Unlock tap can't double-prompt).
    func unlock() async {
        guard isLocked, !authenticating else { return }
        authenticating = true
        let ok = await authenticate("Unlock eCash.com Wallet")
        if ok { isLocked = false }
        authenticating = false
    }
}
