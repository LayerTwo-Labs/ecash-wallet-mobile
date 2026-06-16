// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing
@testable import ECashWalletMobile

/// CoinNews wire-format encoder, checked against the spec's normative test vectors (CoinNews
/// Protocol draft §"Test Vectors") + the §2 varint table and §6 size claims.
@Suite struct CoinNewsCodecTests {

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Spec test vectors

    @Test func topicCreationMatchesSpecVector() {
        // Spec: Topic Creation "Hacker News", 30-day retention, topic 0x484e5321.
        let topic: [UInt8] = [0x48, 0x4E, 0x53, 0x21]
        let data = CoinNewsCodec.encodeTopicCreation(topic: topic, retentionDays: 30, name: "Hacker News")
        // "CN" 01 ‖ 484e5321 ‖ 1e ‖ 0b ‖ "Hacker News"
        #expect(hex(data) == "434e01484e53211e0b4861636b6572204e657773")
    }

    @Test func storyMatchesSpecVectorShape() {
        // Spec: link Story in topic 0x484e5321, 45-byte headline, subtype=link, 53-byte url → 111 B.
        let topic: [UInt8] = [0x48, 0x4E, 0x53, 0x21]
        let headline = "Microsoft and OpenAI end revenue-sharing deal"   // 45 bytes
        #expect(Array(headline.utf8).count == 45)
        let url = String(repeating: "x", count: 53)                       // stand-in 53-byte URL
        let data = CoinNewsCodec.encodeStory(topic: topic, headline: headline, subtype: .link, url: url)

        #expect(data.count == 111)                                        // 2+1+4+1+45+3+2+53
        let h = hex(data)
        #expect(h.hasPrefix("434e02" + "484e5321"))                       // CN ‖ 0x02 ‖ topic
        #expect(h.contains("2d" + Array(headline.utf8).map { String(format: "%02x", $0) }.joined()))  // varint(45)=2d + headline
        #expect(h.contains("050100"))                                     // TLV subtype=link (05 01 00)
        #expect(h.contains("0135"))                                       // TLV url tag(01) + varint(53)=0x35
    }

    // MARK: - Headline-only Story = 8 + headline bytes (§6)

    @Test func headlineOnlyStorySize() {
        let topic: [UInt8] = [0xA1, 0xA1, 0xA1, 0xA1]
        let data = CoinNewsCodec.encodeStory(topic: topic, headline: "Hi")
        #expect(data.count == 8 + 2)                                      // magic2 + tag1 + topic4 + len1 + "Hi"
        // CN ‖ 0x02 ‖ a1a1a1a1 ‖ varint(2)=02 ‖ "Hi"(48 69)
        #expect(hex(data) == "434e02a1a1a1a1024869")
    }

    // MARK: - Varint (§2)

    @Test func varintBoundaries() {
        #expect(CoinNewsCodec.varint(0) == [0x00])
        #expect(CoinNewsCodec.varint(252) == [0xFC])
        #expect(CoinNewsCodec.varint(253) == [0xFD, 0xFD, 0x00])          // 3 B, LE
        #expect(CoinNewsCodec.varint(65_535) == [0xFD, 0xFF, 0xFF])
        #expect(CoinNewsCodec.varint(65_536) == [0xFE, 0x00, 0x00, 0x01, 0x00])  // 5 B, LE
    }

    // MARK: - TLV + helpers

    @Test func tlvFraming() {
        #expect(CoinNewsCodec.tlv(0x05, [0x00]) == [0x05, 0x01, 0x00])    // subtype=link
        #expect(CoinNewsCodec.tlv(0x04, []) == [0x04, 0x00])              // flag-style (length 0)
    }

    @Test func topicHexParsing() {
        #expect(CoinNewsCodec.topicBytes(fromHex: "a1a1a1a1") == [0xA1, 0xA1, 0xA1, 0xA1])
        #expect(CoinNewsCodec.topicBytes(fromHex: "484E5321") == [0x48, 0x4E, 0x53, 0x21])
        #expect(CoinNewsCodec.topicBytes(fromHex: "xyz") == nil)
        #expect(CoinNewsCodec.topicBytes(fromHex: "a1a1a1") == nil)       // wrong length
    }
}
