// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

#if !SKIP_BRIDGE

import Foundation

/// The keys produced when creating or restoring a wallet: the mnemonic (secret) plus the
/// PUBLIC (xpub-based / watch) descriptors that get stored in the WalletStore.
///
/// `public` + `// SKIP @nobridge`: reachable from sibling files' transpiled Kotlin, but kept off
/// the JNI bridge (it carries a mnemonic — never expose it across the bridge surface, §2).
// SKIP @nobridge
public struct WalletKeys: Equatable, Sendable {
    public let mnemonic: String
    public let externalDescriptor: String
    public let internalDescriptor: String

    public init(mnemonic: String, externalDescriptor: String, internalDescriptor: String) {
        self.mnemonic = mnemonic
        self.externalDescriptor = externalDescriptor
        self.internalDescriptor = internalDescriptor
    }
}

/// Abstracts the BDK-crossing work — mnemonic generation/validation, descriptor derivation, and
/// building the live `WalletEngine`. Keeping it behind a protocol lets `WalletManager`'s
/// orchestration be unit-tested with a mock (Robolectric), while the real BDK implementation is
/// integration-tested on device/emulator.
///
/// `public` + `// SKIP @nobridge`: cross-file Kotlin resolution, no JNI bridge (only
/// `WalletManager` is the bridged entry point).
// SKIP @nobridge
public protocol WalletEngineFactory: AnyObject {
    /// Generate a brand-new wallet (random mnemonic) + its public descriptors for the network.
    func create(network: WalletNetwork, wordCount: Int) throws -> WalletKeys
    /// Validate an imported mnemonic (throws `.invalidMnemonic` on bad checksum) + derive descriptors.
    func restore(network: WalletNetwork, mnemonic: String) throws -> WalletKeys
    /// Build the live engine for a wallet from its mnemonic.
    func engine(for wallet: ManagedWallet, mnemonic: String) throws -> WalletEngineProtocol
    /// Purge the wallet's BDK chain-data store (the factory owns it; the manager can't reach it).
    /// Best-effort: a failed delete must not block wallet removal — the secret is gone first.
    /// Called by `WalletManager.removeWallet` so removal purges EVERY keyed artifact (Golden Rule §5).
    func purgeChainData(for walletId: String)
}

/// Deterministic factory for unit tests — no BDK. Uses the canonical 12-word test vector.
/// `public` + `// SKIP @nobridge` (cross-file Kotlin resolution; not bridged).
// SKIP @nobridge
public final class MockWalletEngineFactory: WalletEngineFactory {
    public var mnemonicToReturn: String
    /// When true, `restore` rejects as if the checksum were invalid.
    public var rejectImport = false
    /// Records the walletIds passed to `purgeChainData`, so tests can assert removal purges it.
    public private(set) var purgedChainDataIds: [String] = []

    public init(mnemonic: String = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about") {
        self.mnemonicToReturn = mnemonic
    }

    public func create(network: WalletNetwork, wordCount: Int) throws -> WalletKeys {
        WalletKeys(mnemonic: mnemonicToReturn,
                   externalDescriptor: "wpkh(mock/0/*)",
                   internalDescriptor: "wpkh(mock/1/*)")
    }

    public func restore(network: WalletNetwork, mnemonic: String) throws -> WalletKeys {
        if rejectImport { throw WalletError.invalidMnemonic }
        return WalletKeys(mnemonic: mnemonic,
                          externalDescriptor: "wpkh(mock/0/*)",
                          internalDescriptor: "wpkh(mock/1/*)")
    }

    public func engine(for wallet: ManagedWallet, mnemonic: String) throws -> WalletEngineProtocol {
        MockWalletEngine(network: wallet.network)
    }

    public func purgeChainData(for walletId: String) {
        purgedChainDataIds.append(walletId)
    }
}

// The real BDK-backed factory lives in BDKWalletEngineFactory.swift (the BDK seam).

#endif // !SKIP_BRIDGE — bridged module: bodies excluded from the bridge compile
