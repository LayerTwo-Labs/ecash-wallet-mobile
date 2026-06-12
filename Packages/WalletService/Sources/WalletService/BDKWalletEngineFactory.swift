// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later
//
// The real BDK-backed wallet factory — the BDK seam. Compiles natively with bdk-swift on Apple;
// transpiles to bdk-android on Android. See the bdk-swift-2.3.1-api-map memory.
//
// The ENTIRE file is `#if !SKIP_BRIDGE`: `WalletService` is a bridged transpiled module
// (`bridging: true`), so on Android the Fuse app's calls FORWARD (JNI) into this module's
// transpiled Kotlin (which holds the real bdk-android). The bridge *compile* (SKIP_BRIDGE) excludes
// all of this and uses Skip's generated forwarders — no BDK references, no duplicate symbols there.
// (Earlier this file hand-stubbed `throw .notImplemented` in the bridge pass; that stub was what
// actually ran on Android because bridging wasn't enabled.)

#if !SKIP_BRIDGE

import Foundation
#if !os(Android)
import BitcoinDevKit            // bdk-swift (Apple)
#elseif SKIP
import org.bitcoindevkit.__     // bdk-android (Kotlin)
#endif

// `public` + `// SKIP @nobridge`: `WalletManager()` constructs it cross-file (needs public for the
// transpiled Kotlin to resolve it), but it's BDK-backed so it must never reach the JNI bridge.
// SKIP @nobridge
public final class BDKWalletEngineFactory: WalletEngineFactory {
    /// Directory under which each wallet's BDK SQLite chain-data file lives (one file per
    /// `walletId`). Injectable for tests; defaults to `<applicationSupport>/chaindata`.
    private let chainDataDirectory: URL
    /// Optional Electrum endpoint override applied to every engine (test/Settings seam; `nil` = registry).
    private let electrumURLOverride: String?

    public init(chainDataDirectory: URL? = nil, electrumURLOverride: String? = nil) {
        self.electrumURLOverride = electrumURLOverride
        self.chainDataDirectory = chainDataDirectory
            ?? URL.applicationSupportDirectory.appendingPathComponent("chaindata", isDirectory: true)
    }

    /// Generate a brand-new wallet: random mnemonic → public BIP84 descriptors.
    public func create(network: WalletNetwork, wordCount: Int) throws -> WalletKeys {
        let mnemonic = Mnemonic(wordCount: BDKSeam.wordCount(wordCount))
        return try walletKeys(network: network, mnemonic: mnemonic)
    }

    /// Restore from a mnemonic phrase. `Mnemonic.fromString` validates the checksum/words and
    /// throws on bad input — mapped to `.invalidMnemonic` (no raw text leaks, §2).
    public func restore(network: WalletNetwork, mnemonic mnemonicPhrase: String) throws -> WalletKeys {
        let mnemonic: Mnemonic
        do {
            mnemonic = try Mnemonic.fromString(mnemonic: mnemonicPhrase)
        } catch {
            throw WalletError.invalidMnemonic
        }
        return try walletKeys(network: network, mnemonic: mnemonic)
    }

    /// Build the live engine for a wallet from its mnemonic. Re-derives the SECRET BIP84 descriptors
    /// at runtime (never persisted — Golden Rule §2/§7), opens the wallet's own BDK SQLite store, and
    /// wraps the live `Wallet`. First open has no persisted changeset, so `Wallet.load` throws and we
    /// fall through to the network-aware constructor; later opens reload (with `check_network`).
    public func engine(for wallet: ManagedWallet, mnemonic mnemonicPhrase: String) throws -> WalletEngineProtocol {
        let net = BDKSeam.network(wallet.network)

        let mnemonic: Mnemonic
        do {
            mnemonic = try Mnemonic.fromString(mnemonic: mnemonicPhrase)
        } catch {
            throw WalletError.invalidMnemonic
        }

        let secretKey = DescriptorSecretKey(network: net, mnemonic: mnemonic, password: nil)
        let externalDescriptor = Descriptor.newBip84(secretKey: secretKey,
                                                     keychainKind: BDKSeam.externalKeychain(), network: net)
        let internalDescriptor = Descriptor.newBip84(secretKey: secretKey,
                                                     keychainKind: BDKSeam.internalKeychain(), network: net)

        do {
            let persister = try makePersister(for: wallet.id)
            // `var` (not deferred `let`): assigning in both do/catch transpiles to a reassigned
            // Kotlin `val`, which Kotlin rejects.
            var bdkWallet: Wallet
            do {
                bdkWallet = try Wallet.load(descriptor: externalDescriptor,
                                            changeDescriptor: internalDescriptor,
                                            persister: persister)
            } catch {
                bdkWallet = try Wallet(descriptor: externalDescriptor,
                                       changeDescriptor: internalDescriptor,
                                       network: net,
                                       persister: persister)
                _ = try bdkWallet.persist(persister: persister)
            }
            let endpoint = electrumURLOverride ?? NetworkRegistry.params(for: wallet.network).defaultBackend
            return WalletEngine(wallet: bdkWallet, persister: persister,
                                network: wallet.network, electrumURL: endpoint)
        } catch {
            // Scrub: a BDK error string can embed key material — classify, never echo (Golden Rule §2).
            throw WalletError.mapping(rawDescription: "\(error)")
        }
    }

    /// Delete the wallet's BDK SQLite store (+ `-wal`/`-shm`). Best-effort (Golden Rule §5).
    public func purgeChainData(for walletId: String) {
        let base = chainDataDirectory.appendingPathComponent("\(walletId).sqlite")
        for suffix in ["", "-wal", "-shm"] {
            let url = suffix.isEmpty ? base
                : chainDataDirectory.appendingPathComponent("\(walletId).sqlite\(suffix)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    /// One SQLite file per wallet under `chainDataDirectory`, named by `walletId`.
    private func makePersister(for walletId: String) throws -> Persister {
        try FileManager.default.createDirectory(at: chainDataDirectory, withIntermediateDirectories: true)
        let path = chainDataDirectory.appendingPathComponent("\(walletId).sqlite").path
        return try Persister.newSqlite(path: path)
    }

    /// Derive the PUBLIC (watch) BIP84 descriptors for both keychains from a mnemonic.
    ///
    /// Built through the SAME `Descriptor.newBip84` path the runtime engine uses, then printed
    /// via Display — which is the descriptor's PUBLIC form (account-level tpub; the secret keymap
    /// only prints via `toStringWithSecret`). FIXED 2026-06-12: this previously fed the MASTER
    /// public key to `newBip84Public` (which expects an account-level key), persisting a
    /// master-tpub descriptor whose derived addresses matched nothing the wallet actually used.
    /// Building both from one construction makes stored-vs-runtime divergence impossible.
    private func walletKeys(network: WalletNetwork, mnemonic: Mnemonic) throws -> WalletKeys {
        let net = BDKSeam.network(network)
        let secretKey = DescriptorSecretKey(network: net, mnemonic: mnemonic, password: nil)
        let external = Descriptor.newBip84(secretKey: secretKey,
                                           keychainKind: BDKSeam.externalKeychain(), network: net)
        let change = Descriptor.newBip84(secretKey: secretKey,
                                         keychainKind: BDKSeam.internalKeychain(), network: net)
        // String interpolation forces Display (`.toString()` on Kotlin) — portable across bindings.
        return WalletKeys(mnemonic: "\(mnemonic)",
                          externalDescriptor: "\(external)",
                          internalDescriptor: "\(change)")
    }
}

#endif // !SKIP_BRIDGE — bridged module: bodies excluded from the bridge compile
