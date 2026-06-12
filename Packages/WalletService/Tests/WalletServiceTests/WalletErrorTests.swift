// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// Error mapping + the Golden Rule §2 guarantee: no secret material ever appears in a
/// user-facing message, and raw error text is never echoed through.
final class WalletErrorTests: XCTestCase {

    func testMappingClassifiesKnownErrors() {
        XCTAssertEqual(WalletError.mapping(rawDescription: "Insufficient funds available"), .insufficientFunds)
        XCTAssertEqual(WalletError.mapping(rawDescription: "Output is below the dust limit"), .dustAmount)
        XCTAssertEqual(WalletError.mapping(rawDescription: "bad checksum in recovery phrase"), .invalidMnemonic)
        XCTAssertEqual(WalletError.mapping(rawDescription: "broadcast rejected by node"), .broadcastFailed)
    }

    /// Classification must key off BDK's actual UniFFI variant names as they render in
    /// `"\(error)"` (identical on bdk-swift and bdk-android), not just prose. These strings mirror
    /// real `CreateTxError` / `Bip39Error` / `ElectrumError` descriptions.
    func testMappingClassifiesBDKVariantNames() {
        XCTAssertEqual(WalletError.mapping(rawDescription: "InsufficientFunds(needed: 5000, available: 1200)"), .insufficientFunds)
        XCTAssertEqual(WalletError.mapping(rawDescription: "OutputBelowDustLimit(index: 0)"), .dustAmount)
        XCTAssertEqual(WalletError.mapping(rawDescription: "NoUtxosSelected"), .noSpendableUtxos)
        XCTAssertEqual(WalletError.mapping(rawDescription: "AllAttemptsErrored"), .syncFailed)
        XCTAssertEqual(WalletError.mapping(rawDescription: "BadWordCount(wordCount: 13)"), .invalidMnemonic)
    }

    func testMappingUnknownIsGenericNotRaw() {
        let mapped = WalletError.mapping(rawDescription: "weird internal gibberish 0xdeadbeef")
        XCTAssertFalse(mapped.userMessage.contains("gibberish"))
        XCTAssertFalse(mapped.userMessage.contains("0xdeadbeef"))
    }

    /// The important one: a raw BDK-style error embedding key material must never surface it.
    func testMappingNeverLeaksSecretMaterial() {
        let secret = "xprv9s21ZrQH143K3SECRET tpubDCsecret seedwordone seedwordtwo"
        let raw = "signing failed for wpkh([ab12cd34/84'/1'/0']\(secret)/0/*)"
        let mapped = WalletError.mapping(rawDescription: raw)
        XCTAssertFalse(mapped.userMessage.contains(secret))
        XCTAssertFalse(mapped.userMessage.lowercased().contains("xprv"))
        XCTAssertFalse(mapped.userMessage.lowercased().contains("tpub"))
        XCTAssertFalse(mapped.userMessage.contains("wpkh"))
    }

    func testAllUserMessagesNonEmptyAndContainNoKeyMarkers() {
        let cases: [WalletError] = [
            .notImplemented, .invalidMnemonic, .invalidDescriptor, .invalidAddress,
            .networkMismatch(expected: .testnet4), .insufficientFunds, .dustAmount,
            .noSpendableUtxos, .syncFailed, .broadcastFailed, .signingFailed,
            .persistenceFailed, .engine("Something went wrong.")
        ]
        for error in cases {
            let msg = error.userMessage.lowercased()
            XCTAssertFalse(error.userMessage.isEmpty)
            XCTAssertFalse(msg.contains("xprv"))
            XCTAssertFalse(msg.contains("tprv"))
            XCTAssertFalse(msg.contains("xpub"))
            XCTAssertFalse(msg.contains("tpub"))
        }
    }
}
