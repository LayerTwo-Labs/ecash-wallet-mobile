// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Encodes CoinNews messages into the on-chain `OP_RETURN` wire format (CoinNews Protocol draft,
/// BSD-2). Pure byte assembly — no platform deps, so it compiles natively on both platforms in Fuse
/// (same posture as the read layer). The produced `Data` is handed to the BDK seam to build an
/// `OP_RETURN` output (`TxBuilder.addData`).
///
/// Phase 1 covers the **unsigned** types — Topic Creation (§5) and Story (§6) — which need no
/// SHA-256 or Schnorr (attribution falls to the spending tx's input). Comment/Vote (§7/§8, BIP-340
/// signed) + ItemID land in a later phase.
///
/// Envelope (§1): `"CN"(0x43 0x4E) ‖ TypeTag(1) ‖ rest…`. Lengths use Bitcoin compact-size varints
/// (§2). The single `OP_RETURN` push is capped at 80 bytes by relay policy — longer logical messages
/// chunk via Continuation (§9, not yet implemented); `encode*` here targets the single-push case.
enum CoinNewsCodec {
    static let magic: [UInt8] = [0x43, 0x4E]   // "CN"

    enum TypeTag: UInt8 {
        case topicCreation = 0x01
        case story = 0x02
        case comment = 0x03
        case upvote = 0x04
        case downvote = 0x05
        case continuation = 0x06
    }

    /// Story subtype (§10 tag 0x05).
    enum StorySubtype: Int {
        case link = 0, text = 1, ask = 2, show = 3, poll = 4, job = 5
    }

    // MARK: - Primitives

    /// Bitcoin "compact size" varint (§2), little-endian for the multi-byte forms.
    /// Compute in Int64, not Int: on 32-bit Android (armv7, built for release) Swift `Int` is 32-bit,
    /// so the `0xFFFF_FFFF` bound and the >>24/>>56 shifts overflow. Int64 = Kotlin Long everywhere.
    static func varint(_ value: Int) -> [UInt8] {
        let n = Int64(value)
        if n <= 0xFC {
            return [UInt8(n)]
        } else if n <= 0xFFFF {
            return [0xFD, UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF)]
        } else if n <= 0xFFFF_FFFF {
            return [0xFE,
                    UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF),
                    UInt8((n >> 16) & 0xFF), UInt8((n >> 24) & 0xFF)]
        } else {
            var out: [UInt8] = [0xFF]
            for i in 0..<8 { out.append(UInt8((n >> (8 * i)) & 0xFF)) }
            return out
        }
    }

    /// A varint-prefixed UTF-8 string (`varint(len) ‖ bytes`).
    static func lenPrefixed(_ string: String) -> [UInt8] {
        let bytes = Array(string.utf8)
        return varint(bytes.count) + bytes
    }

    /// One TLV tuple (§10): `tag(1) ‖ varint(length) ‖ value`.
    static func tlv(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
        [tag] + varint(value.count) + value
    }

    /// Parse a 4-byte topic from an 8-char hex string (e.g. "a1a1a1a1"); nil if malformed.
    static func topicBytes(fromHex hex: String) -> [UInt8]? {
        let chars = Array(hex)
        guard chars.count == 8 else { return nil }
        var out: [UInt8] = []
        var i = 0
        while i < 8 {
            guard let hi = hexNibble(chars[i]), let lo = hexNibble(chars[i + 1]) else { return nil }
            out.append(UInt8(hi * 16 + lo))
            i += 2
        }
        return out
    }

    private static func hexNibble(_ c: Character) -> Int? {
        switch c {
        case "0"..."9": return Int(String(c))
        case "a", "A": return 10
        case "b", "B": return 11
        case "c", "C": return 12
        case "d", "D": return 13
        case "e", "E": return 14
        case "f", "F": return 15
        default: return nil
        }
    }

    // MARK: - Messages

    /// Topic Creation (§5): `"CN" ‖ 0x01 ‖ topic(4) ‖ retention_days(1) ‖ name(varint+UTF-8)`.
    /// `retentionDays = 0` ⇒ infinite.
    static func encodeTopicCreation(topic: [UInt8], retentionDays: Int, name: String) -> Data {
        var bytes = magic
        bytes.append(TypeTag.topicCreation.rawValue)
        bytes += topic
        bytes.append(UInt8(retentionDays & 0xFF))
        bytes += lenPrefixed(name)
        return Data(bytes)
    }

    /// Story (§6): `"CN" ‖ 0x02 ‖ topic(4) ‖ headline(varint+UTF-8) ‖ tlv*`.
    /// Unsigned. TLVs are appended in a fixed order (subtype, url, body, lang, nsfw) — order is not
    /// semantically significant per §10, but keeping it stable makes encodings reproducible/testable.
    static func encodeStory(topic: [UInt8],
                            headline: String,
                            subtype: StorySubtype? = nil,
                            url: String? = nil,
                            body: String? = nil,
                            lang: String? = nil,
                            nsfw: Bool = false) -> Data {
        var bytes = magic
        bytes.append(TypeTag.story.rawValue)
        bytes += topic
        bytes += lenPrefixed(headline)

        if let subtype { bytes += tlv(0x05, [UInt8(subtype.rawValue & 0xFF)]) }
        if let url { bytes += tlv(0x01, Array(url.utf8)) }
        if let body { bytes += tlv(0x02, Array(body.utf8)) }
        if let lang { bytes += tlv(0x03, Array(lang.utf8)) }
        if nsfw { bytes += tlv(0x04, [0x01]) }

        return Data(bytes)
    }
}
