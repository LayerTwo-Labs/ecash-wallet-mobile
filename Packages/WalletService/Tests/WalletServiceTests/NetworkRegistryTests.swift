// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// Locks down the network-safety invariants (Golden Rule §4): each network resolves to the
/// right coin-type / HRP / unit / endpoint, and mainnet can never be confused with a testnet.
final class NetworkRegistryTests: XCTestCase {

    func testCoinTypeMainnetIsZeroTestnetsAreOne() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).coinType, Int32(0))
        XCTAssertEqual(NetworkRegistry.params(for: .testnet4).coinType, Int32(1))
        XCTAssertEqual(NetworkRegistry.params(for: .signet).coinType, Int32(1))
        XCTAssertEqual(NetworkRegistry.params(for: .regtest).coinType, Int32(1))
    }

    func testMainnetAndTestnetCoinTypesNeverCollide() {
        XCTAssertNotEqual(NetworkRegistry.params(for: .bitcoin).coinType,
                          NetworkRegistry.params(for: .testnet4).coinType)
    }

    func testAddressHRP() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).addressHRP, "bc")
        XCTAssertEqual(NetworkRegistry.params(for: .testnet4).addressHRP, "tb")
        XCTAssertEqual(NetworkRegistry.params(for: .signet).addressHRP, "tb")
        XCTAssertEqual(NetworkRegistry.params(for: .regtest).addressHRP, "bcrt")
    }

    func testUnitLabel() {
        XCTAssertEqual(NetworkRegistry.params(for: .bitcoin).unitLabel, "BTC")
        XCTAssertEqual(NetworkRegistry.params(for: .testnet4).unitLabel, "tBTC")
    }

    func testTestnet4DefaultBackend() {
        // mempool.space — verified syncing via bdk's ElectrumClient (2026-06-11). Must be an SSL
        // Electrum endpoint (the wallet talks Electrum, and we don't ship plaintext by default).
        let backend = NetworkRegistry.params(for: .testnet4).defaultBackend
        XCTAssertEqual(backend, "ssl://mempool.space:40002")
        XCTAssertTrue(backend.hasPrefix("ssl://"))
    }

    func testExplorerURLSubstitutesTxid() {
        let url = NetworkRegistry.explorerURL(for: "abc123", on: .testnet4)
        XCTAssertEqual(url, "https://mempool.space/testnet4/tx/abc123")
        XCTAssertFalse(url.contains("{txid}"))
    }

    func testIsMainnet() {
        XCTAssertTrue(WalletNetwork.bitcoin.isMainnet)
        XCTAssertFalse(WalletNetwork.testnet4.isMainnet)
        XCTAssertFalse(WalletNetwork.signet.isMainnet)
        XCTAssertFalse(WalletNetwork.regtest.isMainnet)
    }
}
