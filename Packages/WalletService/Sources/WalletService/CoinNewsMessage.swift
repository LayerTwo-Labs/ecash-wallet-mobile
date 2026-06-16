// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

#if !SKIP_BRIDGE
/// Assembles + signs the SIGNED CoinNews messages — Vote (§8) and Comment (§7) — for broadcast as an
/// `OP_RETURN`. Signing needs the identity key + secp, so (unlike the unsigned Story/Topic codec in
/// the app module) this lives in the BDK seam. Vote is exactly 111 B; Comment carries a body TLV.
///
/// `auxRand` is the BIP-340 nonce randomness — pass 32 bytes (zeroed is BIP-340-valid and
/// deterministic; production callers SHOULD pass secure-random for fault-attack protection).
///
/// Transpile-safe construction: build `[UInt8]` (only `.append` + index reads, which transpile),
/// convert to `Data` once via `Data([UInt8])`. (`Data.append(...)` is NOT in SkipFoundation, and
/// byte literals need explicit `UInt8(...)` casts.)
public enum CoinNewsMessage {

    /// Vote (§8): `"CN" ‖ tag ‖ target_id(12) ‖ author_xpk(32) ‖ sig(64)` = 111 B exactly.
    /// `tag` = 0x04 upvote / 0x05 downvote. Sig is Schnorr over `tagged_hash("CoinNews/Vote", tag ‖ target_id)`.
    public static func signedVote(targetId: Data, upvote: Bool,
                                  identityPrivateKey: Data, auxRand: Data) throws -> Data {
        let tag: UInt8 = upvote ? UInt8(0x04) : UInt8(0x05)
        let authorXpk = try CoinNewsCrypto.xonlyPublicKey(privateKey: identityPrivateKey)

        var preimage = [UInt8]()
        preimage.append(tag)
        appendBytes(&preimage, targetId)
        let digest = CoinNewsCrypto.taggedHash("CoinNews/Vote", Data(preimage))
        let sig = try CoinNewsCrypto.schnorrSign(message32: digest, privateKey: identityPrivateKey, auxRand: auxRand)

        var payload = [UInt8]()
        payload.append(UInt8(0x43))   // "C"
        payload.append(UInt8(0x4E))   // "N"
        payload.append(tag)
        appendBytes(&payload, targetId)
        appendBytes(&payload, authorXpk)
        appendBytes(&payload, sig)
        return Data(payload)
    }

    /// Comment (§7): `"CN" ‖ 0x03 ‖ parent_id(12) ‖ author_xpk(32) ‖ sig(64) ‖ tlv*`.
    /// Sig is Schnorr over `tagged_hash("CoinNews/Comment", parent_id ‖ tlv_blob)`; the signed TLV
    /// blob (here the body, tag 0x02) is the SAME blob appended to the message.
    public static func signedComment(parentId: Data, body: String,
                                     identityPrivateKey: Data, auxRand: Data) throws -> Data {
        let authorXpk = try CoinNewsCrypto.xonlyPublicKey(privateKey: identityPrivateKey)
        let blob = tlv(UInt8(0x02), Array(body.utf8))   // [UInt8] body TLV

        var preimage = [UInt8]()
        appendBytes(&preimage, parentId)
        for b in blob { preimage.append(b) }
        let digest = CoinNewsCrypto.taggedHash("CoinNews/Comment", Data(preimage))
        let sig = try CoinNewsCrypto.schnorrSign(message32: digest, privateKey: identityPrivateKey, auxRand: auxRand)

        var payload = [UInt8]()
        payload.append(UInt8(0x43))
        payload.append(UInt8(0x4E))
        payload.append(UInt8(0x03))
        appendBytes(&payload, parentId)
        appendBytes(&payload, authorXpk)
        appendBytes(&payload, sig)
        for b in blob { payload.append(b) }
        return Data(payload)
    }

    // MARK: - Helpers (Data → [UInt8] via index reads; compact-size varint + TLV; §2/§10)

    private static func appendBytes(_ arr: inout [UInt8], _ data: Data) {
        for i in 0..<data.count { arr.append(data[i]) }
    }

    static func tlv(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
        var out = [UInt8]()
        out.append(tag)
        for b in varint(value.count) { out.append(b) }
        for b in value { out.append(b) }
        return out
    }

    static func varint(_ value: Int) -> [UInt8] {
        // Int64, not Int: on 32-bit Android (armv7, release) Swift `Int` is 32-bit and `0xFFFF_FFFF`
        // / the >>24 shifts overflow. Int64 = Kotlin Long.
        let n = Int64(value)
        var out = [UInt8]()
        if n <= 0xFC {
            out.append(UInt8(n))
        } else if n <= 0xFFFF {
            out.append(UInt8(0xFD))
            out.append(UInt8(n & 0xFF)); out.append(UInt8((n >> 8) & 0xFF))
        } else if n <= 0xFFFF_FFFF {
            out.append(UInt8(0xFE))
            out.append(UInt8(n & 0xFF)); out.append(UInt8((n >> 8) & 0xFF))
            out.append(UInt8((n >> 16) & 0xFF)); out.append(UInt8((n >> 24) & 0xFF))
        } else {
            out.append(UInt8(0xFF))
            for i in 0..<8 { out.append(UInt8((n >> (8 * i)) & 0xFF)) }
        }
        return out
    }
}
#endif // !SKIP_BRIDGE
