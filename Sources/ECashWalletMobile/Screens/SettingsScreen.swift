// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// App settings. Native inset-grouped `List`; currently a working appearance toggle + version.
/// Per-wallet info, per-network backends, app-lock, and currency land in the Settings slice
/// (PLAN.md Slice 7).
struct SettingsScreen: View {
    @AppStorage("appearance") var appearance = ""
    @Environment(AppState.self) var app
    @State var showBackup = false   // not `private` — Fuse bridges @State (skip-fuse rule)

    var body: some View {
        List {
            Section("Security") {
                if let wallet = app.selectedWallet {
                    Button { showBackup = true } label: {
                        HStack {
                            Text("Back up recovery phrase", bundle: .module, comment: "settings security row")
                                .textStyle(.body)
                                .foregroundStyle(Theme.Colors.text0)
                            Spacer()
                            (wallet.isBackedUp
                                ? Text("Backed up", bundle: .module, comment: "wallet backup status")
                                : Text("Not backed up", bundle: .module, comment: "wallet backup status"))
                                .textStyle(.xs)
                                .foregroundStyle(wallet.isBackedUp ? Theme.Colors.positive : Theme.Colors.warning)
                        }
                    }
                }
                Toggle("Require unlock", isOn: Binding(
                    get: { app.appLock.enabled },
                    set: { app.appLock.setEnabled($0) }))
                Text("Ask for Face ID, fingerprint, or your passcode when opening the app.",
                     bundle: .module, comment: "require-unlock toggle explainer")
                    .textStyle(.xs)
                    .foregroundStyle(Theme.Colors.text2)
                // Grace window before re-locking — so popping out to copy an address and coming
                // right back doesn't re-prompt. Only relevant while the lock is armed.
                if app.appLock.enabled {
                    Picker("Auto-lock", selection: Binding(
                        get: { app.appLock.graceSeconds },
                        set: { app.appLock.setGraceSeconds($0) })) {
                        Text("Immediately", bundle: .module, comment: "auto-lock: no grace period").tag(0)
                        Text("After 10 seconds", bundle: .module, comment: "auto-lock grace option").tag(10)
                        Text("After 30 seconds", bundle: .module, comment: "auto-lock grace option").tag(30)
                        Text("After 1 minute", bundle: .module, comment: "auto-lock grace option").tag(60)
                        Text("After 5 minutes", bundle: .module, comment: "auto-lock grace option").tag(300)
                    }
                }
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System", bundle: .module, comment: "appearance: follow system").tag("")
                    Text("Light", bundle: .module, comment: "appearance: light mode").tag("light")
                    Text("Dark", bundle: .module, comment: "appearance: dark mode").tag("dark")
                }
            }
            Section("About") {
                Text(versionString)
                    .textStyle(.sm)
                    .foregroundStyle(Theme.Colors.text1)
                NavigationLink {
                    LicensesScreen()
                } label: {
                    Text("Open-source licenses", bundle: .module, comment: "settings row → attributions")
                        .textStyle(.body)
                        .foregroundStyle(Theme.Colors.text0)
                }
            }
            // Dev affordance — the iOS Keychain survives app deletion, so this is the reliable wipe
            // for repeated testing. Returns to the empty state. (Gate behind a debug flag later.)
            Section("Developer") {
                Button { app.wipeAllWallets() } label: {
                    Text("Reset all wallet data", bundle: .module, comment: "developer reset button")
                        .textStyle(.body)
                        .foregroundStyle(Theme.Colors.negative)
                }
                Text("Wipes every wallet from the Keychain + storage on this device.",
                     bundle: .module, comment: "developer reset explainer")
                    .textStyle(.xs)
                    .foregroundStyle(Theme.Colors.text2)
            }
        }
        .groupedListStyle()
        .navigationTitle(Text("Settings", bundle: .module, comment: "settings screen title"))
        .fullScreenFlow(isPresented: $showBackup) {
            if let vm = app.makeBackupViewModel() {
                BackupFlowView(viewModel: vm)
            }
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "eCash.com Wallet \(version) (\(build))"
    }
}
