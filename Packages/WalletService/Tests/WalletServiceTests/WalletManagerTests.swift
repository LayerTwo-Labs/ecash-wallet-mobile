// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

/// WalletManager orchestration, driven by in-memory stores + the mock factory (Robolectric-safe).
/// Real BDK create/import + Keychain/SQLite are integration-tested on device/emulator (§11).
final class WalletManagerTests: XCTestCase {

    func testCreateWalletPersistsSecretAndMetadataAndSelects() throws {
        let ks = InMemoryKeyStore()
        let ws = InMemoryWalletStore()
        let manager = WalletManager(keyStore: ks, walletStore: ws, factory: MockWalletEngineFactory())

        let wallet = try manager.createWallet(label: "Savings", network: .testnet4)

        XCTAssertEqual(manager.wallets.count, 1)
        XCTAssertEqual(manager.selectedWalletId, wallet.id)
        XCTAssertEqual(wallet.network, WalletNetwork.testnet4)
        XCTAssertFalse(wallet.isBackedUp)
        XCTAssertNotNil(try ks.loadMnemonic(walletId: wallet.id))   // secret stored
        XCTAssertEqual(try ws.allWallets().count, 1)                // metadata stored
    }

    func testImportWalletStoresGivenMnemonic() throws {
        let ks = InMemoryKeyStore()
        let manager = WalletManager(keyStore: ks, walletStore: InMemoryWalletStore(), factory: MockWalletEngineFactory())
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        let wallet = try manager.importWallet(label: "Imported", network: .testnet4, mnemonic: mnemonic)

        XCTAssertEqual(try ks.loadMnemonic(walletId: wallet.id), mnemonic)
        XCTAssertEqual(manager.wallets.count, 1)
    }

    func testImportRejectsBadMnemonicAndPersistsNothing() {
        let factory = MockWalletEngineFactory()
        factory.rejectImport = true
        let ks = InMemoryKeyStore()
        let manager = WalletManager(keyStore: ks, walletStore: InMemoryWalletStore(), factory: factory)

        var threw = false
        do { _ = try manager.importWallet(label: "X", network: .testnet4, mnemonic: "bad checksum") }
        catch { threw = true }

        XCTAssertTrue(threw)
        XCTAssertEqual(manager.wallets.count, 0)
    }

    func testRemovePurgesSecretAndMetadataAndReselects() throws {
        let ks = InMemoryKeyStore()
        let ws = InMemoryWalletStore()
        let factory = MockWalletEngineFactory()
        let manager = WalletManager(keyStore: ks, walletStore: ws, factory: factory)
        let a = try manager.createWallet(label: "A", network: .testnet4)
        let b = try manager.createWallet(label: "B", network: .signet)
        manager.select(id: a.id)

        try manager.removeWallet(id: a.id)

        XCTAssertNil(try ks.loadMnemonic(walletId: a.id))      // mnemonic purged
        XCTAssertEqual(manager.wallets.count, 1)
        XCTAssertEqual(manager.selectedWalletId, b.id)         // re-selected the survivor
        XCTAssertNotNil(try ks.loadMnemonic(walletId: b.id))   // other wallet untouched (isolation)
        XCTAssertEqual(try ws.allWallets().count, 1)
        // BDK chain-data store is the third keyed artifact — removal must purge it too (Golden Rule §5).
        XCTAssertEqual(factory.purgedChainDataIds, [a.id])
        XCTAssertFalse(factory.purgedChainDataIds.contains(b.id))   // survivor's data untouched
    }

    func testRename() throws {
        let manager = WalletManager(keyStore: InMemoryKeyStore(), walletStore: InMemoryWalletStore(), factory: MockWalletEngineFactory())
        let wallet = try manager.createWallet(label: "Old", network: .testnet4)
        try manager.renameWallet(id: wallet.id, to: "New")
        XCTAssertEqual(manager.wallets.first?.label, "New")
    }

    func testSetBackedUp() throws {
        let manager = WalletManager(keyStore: InMemoryKeyStore(), walletStore: InMemoryWalletStore(), factory: MockWalletEngineFactory())
        let wallet = try manager.createWallet(label: "A", network: .testnet4)
        XCTAssertFalse(manager.wallets.first?.isBackedUp ?? true)
        try manager.setBackedUp(id: wallet.id)
        XCTAssertTrue(manager.wallets.first?.isBackedUp ?? false)
    }

    func testLoadRestoresWalletsAndSelection() throws {
        let ks = InMemoryKeyStore()
        let ws = InMemoryWalletStore()
        let first = WalletManager(keyStore: ks, walletStore: ws, factory: MockWalletEngineFactory())
        _ = try first.createWallet(label: "A", network: .testnet4)
        _ = try first.createWallet(label: "B", network: .signet)

        // A fresh manager over the same stores loads what was persisted.
        let reloaded = WalletManager(keyStore: ks, walletStore: ws, factory: MockWalletEngineFactory())
        try reloaded.load()
        XCTAssertEqual(reloaded.wallets.count, 2)
        XCTAssertNotNil(reloaded.selectedWalletId)
    }

    func testEngineForWalletMatchesNetwork() throws {
        let manager = WalletManager(keyStore: InMemoryKeyStore(), walletStore: InMemoryWalletStore(), factory: MockWalletEngineFactory())
        let wallet = try manager.createWallet(label: "A", network: .signet)
        let engine = try manager.engine(for: wallet)
        // `WalletNetwork.signet` written out: `engine` is a `WalletEngineProtocol` existential, so
        // inside the generic `XCTAssertEqual` the transpiler can't infer the shorthand's owning type
        // (it emitted `Any.signet`). Explicit qualification is the documented workaround.
        XCTAssertEqual(engine.network, WalletNetwork.signet)
    }
}
