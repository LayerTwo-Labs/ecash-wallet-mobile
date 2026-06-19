// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// Locks down the network-safety invariants (Golden Rule §4): each network resolves to the
/// right coin-type / HRP / unit / endpoint, and mainnet can never be confused with a testnet.
/// Bundled networks: Bitcoin mainnet (`0'`) + L2L Signet (`1'`).
final class NetworkRegistryTests: XCTestCase {

    func testCoinTypeMainnetIsZeroTestnetsAreOne() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).coinType, Int32(0))
        XCTAssertEqual(NetworkRegistry.params(for: .signet).coinType, Int32(1))
    }

    func testMainnetAndTestnetCoinTypesNeverCollide() {
        XCTAssertNotEqual(NetworkRegistry.params(for: .bitcoin).coinType,
                          NetworkRegistry.params(for: .signet).coinType)
    }

    func testAddressHRP() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).addressHRP, "bc")
        XCTAssertEqual(NetworkRegistry.params(for: .signet).addressHRP, "tb")
    }

    func testUnitLabel() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).unitLabel, "BTC")
        XCTAssertEqual(NetworkRegistry.params(for: .signet).unitLabel, "sBTC")
    }

    func testSignetDefaultBackend() {
        // L2L drivechain signet electrs (TLS). Must be an SSL Electrum endpoint (the wallet talks
        // Electrum, and we don't ship plaintext by default).
        let backend = NetworkRegistry.params(for: .signet).defaultBackend
        XCTAssertEqual(backend, "ssl://node.signet.drivechain.info:50002")
        XCTAssertTrue(backend.hasPrefix("ssl://"))
    }

    func testExplorerURLSubstitutesTxid() {
        let url = NetworkRegistry.explorerURL(for: "abc123", on: .signet)
        XCTAssertEqual(url, "https://explorer.signet.drivechain.info/tx/abc123")
        XCTAssertFalse(url.contains("{txid}"))
    }

    func testIsMainnet() {
        XCTAssertTrue(WalletNetwork.bitcoin.isMainnet)
        XCTAssertFalse(WalletNetwork.signet.isMainnet)
    }
}
