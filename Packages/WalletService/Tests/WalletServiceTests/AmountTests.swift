// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// Pure money-math tests — safe under Robolectric (no BDK). Literals are wrapped in
/// `Int64(...)` so the transpiled Kotlin gets `ULong`, not `Int` (Skip Lite rule).
final class AmountTests: XCTestCase {

    func testZeroAndSatsPerCoin() {
        XCTAssertEqual(Amount.zero.sats, Int64(0))
        XCTAssertEqual(Amount.satsPerCoin, Int64(100_000_000))
    }

    func testAdding() {
        let total = Amount(sats: Int64(150)).adding(Amount(sats: Int64(350)))
        XCTAssertEqual(total.sats, Int64(500))
    }

    func testSubtracting() {
        XCTAssertEqual(Amount(sats: Int64(500)).subtracting(Amount(sats: Int64(200)))?.sats, Int64(300))
        XCTAssertEqual(Amount(sats: Int64(500)).subtracting(Amount(sats: Int64(500)))?.sats, Int64(0))
    }

    func testSubtractingUnderflowReturnsNil() {
        XCTAssertNil(Amount(sats: Int64(200)).subtracting(Amount(sats: Int64(500))))
    }

    func testComparable() {
        XCTAssertTrue(Amount(sats: Int64(10)) < Amount(sats: Int64(20)))
        XCTAssertFalse(Amount(sats: Int64(20)) < Amount(sats: Int64(10)))
    }

    // MARK: - Formatting (full 8-dp, integer math)

    func testFormattedCoinVectors() {
        XCTAssertEqual(Amount(sats: Int64(0)).formattedCoin(), "0.00000000")
        XCTAssertEqual(Amount(sats: Int64(1)).formattedCoin(), "0.00000001")
        XCTAssertEqual(Amount(sats: Int64(100_000_000)).formattedCoin(), "1.00000000")
        XCTAssertEqual(Amount(sats: Int64(84_210_000)).formattedCoin(), "0.84210000")
        XCTAssertEqual(Amount(sats: Int64(123_456_789)).formattedCoin(), "1.23456789")
    }

    func testFormattedCoinLargeValueNoOverflow() {
        // 21,000,000 coins = 2.1e15 sats — far beyond Int32; verifies the UInt64/ULong path.
        let maxSupply = Amount(sats: Int64(21_000_000) * Amount.satsPerCoin)
        XCTAssertEqual(maxSupply.formattedCoin(), "21000000.00000000")
    }

    // MARK: - Max spend

    func testMaxSpend() {
        let balance = Amount(sats: Int64(1000))
        XCTAssertEqual(Amount.maxSpend(balance: balance, fee: Amount(sats: Int64(200))).sats, Int64(800))
    }

    func testMaxSpendClampsToZeroWhenFeeExceedsBalance() {
        let balance = Amount(sats: Int64(1000))
        XCTAssertEqual(Amount.maxSpend(balance: balance, fee: Amount(sats: Int64(1000))).sats, Int64(0))
        XCTAssertEqual(Amount.maxSpend(balance: balance, fee: Amount(sats: Int64(5000))).sats, Int64(0))
    }

    // MARK: - Coin-string parsing (fromCoin)

    func testFromCoinVectors() {
        XCTAssertEqual(Amount.fromCoin("0")?.sats, Int64(0))
        XCTAssertEqual(Amount.fromCoin("1")?.sats, Int64(100_000_000))
        XCTAssertEqual(Amount.fromCoin("0.001")?.sats, Int64(100_000))
        XCTAssertEqual(Amount.fromCoin("0.00000001")?.sats, Int64(1))
        XCTAssertEqual(Amount.fromCoin(".5")?.sats, Int64(50_000_000))
        XCTAssertEqual(Amount.fromCoin("21000000")?.sats, Int64(21_000_000) * Amount.satsPerCoin)
    }

    func testFromCoinRejectsMalformed() {
        XCTAssertNil(Amount.fromCoin(""))
        XCTAssertNil(Amount.fromCoin("abc"))
        XCTAssertNil(Amount.fromCoin("1.2.3"))      // two decimal points
        XCTAssertNil(Amount.fromCoin("0.123456789")) // 9 decimal places
        XCTAssertNil(Amount.fromCoin("1a"))
        XCTAssertNil(Amount.fromCoin("-1"))          // negative / sign
    }

    func testCoinRoundTrip() {
        let original = Amount(sats: Int64(123_456_789))
        XCTAssertEqual(Amount.fromCoin(original.formattedCoin())?.sats, original.sats)
    }
}
