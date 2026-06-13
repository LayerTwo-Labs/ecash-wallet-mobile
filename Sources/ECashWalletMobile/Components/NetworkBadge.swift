// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// The persistent network-identity chip — a safety primitive, not decoration (Golden Rule
/// §2.6): a non-mainnet wallet must be unmistakable on every money-touching surface (home,
/// send review, receive, history, wallet switcher).
///
/// Mainnet is the unmarked default (reconciliation) — the badge renders nothing
/// for it. Non-mainnet shows a solid, high-contrast violet chip with the network name, chosen
/// to be impossible to confuse with the brand accent / positive / negative colors.
///
/// Presentational only: it takes a display name + a mainnet flag, so it has no dependency on
/// WalletService and stays trivially previewable. Callers that hold a `WalletNetwork` pass
/// `NetworkRegistry.params(for:).displayName` and `network.isMainnet` (wired in Slice 1/2).
struct NetworkBadge: View {
    /// The network's display name, e.g. "Testnet4". Rendered uppercased.
    let name: String
    /// Mainnet is unmarked — pass `true` to render no badge.
    let isMainnet: Bool

    var body: some View {
        if isMainnet {
            EmptyView()
        } else {
            Text(verbatim: name)   // network display name (proper noun, from NetworkRegistry)
                .textStyle(.overline) // uppercased + tracked
                .foregroundStyle(Theme.Colors.netTestnetText)
                .padding(.horizontal, Theme.Space.x3)
                .padding(.vertical, Theme.Space.x1)
                .background(Theme.Colors.netTestnet, in: Capsule())
                .accessibilityLabel(Text("\(name) network",
                                         bundle: .module,
                                         comment: "Network badge accessibility label"))
        }
    }
}
