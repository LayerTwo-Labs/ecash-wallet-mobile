// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
#if !SKIP_BRIDGE
#if !os(Android)
import BitcoinDevKit          // bdk-swift (Apple)
#elseif SKIP
import org.bitcoindevkit.__   // bdk-android (Kotlin)
#endif

/// Derives the wallet's CoinNews **author identity key** — one BIP-340 identity per wallet (seed),
/// at a dedicated derivation path distinct from the `m/84'` spend keys, so it's recoverable on
/// restore but cryptographically independent from on-chain addresses (DECISION 2026-06-15,
/// `docs/coinnews-integration.md §3.2`). Network-independent: the same seed yields the same identity
/// regardless of the wallet's selected network. The private key is derived on demand for signing and
/// MUST NOT be persisted (Golden Rule §2).
///
/// TODO(pre-mainnet): confirm cross-wallet interop (e.g. BitWindow's identity path) and a
/// multi-identity index (`…/0'`, `…/1'`) before committing this as the canonical path.
public enum CoinNewsIdentity {
    /// eCash.com Wallet CoinNews identity path, v1. Hardened; account/index 0.
    public static let derivationPath = "m/1899h/0h/0h"

    /// 32-byte CoinNews identity private key for `mnemonicPhrase`. Throws `WalletError.invalidMnemonic`
    /// on a bad phrase; the caller derives just-in-time and drops it after signing.
    public static func privateKey(mnemonicPhrase: String, network: WalletNetwork) throws -> Data {
        let mnemonic: Mnemonic
        do {
            mnemonic = try Mnemonic.fromString(mnemonic: mnemonicPhrase)
        } catch {
            throw WalletError.invalidMnemonic
        }
        let secretKey = DescriptorSecretKey(network: BDKSeam.network(network), mnemonic: mnemonic, password: nil)
        let derived = try secretKey.derive(path: DerivationPath(path: derivationPath))
        // bdk-swift's secretBytes() returns Data; bdk-android's returns a Kotlin ByteArray.
        #if !os(Android)
        return derived.secretBytes()
        #elseif SKIP
        return Data(platformValue: derived.secretBytes())
        #endif
    }
}
#endif // !SKIP_BRIDGE
