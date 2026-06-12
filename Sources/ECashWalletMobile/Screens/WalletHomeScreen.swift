// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WalletService

/// The selected wallet's home: identity (label + network badge), live balance with sync state,
/// and the "not backed up" nudge. Syncs on appear and on manual refresh. Receive / Send arrive next.
struct WalletHomeScreen: View {
    @Environment(AppState.self) var app
    @State var showReceive = false   // not `private` — Fuse bridges @State to Compose (skip-fuse rule)
    @State var showSend = false

    var body: some View {
        ZStack {
            Theme.Colors.bg0.ignoresSafeArea()
            if let wallet = app.selectedWallet {
                // Scrollable: balance + actions + activity rows can exceed the screen, and a fixed
                // (non-scrolling) VStack with flexible children overflowed into an infinite Compose
                // layout recursion on Android.
                ScrollView {
                    content(for: wallet)
                }
            } else {
                PlaceholderScreen(heading: "Your wallet", note: "No wallet selected.")
            }
        }
        .navigationTitle("Wallet")
        // Sync the selected wallet against its backend when Home appears (cached balance shows first).
        .task { await app.sync() }
        // Receive is a modal sheet (grab-an-address-and-dismiss), not a navigation push.
        .sheet(isPresented: $showReceive) { ReceiveScreen() }
        // Send is a full-screen cover — a focused, multi-step money flow, not a peek-and-dismiss.
        .fullScreenFlow(isPresented: $showSend) {
            if let vm = app.makeSendViewModel() {
                SendScreen(viewModel: vm)
            }
        }
    }

    @ViewBuilder
    private func content(for wallet: ManagedWallet) -> some View {
        let params = NetworkRegistry.params(for: wallet.network)
        VStack(spacing: Theme.Space.x6) {
            VStack(spacing: Theme.Space.x2) {
                Text(wallet.label)
                    .textStyle(.sm)
                    .foregroundStyle(Theme.Colors.text1)
                NetworkBadge(name: params.displayName, isMainnet: wallet.network.isMainnet)
            }

            VStack(spacing: Theme.Space.x1) {
                // Live balance. JetBrains Mono is already fixed-width, so no `.monospacedDigit()`
                // (also unavailable in SkipUI). The unit label (sBTC/tBTC/BTC) comes from the network.
                Text(app.balance.formattedCoin())
                    .font(.jbMono(36, .medium))
                    .foregroundStyle(Theme.Colors.text0)
                Text(params.unitLabel)
                    .textStyle(.overline)
                    .foregroundStyle(Theme.Colors.text2)
                syncStatus
                    .padding(.top, Theme.Space.x1)
            }

            actionRow

            if !wallet.isBackedUp {
                backupNudge
            }

            recentActivity
        }
        .padding(Theme.Space.gutter)
        .padding(.top, Theme.Space.x8)
    }

    /// Recent-activity preview — the latest few transactions; the full history lives on the
    /// Activity tab. Empty wallets get a quiet hint. Layout discipline (Android Compose): boring
    /// `TxRow`s in a plain VStack, ONE section-level `maxWidth` frame (same pattern as
    /// `backupNudge`, proven stable) — no `Spacer`, no per-row flexible children. "See all" is
    /// intentionally absent: `MainTabView` owns its tab selection locally, so a programmatic jump
    /// to the Activity tab needs a verified construct first.
    @ViewBuilder
    private var recentActivity: some View {
        if app.transactions.isEmpty {
            Text("No transactions yet")
                .textStyle(.xs)
                .foregroundStyle(Theme.Colors.text2)
                .padding(.top, Theme.Space.x4)
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.x3) {
                Text("ACTIVITY")
                    .textStyle(.overline)
                    .foregroundStyle(Theme.Colors.text2)
                ForEach(app.recentTransactions) { tx in
                    TxRow(tx: tx, unitLabel: app.unitLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Space.x2)
        }
    }

    /// Primary money actions. Receive is live (push to `ReceiveScreen`); Send is a disabled
    /// placeholder until the Send slice.
    private var actionRow: some View {
        HStack(spacing: Theme.Space.x3) {
            Button {
                showReceive = true
            } label: {
                actionChip(icon: Icon.receive, title: "Receive", prominent: true)
            }
            .buttonStyle(.plain)

            Button {
                showSend = true
            } label: {
                actionChip(icon: Icon.send, title: "Send", prominent: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionChip(icon: String, title: String, prominent: Bool) -> some View {
        HStack(spacing: Theme.Space.x2) {
            Image(icon: icon).resizable().scaledToFit().frame(width: 18, height: 18)
            Text(title).textStyle(.button)
        }
        .foregroundStyle(prominent ? Theme.Colors.accentText : Theme.Colors.text0)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.x4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(prominent ? Theme.Colors.accent : Theme.Colors.bg2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(prominent ? Color.clear : Theme.Colors.border, lineWidth: 1)
        )
    }

    /// Sync state under the balance: a spinner while syncing, a tappable error on failure, and a
    /// quiet manual "Refresh" when idle. Tapping re-runs `app.sync()` (off the main actor).
    @ViewBuilder
    private var syncStatus: some View {
        switch app.syncState {
        case .syncing:
            HStack(spacing: Theme.Space.x2) {
                ProgressView()
                Text("Syncing…")
                    .textStyle(.xs)
                    .foregroundStyle(Theme.Colors.text2)
            }
        case .failed(let message):
            Button {
                Task { await app.sync() }
            } label: {
                HStack(spacing: Theme.Space.x1) {
                    Image(icon: Icon.refresh).resizable().scaledToFit().frame(width: 14, height: 14)
                    Text(message).textStyle(.xs)
                }
                .foregroundStyle(Theme.Colors.negative)
            }
        case .idle:
            Button {
                Task { await app.sync() }
            } label: {
                HStack(spacing: Theme.Space.x1) {
                    Image(icon: Icon.refresh).resizable().scaledToFit().frame(width: 14, height: 14)
                    Text("Refresh").textStyle(.xs)
                }
                .foregroundStyle(Theme.Colors.text2)
            }
        }
    }

    /// Persistent "not backed up" nudge (Golden Rule §7). Tapping wires to the Backup flow in Slice 3.
    private var backupNudge: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x1) {
            Text("Back up your recovery phrase")
                .textStyle(.sm)
                .foregroundStyle(Theme.Colors.text0)
            Text("It's the only way to restore this wallet if you lose the device.")
                .textStyle(.xs)
                .foregroundStyle(Theme.Colors.text1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x4)
        .background(Theme.Colors.warningTint, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.warning.opacity(0.4), lineWidth: 1)
        )
    }
}
