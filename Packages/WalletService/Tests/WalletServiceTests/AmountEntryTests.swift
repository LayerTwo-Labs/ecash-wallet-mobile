// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// The keypad editing rules that feed `Amount.fromCoin` — every branch, since this guards
/// money input on both platforms.
final class AmountEntryTests: XCTestCase {

    func testAppendDigitBasics() {
        XCTAssertEqual(AmountEntry.appendDigit("", digit: 5), "5")
        XCTAssertEqual(AmountEntry.appendDigit("1", digit: 2), "12")
        XCTAssertEqual(AmountEntry.appendDigit("0.0", digit: 7), "0.07")
    }

    func testAppendDigitReplacesLoneZero() {
        XCTAssertEqual(AmountEntry.appendDigit("0", digit: 5), "5")
        // But a zero AFTER the dot is a real digit.
        XCTAssertEqual(AmountEntry.appendDigit("0.", digit: 0), "0.0")
    }

    func testAppendDigitRejectsOutOfRange() {
        XCTAssertEqual(AmountEntry.appendDigit("1", digit: -1), "1")
        XCTAssertEqual(AmountEntry.appendDigit("1", digit: 10), "1")
    }

    func testAppendDigitCapsFractionAtEightDigits() {
        let eight = "0.12345678"
        XCTAssertEqual(AmountEntry.appendDigit(eight, digit: 9), eight)
        XCTAssertEqual(AmountEntry.appendDigit("0.1234567", digit: 8), "0.12345678")
    }

    func testAppendDigitCapsWholeAtTenDigits() {
        let ten = "1234567890"
        XCTAssertEqual(AmountEntry.appendDigit(ten, digit: 1), ten)
        XCTAssertEqual(AmountEntry.appendDigit("123456789", digit: 0), ten)
    }

    func testAppendDot() {
        XCTAssertEqual(AmountEntry.appendDot(""), "0.")
        XCTAssertEqual(AmountEntry.appendDot("1"), "1.")
        XCTAssertEqual(AmountEntry.appendDot("1.2"), "1.2") // only one dot
        XCTAssertEqual(AmountEntry.appendDot("0."), "0.")
    }

    func testBackspace() {
        XCTAssertEqual(AmountEntry.backspace("1.2"), "1.")
        XCTAssertEqual(AmountEntry.backspace("1"), "")
        XCTAssertEqual(AmountEntry.backspace(""), "")
    }

    /// Every string the keypad can build must be parseable by `Amount.fromCoin` once it has
    /// any digits (a trailing dot is fine: "1." parses as 1 coin).
    func testKeypadOutputRoundTripsThroughFromCoin() {
        var text = ""
        text = AmountEntry.appendDigit(text, digit: 0)   // "0"
        text = AmountEntry.appendDot(text)               // "0."
        text = AmountEntry.appendDigit(text, digit: 0)   // "0.0"
        text = AmountEntry.appendDigit(text, digit: 1)   // "0.01"
        XCTAssertEqual(Amount.fromCoin(text)?.sats, Int64(1_000_000))
        XCTAssertEqual(Amount.fromCoin("1.")?.sats, Amount.satsPerCoin)
    }
}
