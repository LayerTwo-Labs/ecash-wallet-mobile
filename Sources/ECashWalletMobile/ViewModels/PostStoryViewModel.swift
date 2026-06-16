// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse   // @Observable must drive the Android (Compose) UI in Fuse
import WalletService

/// Drives the "Post a Story" (CoinNews §6, unsigned) compose flow: topic + headline + body + fee,
/// with a live cost estimate. Builds the `OP_RETURN` payload with `CoinNewsCodec` and publishes via
/// the injected closure (AppState → `WalletManager.publishOpReturn`). Platform-agnostic/testable.
@MainActor
@Observable
final class PostStoryViewModel {
    enum Step: Equatable {
        case editing
        case publishing
        case published          // broadcast accepted (optimistic)
        case failed(String)
    }

    /// Fee tiers + a Custom option. The fee IS the only CoinNews anti-spam/boost knob (spec §14),
    /// so we let the user raise it beyond the presets via `.custom` (`customFeeText`).
    enum FeeTier: String, CaseIterable, Hashable {
        case slow, normal, fast, custom
        var label: String {
            switch self {
            case .slow: return "Slow"
            case .normal: return "Normal"
            case .fast: return "Fast"
            case .custom: return "Custom"
            }
        }
        /// Preset sat/vB (custom is overridden by `customFeeText` — 0 here is a never-used sentinel).
        var satPerVByte: Int64 {
            switch self {
            case .slow: return 1
            case .normal: return 2
            case .fast: return 5
            case .custom: return 0
            }
        }
    }

    // Rough non-witness vsize for the funding skeleton (1 P2WPKH input + change + overhead); the
    // OP_RETURN output adds ~11 B + payload. Estimate only — labelled "≈" in the UI.
    private static let baseVsize: Int64 = 110
    private static let opReturnOverhead: Int64 = 11

    /// Reserved "global / no topic" id (spec §3).
    static let globalTopicHex = "00000000"

    let network: WalletNetwork
    let unitLabel: String
    /// Topics fetched from the indexer (`ListTopics`) — the compose topic picker's options, plus
    /// "Global". Posting under a brand-new topic (Topic Creation §5) is a separate future flow.
    let availableTopics: [CoinNewsTopic]

    var topicHex: String = PostStoryViewModel.globalTopicHex   // selected topic id (default global)
    var headline: String = ""
    var body: String = ""
    var url: String = ""
    var tier: FeeTier = .normal
    var customFeeText: String = "10"   // sat/vB, used when tier == .custom
    private(set) var step: Step = .editing

    /// The effective fee rate (sat/vB): the preset tier, or the parsed custom value (min 1).
    var effectiveSatPerVByte: Int64 {
        if tier == .custom { return max(1, Int64(customFeeText.filter { $0.isNumber }) ?? 1) }
        return tier.satPerVByte
    }
    var effectiveFeeRate: FeeRate { FeeRate(satPerVByte: effectiveSatPerVByte) }

    private let publish: (_ payloadHex: String, _ feeRate: FeeRate) async throws -> WalletTx
    /// Hands back an optimistic `CoinNewsItem` (for the feed) + the tx (for Activity).
    private let onPublished: @MainActor (CoinNewsItem, WalletTx) -> Void
    private let fiatString: (Int64) -> String?
    /// Device-auth gate before broadcasting (Golden Rule §7) — publishing spends coins, like Send.
    /// AppState wires this to `DeviceAuth` when app-lock is on, or a pass-through when it's off.
    private let authorize: (String) async -> Bool

    init(network: WalletNetwork,
         unitLabel: String,
         availableTopics: [CoinNewsTopic] = [],
         publish: @escaping (_ payloadHex: String, _ feeRate: FeeRate) async throws -> WalletTx,
         onPublished: @escaping @MainActor (CoinNewsItem, WalletTx) -> Void,
         fiatString: @escaping (Int64) -> String? = { _ in nil },
         authorize: @escaping (String) async -> Bool = { _ in true }) {
        self.network = network
        self.unitLabel = unitLabel
        self.availableTopics = availableTopics
        self.publish = publish
        self.onPublished = onPublished
        self.fiatString = fiatString
        self.authorize = authorize
    }

    /// Display name for the currently-selected topic ("Global" for the reserved id, else the topic's
    /// name, else its short hex).
    var selectedTopicName: String {
        if topicHex == Self.globalTopicHex { return "Global" }
        if let t = availableTopics.first(where: { $0.topicHex == topicHex }) { return t.name }
        return topicHex
    }

    // MARK: - Validation + payload

    /// The 4 topic bytes, or nil if the field isn't exactly 8 hex chars.
    private var topicBytes: [UInt8]? { CoinNewsCodec.topicBytes(fromHex: topicHex) }

    var topicValid: Bool { topicBytes != nil }

    /// The encoded Story payload for the current fields, or nil if not yet valid.
    var payload: Data? {
        guard let topic = topicBytes, !trimmedHeadline.isEmpty else { return nil }
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoinNewsCodec.encodeStory(
            topic: topic,
            headline: trimmedHeadline,
            subtype: trimmedURL.isEmpty ? .text : .link,
            url: trimmedURL.isEmpty ? nil : trimmedURL,
            body: trimmedBody.isEmpty ? nil : trimmedBody)
    }

    private var trimmedHeadline: String { headline.trimmingCharacters(in: .whitespacesAndNewlines) }

    var payloadByteCount: Int { payload?.count ?? 0 }

    var canPublish: Bool {
        if case .editing = step {} else { return false }
        return topicValid && !trimmedHeadline.isEmpty && payload != nil
    }

    // MARK: - Cost estimate

    /// Estimated miner fee to publish, in sats. `feeRate × (baseVsize + opReturnOverhead + payload)`.
    /// Approximate (assumes a single input) — shown with a "≈".
    var estimatedCostSats: Int64 {
        effectiveSatPerVByte * (Self.baseVsize + Self.opReturnOverhead + Int64(payloadByteCount))
    }

    /// Estimated cost formatted in the wallet's unit (e.g. "0.00000342 sBTC").
    var estimatedCostText: String {
        Amount(sats: estimatedCostSats).formattedCoin() + " " + unitLabel
    }

    /// Fiat estimate for the cost, if a rate is available (mainnet); else nil.
    var estimatedCostFiat: String? { fiatString(estimatedCostSats) }

    // MARK: - Publish

    func publishStory() async {
        guard canPublish, let payload else { return }
        // Biometric/passcode gate before spending coins (§7). On cancel/failure, stay editing.
        guard await authorize("Authorize publishing this story") else { return }
        step = .publishing
        do {
            let tx = try await publish(Self.hex(payload), effectiveFeeRate)
            // Optimistic feed copy: keyed by txid (local id), reconciled by content once indexed.
            // No createdAtRaw — the "Broadcasting…" badge conveys it's in flight.
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = CoinNewsItem(
                id: "pending:\(tx.txid)",
                topicHex: topicHex,
                headline: trimmedHeadline,
                body: trimmedBody.isEmpty ? nil : trimmedBody,
                url: trimmedURL.isEmpty ? nil : trimmedURL)
            onPublished(item, tx)
            step = .published
        } catch let error as WalletError {
            step = .failed(error.userMessage)
        } catch {
            step = .failed("Couldn't publish. Please try again.")
        }
    }

    /// Retry after a failure.
    func retry() async {
        guard case .failed = step else { return }
        step = .editing
        await publishStory()
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
