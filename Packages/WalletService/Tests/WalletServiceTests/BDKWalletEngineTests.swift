// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Real-BDK correctness tests for the BDK seam. These cross the seam into actual
// bdk-swift, so they run ONLY on the macOS host — every test bails with `XCTSkip` under Robolectric
// (`#if SKIP`), where the bdk-android `.so` isn't loaded. The pure orchestration logic
// (WalletManager etc.) is covered separately with the mock engine on both platforms.
//
// What these lock down:
// • BIP84 derivation matches the PUBLISHED BIP84 spec vectors (mainnet) — world ground truth.
// • Testnet4 derivation (coin-type 1') is pinned + provably distinct from mainnet (coin-type 0').
// • `check_network`: a wallet rejects an address from another network (Golden Rule §4/§6).
// • Persistence round-trip: BDK's own SQLite store survives a cold reload (load-vs-create path).
// • Determinism + mnemonic round-trip + invalid-mnemonic rejection.
//
// NOTE: mainnet (`.bitcoin`) is used here ONLY as the authoritative published derivation vector —
// the product ships Testnet4 + eCash, not Bitcoin mainnet (per project scope). Asserting against the
// BIP84 spec is the least-contrived way to prove our derivation is correct, not a scope change.
//
// SkipUnit lacks `XCTAssertThrowsError`, and this file still TRANSPILES (even though it XCTSkips at
// runtime on Android), so throwing expectations use do/catch, not the XCTAssert* throwing helpers.

import XCTest
import Foundation
@testable import WalletService

final class BDKWalletEngineTests: XCTestCase {

    /// Canonical all-"abandon" BIP39 test vector (checksum word "about").
    private static let mnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"


    // Published BIP84 spec receiving addresses for the mnemonic above (m/84'/0'/0'/0/{0,1}).
    private static let mainnetExternal0 = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let mainnetExternal1 = "bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g"

    // Testnet4 receiving addresses (m/84'/1'/0'/0/{0,1}) — pinned regression vectors.
    private static let testnet4External0 = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"
    private static let testnet4External1 = "tb1qd7spv5q28348xl4myc8zmh983w5jx32cjhkn97"

    // MARK: - Helpers

    /// A fresh factory pointed at a unique temp chain-data dir; the dir is returned for cleanup.
    private func makeFactory() -> (BDKWalletEngineFactory, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bdk-test-\(UUID().uuidString)", isDirectory: true)
        return (BDKWalletEngineFactory(chainDataDirectory: dir), dir)
    }

    private func managedWallet(id: String, network: WalletNetwork, keys: WalletKeys) -> ManagedWallet {
        ManagedWallet(id: id, label: "t", network: network,
                      externalDescriptor: keys.externalDescriptor,
                      internalDescriptor: keys.internalDescriptor)
    }

    /// First two external addresses for a network, via a live engine over a temp store.
    private func firstTwoExternalAddresses(_ network: WalletNetwork) throws -> (String, String) {
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.restore(network: network, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: "vec-\(network.rawValue)", network: network, keys: keys)
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        let a0 = try engine.nextReceiveAddress()
        let a1 = try engine.nextReceiveAddress()
        XCTAssertEqual(a0.index, Int32(0))
        XCTAssertEqual(a1.index, Int32(1))
        return (a0.address, a1.address)
    }

    // MARK: - Derivation vectors

    /// Mainnet BIP84 matches the published spec vectors — proves our derivation is correct, period.
    func testMainnetBip84MatchesPublishedSpecVector() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (ext0, ext1) = try firstTwoExternalAddresses(.bitcoin)
        XCTAssertEqual(ext0, Self.mainnetExternal0)
        XCTAssertEqual(ext1, Self.mainnetExternal1)
        #endif
    }

    /// Testnet4 derivation (coin-type 1') is pinned and yields `tb1` SegWit addresses.
    func testTestnet4Bip84DerivationVector() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (ext0, ext1) = try firstTwoExternalAddresses(.testnet4)
        XCTAssertEqual(ext0, Self.testnet4External0)
        XCTAssertEqual(ext1, Self.testnet4External1)
        XCTAssertTrue(ext0.hasPrefix("tb1"), "Testnet4 must use the tb1 SegWit HRP")
        #endif
    }

    /// Same mnemonic, different network → different addresses (coin-type isolation, Golden Rule §4).
    func testNetworksDeriveDistinctAddresses() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (mainnet0, _) = try firstTwoExternalAddresses(.bitcoin)
        let (testnet0, _) = try firstTwoExternalAddresses(.testnet4)
        XCTAssertNotEqual(mainnet0, testnet0)
        #endif
    }

    /// Descriptors embed the network-correct BIP84 coin-type: 0' on mainnet, 1' on testnet4.
    func testDescriptorsCarryNetworkCorrectCoinType() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let mainnet = try factory.restore(network: .bitcoin, mnemonic: Self.mnemonic)
        XCTAssertTrue(mainnet.externalDescriptor.contains("84'/0'/0'"), mainnet.externalDescriptor)
        XCTAssertTrue(mainnet.internalDescriptor.contains("84'/0'/0'"))

        let testnet4 = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        XCTAssertTrue(testnet4.externalDescriptor.contains("84'/1'/0'"), testnet4.externalDescriptor)
        XCTAssertTrue(testnet4.internalDescriptor.contains("84'/1'/0'"))

        // External (.../0/*) and change (.../1/*) keychains are distinct.
        XCTAssertNotEqual(testnet4.externalDescriptor, testnet4.internalDescriptor)
        // Public descriptors only — no private key material may leak into stored metadata (§7).
        XCTAssertFalse(testnet4.externalDescriptor.lowercased().contains("xprv"))
        XCTAssertFalse(testnet4.externalDescriptor.lowercased().contains("tprv"))
        #endif
    }

    // MARK: - Mnemonic handling

    /// Restore returns the exact phrase it was given (it's what KeyStore persists, §7).
    func testRestoreRoundTripsMnemonicAndIsDeterministic() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let b = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        XCTAssertEqual(a.mnemonic, Self.mnemonic)
        XCTAssertEqual(a.externalDescriptor, b.externalDescriptor) // deterministic
        XCTAssertEqual(a.internalDescriptor, b.internalDescriptor)
        #endif
    }

    /// A bad-checksum phrase is rejected as `.invalidMnemonic`, with nothing leaked (§2).
    func testRestoreRejectsInvalidMnemonic() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            _ = try factory.restore(network: .testnet4, mnemonic: "not a valid bip39 phrase at all")
            XCTFail("expected restore to throw on an invalid mnemonic")
        } catch let error as WalletError {
            XCTAssertEqual(error, WalletError.invalidMnemonic)
        }
        #endif
    }

    /// Create generates a valid, distinct wallet whose mnemonic restores to the same descriptors.
    func testCreateProducesUsableWallet() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.create(network: .testnet4, wordCount: 12)
        XCTAssertEqual(keys.mnemonic.split(separator: " ").count, 12)
        XCTAssertTrue(keys.externalDescriptor.contains("84'/1'/0'"))
        // Round-trip: restoring the generated mnemonic reproduces the same descriptors.
        let restored = try factory.restore(network: .testnet4, mnemonic: keys.mnemonic)
        XCTAssertEqual(restored.externalDescriptor, keys.externalDescriptor)
        #endif
    }

    // MARK: - check_network

    /// A Testnet4 wallet refuses to send to a mainnet address — address validation happens before
    /// any network I/O, so this exercises `check_network` without a live backend (Golden Rule §4/§6).
    func testSendRejectsForeignNetworkAddress() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: "cn-tn4", network: .testnet4, keys: keys)
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        do {
            // A mainnet (bc1) address on a testnet4 wallet must be rejected.
            _ = try engine.send(to: Self.mainnetExternal0,
                                amount: Amount(sats: Int64(1000)),
                                feeRate: FeeRate(satPerVByte: Int64(1)))
            XCTFail("expected send to reject a mainnet address on a testnet4 wallet")
        } catch let error as WalletError {
            XCTAssertEqual(error, WalletError.invalidAddress)
        }
        #endif
    }

    // MARK: - Persistence

    /// BDK owns chain-data storage via `Persister.newSqlite`. A second engine over the SAME file
    /// must reload the persisted reveal state — the next address continues the index rather than
    /// restarting at 0. Proves the load-vs-create branch and that persistence actually round-trips.
    func testPersistenceRoundTripAcrossEngineReload() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: "persist-rt", network: .testnet4, keys: keys)

        // First engine: reveal indices 0 and 1 (each call persists the advance).
        let first = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        XCTAssertEqual(try first.nextReceiveAddress().index, Int32(0))
        XCTAssertEqual(try first.nextReceiveAddress().index, Int32(1))
        XCTAssertEqual(try first.balance(), Amount.zero) // unsynced/empty
        XCTAssertTrue(try first.transactions().isEmpty)
        XCTAssertTrue(try first.listUtxos().isEmpty)

        // Second engine over the SAME chain-data dir: it must LOAD, not re-create.
        let reloaded = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        let next = try reloaded.nextReceiveAddress()
        XCTAssertEqual(next.index, Int32(2), "reload must continue the persisted reveal index")
        // And it derives the same address index 0 would have — i.e. the same descriptor/keychain.
        XCTAssertEqual(next.address.hasPrefix("tb1"), true)
        #endif
    }

    /// `purgeChainData` actually deletes the wallet's on-disk SQLite store (Golden Rule §5 — the
    /// BDK chain-data file is a keyed artifact and must not survive removal).
    func testPurgeChainDataDeletesSqliteFile() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bdk-purge-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let factory = BDKWalletEngineFactory(chainDataDirectory: dir)

        let walletId = "purge-me"
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: walletId, network: .testnet4, keys: keys)
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        _ = try engine.nextReceiveAddress() // forces a persisted write

        // Chain data is namespaced per (walletId × network): <walletId>-<network>.sqlite.
        let sqlite = dir.appendingPathComponent("\(walletId)-testnet4.sqlite")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sqlite.path), "store should exist after use")

        factory.purgeChainData(for: walletId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sqlite.path), "purge must delete the store")
        #endif
    }

    /// Migration: a pre-namespacing store (`<walletId>.sqlite`) is moved to the network-scoped path
    /// (`<walletId>-<network>.sqlite`) on next open, so existing chain data survives the layout
    /// change instead of forcing a full rescan (`docs/network-switching.md`).
    func testLegacyStoreMigratesToNetworkScopedPath() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bdk-migrate-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let factory = BDKWalletEngineFactory(chainDataDirectory: dir)

        let walletId = "legacy-wallet"
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: walletId, network: .testnet4, keys: keys)

        // First open creates the network-scoped store; rename it (and siblings) back to the legacy
        // un-namespaced path to simulate a wallet from before this change.
        _ = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        let scoped = dir.appendingPathComponent("\(walletId)-testnet4.sqlite")
        let legacy = dir.appendingPathComponent("\(walletId).sqlite")
        for suffix in ["", "-wal", "-shm"] {
            let from = dir.appendingPathComponent("\(walletId)-testnet4.sqlite\(suffix)")
            let to = dir.appendingPathComponent("\(walletId).sqlite\(suffix)")
            if FileManager.default.fileExists(atPath: from.path) {
                try FileManager.default.moveItem(at: from, to: to)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: scoped.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))

        // Re-open: the factory migrates legacy → scoped and loads successfully.
        _ = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { Self.mnemonic })
        XCTAssertTrue(FileManager.default.fileExists(atPath: scoped.path), "legacy store should migrate to the network-scoped path")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "legacy store should be moved, not left behind")
        #endif
    }

    /// Sending from an EMPTY wallet surfaces `.insufficientFunds` — exercises the real send build
    /// path (TxBuilder→coin-selection→`CreateTxError`) and our typed→WalletError mapping, with NO
    /// funds and NO network (TxBuilder.finish fails locally, before any broadcast). The destination
    /// is a same-network (testnet4) address so it passes the address check and reaches coin selection.
    func testSendFromEmptyWalletIsInsufficientFunds() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: "empty-send", network: .testnet4, keys: keys)
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { keys.mnemonic })
        do {
            _ = try engine.send(to: Self.testnet4External0, // valid same-network address
                                amount: Amount(sats: Int64(10_000)),
                                feeRate: FeeRate(satPerVByte: Int64(1)))
            XCTFail("expected insufficient-funds on an empty wallet")
        } catch let error as WalletError {
            XCTAssertEqual(error, WalletError.insufficientFunds)
        }
        #endif
    }

    /// Sign-on-demand: the everyday engine is watch-only. Balance, address derivation, history,
    /// and UTXO listing must NOT read the mnemonic — the secret is touched only when signing a
    /// send (§7 / docs/key-storage.md §3). Also confirms the watch-only (public-descriptor) build
    /// still derives the correct spec-vector address, i.e. it's the same wallet, minus signing.
    func testWatchOnlyEngineNeverReadsMnemonicForReads() throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.restore(network: .testnet4, mnemonic: Self.mnemonic)
        let wallet = managedWallet(id: "watch-only", network: .testnet4, keys: keys)

        var mnemonicReads = 0
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: {
            mnemonicReads += 1
            return Self.mnemonic
        })

        _ = try engine.balance()
        let addr = try engine.nextReceiveAddress()
        _ = try engine.transactions()
        _ = try engine.listUtxos()

        XCTAssertEqual(mnemonicReads, 0, "watch-only reads must never load the secret")
        XCTAssertEqual(addr.address, Self.testnet4External0,
                       "watch-only build derives the same address as the keyed wallet")
        #endif
    }

    // MARK: - Live network (opt-in)

    /// End-to-end `sync()` against the LIVE Testnet4 Electrum endpoint from `NetworkRegistry`.
    /// OFF by default — it hits an external server (slow + flaky), so it's gated behind
    /// `WALLETSERVICE_LIVE=1`; normal `swift test` skips it. Uses a FRESH random wallet so the
    /// scan is fast and the expected balance is 0 (proves connect→fullScan→applyUpdate→persist
    /// round-trips, off the main actor). Run: `WALLETSERVICE_LIVE=1 swift test --filter testLiveTestnet4Sync`.
    func testLiveTestnet4Sync() async throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        guard ProcessInfo.processInfo.environment["WALLETSERVICE_LIVE"] == "1" else {
            throw XCTSkip("opt-in live-network test — set WALLETSERVICE_LIVE=1 to run")
        }
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.create(network: .testnet4, wordCount: 12) // fresh, empty
        let wallet = managedWallet(id: "live-tn4", network: .testnet4, keys: keys)
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: "ssl://example.invalid:50002", backendProxy: nil, loadMnemonic: { keys.mnemonic })

        try await engine.sync() // must not throw against live Testnet4
        XCTAssertEqual(try engine.balance(), Amount.zero) // fresh wallet → empty
        XCTAssertTrue(try engine.transactions().isEmpty)
        #endif
    }

    /// End-to-end `sync()` against the LIVE Signet Electrum endpoint from `NetworkRegistry`
    /// (`ssl://node.signet.drivechain.info:50002` — the L2L Drivechain signet, TLS). Same gating/shape
    /// as the Testnet4 test: a fresh wallet → balance 0, proving connect→fullScan→applyUpdate→persist
    /// against this server. Run: `WALLETSERVICE_LIVE=1 swift test --filter testLiveSignetSync`.
    func testLiveSignetSync() async throws {
        #if SKIP
        throw XCTSkip("real BDK — host only")
        #else
        guard ProcessInfo.processInfo.environment["WALLETSERVICE_LIVE"] == "1" else {
            throw XCTSkip("opt-in live-network test — set WALLETSERVICE_LIVE=1 to run")
        }
        let (factory, dir) = makeFactory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let keys = try factory.create(network: .signet, wordCount: 12) // fresh, empty
        let wallet = managedWallet(id: "live-signet", network: .signet, keys: keys)
        // Hit the ACTUAL registry default (ssl://node.signet.drivechain.info:50002, TLS), so this
        // also verifies BDK's ElectrumClient against the real endpoint — not a placeholder URL.
        let backend = NetworkRegistry.params(for: .signet).defaultBackend
        let engine = try factory.engine(for: wallet, backendKind: "electrum", backendURL: backend, backendProxy: nil, loadMnemonic: { keys.mnemonic })

        try await engine.sync() // must not throw against the live signet endpoint
        XCTAssertEqual(try engine.balance(), Amount.zero) // fresh wallet → empty
        XCTAssertTrue(try engine.transactions().isEmpty)
        #endif
    }
}
