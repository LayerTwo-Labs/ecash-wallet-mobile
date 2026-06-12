// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// BIP21 / payment-request parsing. Pure logic — safe under Robolectric.
final class BIP21Tests: XCTestCase {

    func testBareAddress() {
        let r = BIP21.parse("tb1qexampleaddress")
        XCTAssertEqual(r?.address, "tb1qexampleaddress")
        XCTAssertNil(r?.amount)
    }

    func testSchemeStripped() {
        XCTAssertEqual(BIP21.parse("bitcoin:tb1qabc")?.address, "tb1qabc")
    }

    func testSchemeCaseInsensitive() {
        XCTAssertEqual(BIP21.parse("BITCOIN:tb1qabc")?.address, "tb1qabc")
    }

    func testAmountConvertedToSats() {
        let r = BIP21.parse("bitcoin:tb1qabc?amount=0.001")
        XCTAssertEqual(r?.address, "tb1qabc")
        XCTAssertEqual(r?.amount?.sats, Int64(100_000))
    }

    func testLabelAndMessage() {
        let r = BIP21.parse("bitcoin:tb1qabc?amount=1&label=Coffee&message=Thanks")
        XCTAssertEqual(r?.amount?.sats, Int64(100_000_000))
        XCTAssertEqual(r?.label, "Coffee")
        XCTAssertEqual(r?.message, "Thanks")
    }

    func testPercentEncodedLabelDecoded() {
        XCTAssertEqual(BIP21.parse("bitcoin:tb1qabc?label=Donation%20fund")?.label, "Donation fund")
    }

    func testUnknownParamIgnored() {
        let r = BIP21.parse("bitcoin:tb1qabc?somefuture=1&amount=0.5")
        XCTAssertEqual(r?.amount?.sats, Int64(50_000_000))
    }

    func testMalformedAmountRejectsWholeURI() {
        XCTAssertNil(BIP21.parse("bitcoin:tb1qabc?amount=notanumber"))
    }

    func testWhitespaceTrimmed() {
        XCTAssertEqual(BIP21.parse("  tb1qabc  ")?.address, "tb1qabc")
    }

    func testEmptyAndAddresslessRejected() {
        XCTAssertNil(BIP21.parse(""))
        XCTAssertNil(BIP21.parse("bitcoin:"))   // scheme but no address
    }
}
