// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

#if !SKIP_BRIDGE

import Foundation
import SkipKeychain

/// Per-wallet secure storage for the ONE secret we ever persist: the mnemonic
/// (Golden Rules §2/§5). Keyed by `walletId`. NEVER store xprv or
/// private descriptors here — those are derived from the mnemonic at runtime and dropped.
/// `public` + `// SKIP @nobridge`: `WalletManager` references the protocol and constructs the
/// concrete stores cross-file (needs public for the transpiled Kotlin to resolve them), but the
/// mnemonic-handling seam must never reach the JNI bridge (§2).
// SKIP @nobridge
public protocol KeyStore: AnyObject {
    func saveMnemonic(_ mnemonic: String, walletId: String) throws
    func loadMnemonic(walletId: String) throws -> String?
    func deleteMnemonic(walletId: String) throws
}

/// Real implementation: SkipKeychain → iOS Keychain (`WhenUnlockedThisDeviceOnly`, NOT synced
/// to iCloud) / Android Keystore-backed storage. Verified by integration tests on device (§11),
/// not Robolectric.
// SKIP @nobridge
public final class KeychainKeyStore: KeyStore {
    private let keychain = Keychain.shared

    public init() {}

    private func key(_ walletId: String) -> String { "ecashwallet.mnemonic.\(walletId)" }

    public func saveMnemonic(_ mnemonic: String, walletId: String) throws {
        try keychain.set(mnemonic, forKey: key(walletId), access: .unlockedThisDeviceOnly)
    }

    public func loadMnemonic(walletId: String) throws -> String? {
        try keychain.string(forKey: key(walletId))
    }

    public func deleteMnemonic(walletId: String) throws {
        try keychain.removeValue(forKey: key(walletId))
    }
}

/// In-memory KeyStore for fast unit tests — never touches the real Keychain (Robolectric-safe).
// SKIP @nobridge
public final class InMemoryKeyStore: KeyStore {
    private var storage: [String: String] = [:]

    public init() {}

    public func saveMnemonic(_ mnemonic: String, walletId: String) throws {
        storage[walletId] = mnemonic
    }

    public func loadMnemonic(walletId: String) throws -> String? {
        storage[walletId]
    }

    public func deleteMnemonic(walletId: String) throws {
        storage[walletId] = nil
    }
}

#endif // !SKIP_BRIDGE — bridged module: bodies excluded from the bridge compile
