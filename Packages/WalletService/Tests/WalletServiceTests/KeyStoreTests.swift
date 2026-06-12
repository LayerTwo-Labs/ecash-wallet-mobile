// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// KeyStore semantics via the in-memory impl (the real Keychain is integration-tested on device).
final class KeyStoreTests: XCTestCase {

    func testSaveLoadDelete() throws {
        let ks = InMemoryKeyStore()
        try ks.saveMnemonic("seed words here", walletId: "w1")
        XCTAssertEqual(try ks.loadMnemonic(walletId: "w1"), "seed words here")
        try ks.deleteMnemonic(walletId: "w1")
        XCTAssertNil(try ks.loadMnemonic(walletId: "w1"))
    }

    func testKeyedByWalletIdIsolation() throws {
        let ks = InMemoryKeyStore()
        try ks.saveMnemonic("alpha", walletId: "w1")
        try ks.saveMnemonic("bravo", walletId: "w2")
        XCTAssertEqual(try ks.loadMnemonic(walletId: "w1"), "alpha")
        XCTAssertEqual(try ks.loadMnemonic(walletId: "w2"), "bravo")
        try ks.deleteMnemonic(walletId: "w1")
        XCTAssertNil(try ks.loadMnemonic(walletId: "w1"))
        XCTAssertEqual(try ks.loadMnemonic(walletId: "w2"), "bravo")
    }

    func testLoadMissingReturnsNil() throws {
        XCTAssertNil(try InMemoryKeyStore().loadMnemonic(walletId: "nope"))
    }
}
