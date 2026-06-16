// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import XCTest
@testable import WalletService

// Apple-only (real P256K + BDK key derivation; not runnable under Robolectric — see CoinNewsCryptoTests).
#if !SKIP
/// CoinNews signed-message assembly (Vote §8 / Comment §7) + identity-key derivation. Verifies the
/// exact wire layout AND that the embedded BIP-340 signature actually verifies against the embedded
/// author key over the spec's tagged-hash preimage — i.e. a full derive→sign→parse→verify round-trip.
final class CoinNewsMessageTests: XCTestCase {

    // BIP-340 test-vector key — used directly as a CoinNews identity key for the message tests.
    private let privHex = "B7E151628AED2A6ABF7158809CF4F3C762E7160F38B4DA56A784D9045190CFEF"
    private let targetId = Data([UInt8](repeating: 0xAB, count: 12))

    private func data(hex: String) -> Data {
        var bytes = [UInt8](); let c = Array(hex.utf8); var i = 0
        while i < c.count { bytes.append(UInt8(nib(c[i]) * 16 + nib(c[i + 1]))); i += 2 }
        return Data(bytes)
    }
    private func nib(_ b: UInt8) -> Int { let v = Int(b); if v >= 48 && v <= 57 { return v - 48 }; if v >= 97 && v <= 102 { return v - 87 }; return v - 55 }

    func testSignedVoteLayoutAndSignature() throws {
        let priv = data(hex: privHex)
        let payload = try CoinNewsMessage.signedVote(targetId: targetId, upvote: true,
                                                     identityPrivateKey: priv, auxRand: CoinNewsMessageTests.zeroAux)
        XCTAssertEqual(payload.count, 111)                                   // 2+1+12+32+64
        XCTAssertEqual([UInt8](payload.subdata(in: 0..<2)), [0x43, 0x4E])    // "CN"
        XCTAssertEqual(payload[2], 0x04)                                     // upvote tag
        XCTAssertEqual(payload.subdata(in: 3..<15), targetId)               // target_id

        let authorXpk = payload.subdata(in: 15..<47)
        XCTAssertEqual(authorXpk, try CoinNewsCrypto.xonlyPublicKey(privateKey: priv))

        let sig = payload.subdata(in: 47..<111)
        var preimage = Data([0x04]); preimage.append(targetId)
        let digest = CoinNewsCrypto.taggedHash("CoinNews/Vote", preimage)
        XCTAssertTrue(CoinNewsCrypto.schnorrVerify(signature: sig, message32: digest, xonlyPublicKey: authorXpk))
    }

    func testDownvoteTag() throws {
        let payload = try CoinNewsMessage.signedVote(targetId: targetId, upvote: false,
                                                     identityPrivateKey: data(hex: privHex), auxRand: CoinNewsMessageTests.zeroAux)
        XCTAssertEqual(payload[2], 0x05)                                     // downvote tag
    }

    func testSignedCommentLayoutAndSignature() throws {
        let priv = data(hex: privHex)
        let parentId = Data([UInt8](repeating: 0x11, count: 12))
        let body = "gm"
        let payload = try CoinNewsMessage.signedComment(parentId: parentId, body: body,
                                                        identityPrivateKey: priv, auxRand: CoinNewsMessageTests.zeroAux)
        // "CN" ‖ 0x03 ‖ parent_id(12) ‖ author_xpk(32) ‖ sig(64) ‖ tlv(0x02, "gm")
        let tlvBlob = Data([0x02, 0x02]) + Data(Array(body.utf8))           // tag, len=2, "gm"
        XCTAssertEqual(payload.count, 2 + 1 + 12 + 32 + 64 + tlvBlob.count)
        XCTAssertEqual(payload[2], 0x03)
        XCTAssertEqual(payload.subdata(in: 3..<15), parentId)
        XCTAssertEqual(payload.subdata(in: 111..<payload.count), tlvBlob)   // trailing TLV (after the 64-byte sig)

        let authorXpk = payload.subdata(in: 15..<47)
        let sig = payload.subdata(in: 47..<111)
        var preimage = Data(parentId); preimage.append(tlvBlob)
        let digest = CoinNewsCrypto.taggedHash("CoinNews/Comment", preimage)
        XCTAssertTrue(CoinNewsCrypto.schnorrVerify(signature: sig, message32: digest, xonlyPublicKey: authorXpk))
    }

    // MARK: - Identity derivation (real BDK)

    func testIdentityKeyIsDeterministicAndValid() throws {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let k1 = try CoinNewsIdentity.privateKey(mnemonicPhrase: mnemonic, network: .signet)
        let k2 = try CoinNewsIdentity.privateKey(mnemonicPhrase: mnemonic, network: .signet)
        XCTAssertEqual(k1.count, 32)
        XCTAssertEqual(k1, k2)                                              // deterministic
        // Network-independent (same seed → same identity regardless of the wallet's network view).
        XCTAssertEqual(k1, try CoinNewsIdentity.privateKey(mnemonicPhrase: mnemonic, network: .testnet4))
        // Produces a usable BIP-340 key: derive author xpk, sign a vote, verify.
        let xpk = try CoinNewsCrypto.xonlyPublicKey(privateKey: k1)
        XCTAssertEqual(xpk.count, 32)
        let payload = try CoinNewsMessage.signedVote(targetId: targetId, upvote: true,
                                                     identityPrivateKey: k1, auxRand: CoinNewsMessageTests.zeroAux)
        var preimage = Data([0x04]); preimage.append(targetId)
        XCTAssertTrue(CoinNewsCrypto.schnorrVerify(signature: payload.subdata(in: 47..<111),
                                                   message32: CoinNewsCrypto.taggedHash("CoinNews/Vote", preimage),
                                                   xonlyPublicKey: xpk))
    }

    private static let zeroAux = Data([UInt8](repeating: 0, count: 32))
}
#endif  // !SKIP
