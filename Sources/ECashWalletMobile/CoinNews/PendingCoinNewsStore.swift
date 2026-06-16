// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import WalletService

/// Local, persisted **optimistic** CoinNews you've just published — stories and topics — so they
/// show in the feed immediately instead of vanishing for the ~10 min it takes to mine + index.
/// Per-network (CoinNews is on-chain per network), JSON in UserDefaults.
///
/// Reconciliation: once the indexer returns the real copy, the pending one is dropped —
///   • **topics** by `topicHex` (canonical), • **stories** by content (topic + headline + body),
/// since the on-chain OP_RETURN's vout (hence the indexer's ItemID) isn't known at publish time.
/// A TTL also drops anything that never confirms (dropped/RBF'd tx) so it can't linger forever.
@MainActor
final class PendingCoinNewsStore {
    private let defaults: UserDefaults
    private let ttlSeconds: Int64

    init(defaults: UserDefaults = .standard, ttlSeconds: Int64 = 24 * 60 * 60) {
        self.defaults = defaults
        self.ttlSeconds = ttlSeconds
    }

    private struct PendingItem: Codable { let item: CoinNewsItem; let addedAt: Int64 }
    private struct PendingTopic: Codable { let topic: CoinNewsTopic; let addedAt: Int64 }

    private func itemsKey(_ n: WalletNetwork) -> String { "coinnews.pending.items.\(n.rawValue)" }
    private func topicsKey(_ n: WalletNetwork) -> String { "coinnews.pending.topics.\(n.rawValue)" }
    private var now: Int64 { Int64(Date().timeIntervalSince1970) }

    // MARK: - Read (TTL-pruned)

    func items(on network: WalletNetwork) -> [CoinNewsItem] {
        loadItems(network).map { $0.item }
    }
    func topics(on network: WalletNetwork) -> [CoinNewsTopic] {
        loadTopics(network).map { $0.topic }
    }

    // MARK: - Add

    func addItem(_ item: CoinNewsItem, on network: WalletNetwork) {
        var list = loadItems(network).filter { $0.item.id != item.id }
        list.insert(PendingItem(item: item, addedAt: now), at: 0)
        saveItems(list, network)
    }
    func addTopic(_ topic: CoinNewsTopic, on network: WalletNetwork) {
        var list = loadTopics(network).filter { $0.topic.topicHex != topic.topicHex }
        list.insert(PendingTopic(topic: topic, addedAt: now), at: 0)
        saveTopics(list, network)
    }

    // MARK: - Reconcile (drop confirmed + TTL-expired)

    /// Drop pending stories whose content now appears in the indexed feed.
    func reconcileItems(fetched: [CoinNewsItem], on network: WalletNetwork) {
        let cutoff = now - ttlSeconds
        let keep = loadItems(network).filter { p in
            p.addedAt >= cutoff && !fetched.contains { Self.sameStory($0, p.item) }
        }
        saveItems(keep, network)
    }
    /// Drop pending topics that the indexer now returns (by topicHex), and TTL-expired ones.
    func reconcileTopics(fetchedHexes: Set<String>, on network: WalletNetwork) {
        let cutoff = now - ttlSeconds
        let keep = loadTopics(network).filter { p in
            p.addedAt >= cutoff && !fetchedHexes.contains(p.topic.topicHex)
        }
        saveTopics(keep, network)
    }

    /// Two stories are "the same" if same topic + headline + body (our optimistic copy vs the
    /// indexed one). Good enough — a real duplicate-content collision is harmless (drops one copy).
    private static func sameStory(_ a: CoinNewsItem, _ b: CoinNewsItem) -> Bool {
        a.topicHex == b.topicHex && a.headline == b.headline && (a.body ?? "") == (b.body ?? "")
    }

    // MARK: - Persistence

    private func loadItems(_ n: WalletNetwork) -> [PendingItem] { decode(itemsKey(n)) }
    private func loadTopics(_ n: WalletNetwork) -> [PendingTopic] { decode(topicsKey(n)) }
    private func saveItems(_ v: [PendingItem], _ n: WalletNetwork) { encode(v, itemsKey(n)) }
    private func saveTopics(_ v: [PendingTopic], _ n: WalletNetwork) { encode(v, topicsKey(n)) }

    private func decode<T: Decodable>(_ key: String) -> [T] {
        guard let data = defaults.data(forKey: key),
              let v = try? JSONDecoder().decode([T].self, from: data) else { return [] }
        return v
    }
    private func encode<T: Encodable>(_ value: [T], _ key: String) {
        if value.isEmpty { defaults.removeObject(forKey: key); return }
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
