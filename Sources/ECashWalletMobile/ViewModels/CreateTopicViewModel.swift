// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse
import WalletService

/// Compose + broadcast a CoinNews **Topic Creation** (§5, unsigned): `CN ‖ 0x01 ‖ topic(4) ‖
/// retention(1) ‖ name`. The 4-byte topic ID is **prefilled with an auto-minted random hex** so the
/// user never has to think about it, but it stays editable for anyone who wants a specific ID (e.g.
/// to match an existing topic, or BitWindow interop). First confirmed creation per ID wins the name
/// (§5), and discovery is by name via `ListTopics`, so the ID is just opaque identity. Same publish
/// path + bio gate as posting a Story.
///
/// NOTE for L2L: a nicer scheme to propose — derive the ID from the name (`sha256(name)[:4]`) so the
/// same name maps to one topic everywhere (no fragmentation). That needs cross-client agreement;
/// until then a random default is fine (dup-named topics just coexist, nothing is lost).
@MainActor
@Observable
final class CreateTopicViewModel {
    enum Step: Equatable {
        case editing, publishing, published, failed(String)
    }

    private static let baseVsize: Int64 = 110
    private static let opReturnOverhead: Int64 = 11

    let network: WalletNetwork
    let unitLabel: String

    /// 4-byte topic id as 8 hex chars — prefilled with a random default in `init`, editable.
    var topicHex: String
    var name: String = ""
    var retentionText: String = "0"     // days; 0 = infinite (§5)
    var tier: PostStoryViewModel.FeeTier = .normal
    var customFeeText: String = "10"
    private(set) var step: Step = .editing

    private let publish: (_ payloadHex: String, _ feeRate: FeeRate) async throws -> WalletTx
    private let onCreated: @MainActor (_ topic: CoinNewsTopic, _ tx: WalletTx) -> Void
    private let fiatString: (Int64) -> String?
    private let authorize: (String) async -> Bool

    init(network: WalletNetwork,
         unitLabel: String,
         publish: @escaping (_ payloadHex: String, _ feeRate: FeeRate) async throws -> WalletTx,
         onCreated: @escaping @MainActor (_ topic: CoinNewsTopic, _ tx: WalletTx) -> Void,
         fiatString: @escaping (Int64) -> String? = { _ in nil },
         authorize: @escaping (String) async -> Bool = { _ in true }) {
        self.network = network
        self.unitLabel = unitLabel
        self.topicHex = (0..<4).map { _ in String(format: "%02x", UInt8.random(in: UInt8.min ... UInt8.max)) }.joined()
        self.publish = publish
        self.onCreated = onCreated
        self.fiatString = fiatString
        self.authorize = authorize
    }

    // MARK: - Validation + payload

    private var topicBytes: [UInt8]? { CoinNewsCodec.topicBytes(fromHex: topicHex) }
    var topicValid: Bool { topicBytes != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var retentionDays: Int { min(255, max(0, Int(retentionText.filter { $0.isNumber }) ?? 0)) }

    var payload: Data? {
        guard let topic = topicBytes, !trimmedName.isEmpty else { return nil }
        return CoinNewsCodec.encodeTopicCreation(topic: topic, retentionDays: retentionDays, name: trimmedName)
    }

    var canCreate: Bool {
        if case .editing = step {} else { return false }
        return topicValid && !trimmedName.isEmpty && payload != nil
    }

    // MARK: - Fee + cost

    var effectiveSatPerVByte: Int64 {
        if tier == .custom { return max(1, Int64(customFeeText.filter { $0.isNumber }) ?? 1) }
        return tier.satPerVByte
    }
    var effectiveFeeRate: FeeRate { FeeRate(satPerVByte: effectiveSatPerVByte) }

    var estimatedCostSats: Int64 {
        effectiveSatPerVByte * (Self.baseVsize + Self.opReturnOverhead + Int64(payload?.count ?? 0))
    }
    var estimatedCostText: String { Amount(sats: estimatedCostSats).formattedCoin() + " " + unitLabel }
    var estimatedCostFiat: String? { fiatString(estimatedCostSats) }

    // MARK: - Create

    func create() async {
        guard canCreate, let payload else { return }
        guard await authorize("Authorize creating this topic") else { return }
        step = .publishing
        do {
            let tx = try await publish(Self.hex(payload), effectiveFeeRate)
            let topic = CoinNewsTopic(topicHex: topicHex.lowercased(), name: trimmedName,
                                      retentionDays: retentionDays)
            onCreated(topic, tx)
            step = .published
        } catch let error as WalletError {
            step = .failed(error.userMessage)
        } catch {
            step = .failed("Couldn't create the topic. Please try again.")
        }
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
