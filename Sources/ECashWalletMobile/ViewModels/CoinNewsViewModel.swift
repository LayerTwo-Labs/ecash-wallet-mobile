// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse   // @Observable must drive the Android (Compose) UI in Fuse
import WalletService

/// Drives the News tab: loads the CoinNews front page (+ topic names for display) through a
/// `CoinNewsFetching`, exposing loading/loaded/error so the screen can react. Platform-agnostic and
/// testable — it depends only on the injected fetcher (AppState wires the backend), never on a
/// concrete server.
///
/// **One instance per network** (CoinNews is on-chain per network — topics, feed, and the local
/// follow set all differ by network). `AppState` caches one of these per `WalletNetwork` and vends
/// the selected wallet's; each survives tab switches.
@MainActor
@Observable
final class CoinNewsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)   // user-safe message
    }

    /// What the feed is scoped to. `.followed` reads the mirrored `followed` set (the per-network
    /// subscription store); `.topic` is a single-board view (tap a topic in the manager).
    enum FeedFilter: Equatable {
        case all
        case followed
        case topic(String)   // topicHex
    }

    /// The network this feed belongs to (CoinNews is per-network).
    let network: WalletNetwork

    private(set) var state: State = .idle
    private(set) var items: [CoinNewsItem] = []
    /// Known topics (from the indexer's `ListTopics`) — drives the topic name lookup + the compose
    /// topic picker.
    private(set) var topics: [CoinNewsTopic] = []
    private var topicNames: [String: String] = [:]

    /// Active feed scope (set from the topic manager). Drives `visibleItems`.
    var feedFilter: FeedFilter = .all
    /// Mirror of the per-network followed topic IDs (owned by `TopicSubscriptionStore`); kept in sync
    /// by `AppState`/`TopicsViewModel` so the `.followed` filter can be applied locally.
    var followed: Set<String> = []

    private let fetcher: CoinNewsFetching

    init(network: WalletNetwork, fetcher: CoinNewsFetching) {
        self.network = network
        self.fetcher = fetcher
    }

    /// The items the feed should actually show, after applying `feedFilter`.
    var visibleItems: [CoinNewsItem] {
        switch feedFilter {
        case .all: return items
        case .followed: return items.filter { followed.contains($0.topicHex) }
        case .topic(let hex): return items.filter { $0.topicHex == hex }
        }
    }

    /// Display name of the active single-topic filter (falls back to the hex), or nil if not scoped
    /// to one topic.
    var activeTopicName: String? {
        if case .topic(let hex) = feedFilter { return topicNames[hex] ?? hex }
        return nil
    }

    /// Topic display name for an item's `topicHex`, if known.
    func topicName(for topicHex: String) -> String? { topicNames[topicHex] }

    /// Optimistically surface a just-created topic before the indexer picks it up (the on-chain
    /// creation won't be queryable until it's mined + indexed). No-op if already known.
    func addLocalTopic(_ topic: CoinNewsTopic) {
        guard !topics.contains(where: { $0.topicHex == topic.topicHex }) else { return }
        topics.append(topic)
        topicNames[topic.topicHex] = topic.name
    }

    /// Load once (no-op if already loaded). Called from the screen's `.task`.
    func load() async {
        if case .loaded = state { return }
        await reload()
    }

    /// Force a refresh (pull-to-refresh).
    func refresh() async { await reload() }

    private func reload() async {
        state = .loading
        do {
            let fetchedTopics = try await fetcher.topics()
            topics = fetchedTopics
            var names: [String: String] = [:]
            for topic in fetchedTopics { names[topic.topicHex] = topic.name }
            topicNames = names

            items = try await fetcher.frontPage(limit: 50)
            state = .loaded
        } catch let error as CoinNewsError {
            state = .failed(Self.message(for: error))
        } catch {
            state = .failed("Couldn't load news. Pull to retry.")
        }
    }

    private static func message(for error: CoinNewsError) -> String {
        switch error {
        case .server(let status, let message): return message ?? "Server error (\(status))."
        case .network: return "Network error. Pull to retry."
        case .decode, .badURL: return "Couldn't read the news feed."
        }
    }
}
