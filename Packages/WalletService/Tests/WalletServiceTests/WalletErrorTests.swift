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

    /// The Golden Rule §2 guarantee, property-style: a BDK error string can embed ANYTHING —
    /// a signing failure that prints the offending descriptor, a Bip32 error quoting the xprv,
    /// a Generic error that stringifies internal state including the mnemonic. No matter how the
    /// raw text is shaped or which case it classifies as, `mapping()` must return a fixed,
    /// pre-scrubbed message that contains NONE of the secret material. This holds structurally
    /// because every case's `userMessage` is a constant and `.engine` is only ever built with a
    /// fixed string — this test pins that invariant against regressions.
    func testMappingNeverLeaksAcrossRealisticBDKErrorShapes() {
        // Clearly fake, but structurally real secret material that must never survive.
        let xprv = "xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpykdGGBxe3MfWyz4hQuXKh2FAKEKEYMATERIAL"
        let tprv = "tprv8ZgxMBicQKsPeFAKETPRVKEYMATERIALdonotleakthisever1234567890abcdef"
        let tpub = "tpubDC8msFG4d1234FAKEXPUBACCOUNTKEYdonotleak"
        let fingerprint = "73c5da0a"
        let mnemonic = "abandon ability able about above absent absorb abstract absurd abuse access accident"
        let descriptor = "wpkh([\(fingerprint)/84'/1'/0']\(tprv)/0/*)"

        // Raw error strings shaped like the real BDK 2.3.1 / Miniscript / Bip32 descriptions
        // that could plausibly embed the above.
        let rawErrors = [
            "SignerError(External): failed to sign input 0 of \(descriptor)",
            "DescriptorError: invalid descriptor \(descriptor)",
            "Bip32Error: secret key \(xprv) is invalid for this path",
            "Generic(\"internal state: mnemonic=\(mnemonic) account=\(tpub)\")",
            "Miniscript(BadDescriptor(\"\(descriptor)\"))",
            "PsbtError: could not finalize wpkh(\(tprv))",
            "unexpected failure deriving \(xprv) at 84'/1'/0'",
        ]

        let forbidden = [xprv, tprv, tpub, fingerprint, mnemonic, descriptor, "wpkh", "xprv", "tprv", "tpub"]

        for raw in rawErrors {
            let message = WalletError.mapping(rawDescription: raw).userMessage
            let lowerMessage = message.lowercased()
            XCTAssertFalse(message.isEmpty, "mapped message must never be empty for: \(raw)")
            XCTAssertNotEqual(message, raw, "mapped message must never echo the raw error")
            for secret in forbidden {
                XCTAssertFalse(lowerMessage.contains(secret.lowercased()),
                               "leaked '\(secret)' for raw error: \(raw)")
            }
        }
    }

    func testAllUserMessagesNonEmptyAndContainNoKeyMarkers() {
        let cases: [WalletError] = [
            .notImplemented, .invalidMnemonic, .invalidDescriptor, .invalidAddress,
            .networkMismatch(expected: .signet), .insufficientFunds, .dustAmount,
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
