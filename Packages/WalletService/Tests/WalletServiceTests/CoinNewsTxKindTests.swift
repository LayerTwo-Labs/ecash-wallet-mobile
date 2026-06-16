// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import XCTest
@testable import WalletService

// Apple-only (`#if !SKIP`): the classifier lives on `WalletEngine`, whose type references bdk-swift
// (an Apple-only binary that can't load under Robolectric). Pure byte logic, so the host run fully
// covers it; the Android path is exercised by `skip export` (compile) + on-device CoinNews posting.
#if !SKIP

/// `WalletEngine` CoinNews `OP_RETURN` classification — both the raw-payload form (what we hand to
/// `addData`) and the on-chain output-script form (`OP_RETURN ‖ push(payload)`), including the
/// `OP_PUSHDATA1` length form for payloads > 75 bytes.
final class CoinNewsTxKindTests: XCTestCase {

    // "CN" envelope + type tag.
    private let cn: [UInt8] = [0x43, 0x4e]

    func testPayloadKinds() {
        XCTAssertEqual(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x01, 0xde, 0xad])), "topic")
        XCTAssertEqual(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x02, 0x00])), "story")
        XCTAssertEqual(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x03])), "comment")
        XCTAssertEqual(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x04])), "upvote")
        XCTAssertEqual(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x05])), "downvote")
    }

    func testPayloadRejectsNonCoinNews() {
        XCTAssertNil(WalletEngine.coinNewsKind(fromPayload: Data([0x41, 0x42, 0x02])))   // "AB"
        XCTAssertNil(WalletEngine.coinNewsKind(fromPayload: Data(cn + [0x7f])))           // unknown tag
        XCTAssertNil(WalletEngine.coinNewsKind(fromPayload: Data([0x43])))                // too short
    }

    func testScriptDirectPush() {
        // OP_RETURN(0x6a) ‖ push-len(5) ‖ "CN" ‖ 0x02(story) ‖ 2 body bytes
        let script = Data([0x6a, 0x05] + cn + [0x02, 0xaa, 0xbb])
        XCTAssertEqual(WalletEngine.coinNewsKind(fromScript: script), "story")
    }

    func testScriptPushData1ForLongPayload() {
        // Payloads > 75 bytes use OP_PUSHDATA1 (0x4c ‖ len). 80-byte payload: "CN" ‖ 0x01(topic) ‖ 77×0x00.
        var payload = cn + [0x01]
        for _ in 0..<77 { payload.append(0x00) }
        let script = Data([0x6a, 0x4c, UInt8(payload.count)] + payload)
        XCTAssertEqual(WalletEngine.coinNewsKind(fromScript: script), "topic")
    }

    func testScriptRejectsNonCoinNews() {
        // OP_RETURN carrying "ABC" — a valid OP_RETURN, but not CoinNews.
        XCTAssertNil(WalletEngine.coinNewsKind(fromScript: Data([0x6a, 0x03, 0x41, 0x42, 0x43])))
        // A P2WPKH-style script (starts 0x00 0x14 …), not an OP_RETURN at all.
        XCTAssertNil(WalletEngine.coinNewsKind(fromScript: Data([0x00, 0x14] + Array(repeating: 0x11, count: 20))))
        // OP_RETURN with a truncated push (claims 5 bytes, only 2 present).
        XCTAssertNil(WalletEngine.coinNewsKind(fromScript: Data([0x6a, 0x05] + cn)))
    }
}

#endif
