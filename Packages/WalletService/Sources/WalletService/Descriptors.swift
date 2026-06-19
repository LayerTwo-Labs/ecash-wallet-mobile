// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

#if !SKIP_BRIDGE

import Foundation

/// Network-aware BIP84 (native segwit, `wpkh`) descriptor templates.
/// Coin-type is per network — `0'` mainnet, `1'` every test network — so a mainnet
/// descriptor can never be reused on a testnet wallet or vice-versa.
///
/// These helpers assemble derivation paths and descriptor STRINGS only. Turning a key
/// into a usable descriptor (and any private-key handling) is BDK's job in `WalletEngine`.
// `internal` (NOT public, NOT bridged): these are module-internal string helpers consumed only by
// WalletService's own tests (`@testable import`), not by any sibling main-module file and not by
// the app — so they need neither cross-file Kotlin visibility (no `public`) nor a JNI bridge. Making
// the type `public` would force its nested `Keychain` enum to be bridged (the parent's @nobridge
// does NOT cascade to nested types), and that bridge can't resolve the `#if !SKIP_BRIDGE`-excluded
// `Descriptors` in the bridge pass. Internal sidesteps the whole thing.
enum Descriptors {
    enum Keychain {
        case external // receive: .../0/*
        case change // internal: .../1/*

        var branch: UInt32 {
            switch self {
            // Wrap literals so Skip emits Kotlin UInt, not Int (transpilation type rule).
            case .external: return UInt32(0)
            case .change: return UInt32(1)
            }
        }
    }

    /// The account-level derivation path for a network, e.g. "m/84'/1'/0'" on L2L Signet.
    static func accountPath(for network: WalletNetwork, account: Int32 = 0) -> String {
        let coinType = NetworkRegistry.params(for: network).coinType
        return "m/84'/\(coinType)'/\(account)'"
    }

    /// The full path for a keychain branch, e.g. "m/84'/0'/0'/0/*" (external, mainnet).
    static func keychainPath(for network: WalletNetwork,
                                    keychain: Keychain,
                                    account: Int32 = 0) -> String {
        "\(accountPath(for: network, account: account))/\(keychain.branch)/*"
    }

    /// A `wpkh` descriptor string for a given key expression and keychain branch.
    /// `keyExpression` is whatever BDK hands us (an xprv/xpub with origin), e.g.
    /// "[fingerprint/84'/1'/0']tpub.../0/*". We only frame it as `wpkh(...)`.
    static func wpkh(_ keyExpression: String) -> String {
        "wpkh(\(keyExpression))"
    }
}

#endif // !SKIP_BRIDGE — bridged module: bodies excluded from the bridge compile
