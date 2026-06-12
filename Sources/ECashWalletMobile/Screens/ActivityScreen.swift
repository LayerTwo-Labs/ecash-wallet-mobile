// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WalletService

/// Full transaction history for the selected wallet, newest first (pending at the top). Syncs on
/// appear. Uses a `List` (Compose `LazyColumn`) — the robust virtualized row container — rather than
/// a hand-built VStack+ForEach, which recursed in SkipUI's Compose layout.
struct ActivityScreen: View {
    @Environment(AppState.self) var app

    var body: some View {
        Group {
            if app.transactions.isEmpty {
                ZStack {
                    Theme.Colors.bg0.ignoresSafeArea()
                    PlaceholderScreen(heading: "No activity yet",
                                      note: "Your transactions will appear here.")
                }
            } else {
                List {
                    ForEach(app.transactions) { tx in
                        TxRow(tx: tx, unitLabel: app.unitLabel)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Activity")
        .task { await app.sync() }
    }
}
