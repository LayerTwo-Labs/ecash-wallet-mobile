// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// `WalletTx` derived-value logic — the fee-rate computation used by the transaction detail
/// screen, plus the direction/confirmation helpers. Pure logic, runs on both platforms.
final class WalletTxTests: XCTestCase {

    private func tx(netSats: Int64 = -400_000, feeSats: Int64? = 200, confirmations: Int32 = 3,
                    blockHeight: Int64? = 196_842, vsize: Int64? = 141) -> WalletTx {
        WalletTx(txid: "t", netSats: netSats, feeSats: feeSats, confirmations: confirmations,
                 timestampEpochSeconds: nil, isRBF: false, blockHeight: blockHeight, vsize: vsize)
    }

    func testFeeRateIsFeeOverVsize() {
        // 200 sats / 141 vB = 1.4184… sat/vB
        let rate = tx(feeSats: 200, vsize: 141).feeRatePerVByte()
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate!, 200.0 / 141.0, accuracy: 0.0001)
    }

    func testFeeRateExactWhenDivisible() {
        XCTAssertEqual(tx(feeSats: 282, vsize: 141).feeRatePerVByte()!, 2.0, accuracy: 0.0001)
    }

    func testFeeRateNilWhenFeeUnknown() {
        XCTAssertNil(tx(feeSats: nil, vsize: 141).feeRatePerVByte())
    }

    func testFeeRateNilWhenVsizeUnknown() {
        XCTAssertNil(tx(feeSats: 200, vsize: nil).feeRatePerVByte())
    }

    func testFeeRateNilWhenVsizeZero() {
        // Guard against divide-by-zero rather than returning inf/NaN.
        XCTAssertNil(tx(feeSats: 200, vsize: 0).feeRatePerVByte())
    }

    func testDirectionAndConfirmation() {
        XCTAssertTrue(tx(netSats: 200_000).isReceived)
        XCTAssertFalse(tx(netSats: -200_000).isReceived)
        XCTAssertTrue(tx(confirmations: 1).isConfirmed)
        XCTAssertFalse(tx(confirmations: 0).isConfirmed)
    }
}
