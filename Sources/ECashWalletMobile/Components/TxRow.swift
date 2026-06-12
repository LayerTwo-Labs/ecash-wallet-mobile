// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import WalletService

/// One transaction row — shared by the Activity tab (and later a Home preview).
///
/// DELIBERATELY SHALLOW (Android): SkipUI composes every modifier as a recursive wrapper
/// (`ModifiedContent.Render` → `EnvironmentValues.setValues` → `CompositionLocalProvider`, ~10
/// interpreter frames each on a cold debug start before ART JITs). Stacking `.textStyle`
/// (font+tracking+textCase) + `.foregroundStyle` + `.lineLimit` on three Texts inside
/// TabView→NavigationStack→List→item overflowed the main-thread stack (SIGTRAP, the
/// `EvaluateLazyItems` crash). So: ONE `.font` per Text, ONE shared `.foregroundStyle`, no
/// tracking/textCase/lineLimit, no Spacer/maxWidth (flexible containers also recursed), no
/// child padding. Keep this row boring.
struct TxRow: View {
    let tx: WalletTx
    let unitLabel: String

    var body: some View {
        HStack(spacing: Theme.Space.x3) {
            Image(icon: tx.isReceived ? Icon.receive : Icon.send)
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(tx.isReceived ? Theme.Colors.positive : Theme.Colors.text1)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.isReceived ? "Received" : "Sent")
                    .font(.grotesk(17, .semibold))
                Text(amountText)
                    .font(.jbMono(14, .regular))
                    .foregroundStyle(tx.isReceived ? Theme.Colors.positive : Theme.Colors.text0)
                Text(metaText)
                    .font(.jbMono(12, .medium))
                    .foregroundStyle(Theme.Colors.text2)
            }
            .foregroundStyle(Theme.Colors.text0)
        }
    }

    /// Confirmations, plus the miner fee for sent txs: "Pending · 0 conf · fee 281 sats".
    /// The fee is shown separately because it goes to the miner, not the recipient — the
    /// amount line is what the recipient actually gets.
    private var metaText: String {
        let conf: String
        if tx.confirmations == 0 {
            conf = "Pending · 0 conf"
        } else {
            conf = "\(tx.confirmations) conf"
        }
        if !tx.isReceived, let fee = tx.feeSats {
            return "\(conf) · fee \(fee) sats"
        }
        return conf
    }

    /// e.g. "+0.00125000 sBTC" / "-0.01500000 sBTC". For sent txs this is the amount the
    /// RECIPIENT receives — `netSats` (the wallet's total outflow) minus the miner fee, which
    /// is itemized on the meta line. Falls back to the net amount when BDK can't compute the
    /// fee. Received txs show the net amount (the payer covered the fee).
    private var amountText: String {
        let sign = tx.isReceived ? "+" : "-"
        var sats = abs(tx.netSats)
        if !tx.isReceived, let fee = tx.feeSats, fee <= sats {
            sats = sats - fee
        }
        let coins = Amount(sats: sats).formattedCoin()
        return "\(sign)\(coins) \(unitLabel)"
    }
}
