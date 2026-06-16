// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Testing
import WalletService
@testable import ECashWalletMobile

/// Topic management + per-network CoinNews behavior: feed filtering, optimistic topics, the local
/// per-network subscription store, the topic manager view model, network availability, and the
/// network-scoped seeded client.
@MainActor
@Suite struct CoinNewsTopicsTests {

    // MARK: - Fixtures

    private struct FakeFetcher: CoinNewsFetching {
        let topicsList: [CoinNewsTopic]
        let items: [CoinNewsItem]
        func topics() async throws -> [CoinNewsTopic] { topicsList }
        func frontPage(limit: Int) async throws -> [CoinNewsItem] { items }
        func newFeed(limit: Int) async throws -> [CoinNewsItem] { items }
    }

    private func item(_ id: String, _ topicHex: String) -> CoinNewsItem {
        CoinNewsItem(id: id, topicHex: topicHex, headline: "Headline \(id)")
    }
    private func topic(_ hex: String) -> CoinNewsTopic {
        CoinNewsTopic(topicHex: hex, name: "Topic \(hex)", retentionDays: 0)
    }

    private func loadedFeed() async -> CoinNewsViewModel {
        let vm = CoinNewsViewModel(
            network: .signet,
            fetcher: FakeFetcher(
                topicsList: [topic("aaaa"), topic("bbbb")],
                items: [item("1", "aaaa"), item("2", "bbbb"), item("3", "aaaa")]))
        await vm.load()
        return vm
    }

    // MARK: - Feed filtering

    @Test func feedFiltersByTopicAndFollowed() async {
        let vm = await loadedFeed()
        #expect(vm.visibleItems.count == 3)              // .all

        vm.feedFilter = .topic("aaaa")
        #expect(vm.visibleItems.count == 2)              // only aaaa items
        #expect(vm.activeTopicName == "Topic aaaa")      // resolves the display name

        vm.followed = ["bbbb"]
        vm.feedFilter = .followed
        #expect(vm.visibleItems.count == 1)              // only the followed topic's item
        #expect(vm.visibleItems.first?.topicHex == "bbbb")

        vm.feedFilter = .all
        #expect(vm.activeTopicName == nil)
    }

    @Test func addLocalTopicIsOptimisticAndIdempotent() async {
        let vm = await loadedFeed()
        let before = vm.topics.count
        vm.addLocalTopic(CoinNewsTopic(topicHex: "cccc", name: "Fresh", retentionDays: 5))
        #expect(vm.topics.count == before + 1)
        #expect(vm.topicName(for: "cccc") == "Fresh")
        // Re-adding the same id is a no-op (won't duplicate when the indexer also returns it).
        vm.addLocalTopic(CoinNewsTopic(topicHex: "cccc", name: "Dup", retentionDays: 9))
        #expect(vm.topics.count == before + 1)
    }

    // MARK: - Subscription store (per network)

    @Test func subscriptionsAreIsolatedPerNetwork() {
        let store = TopicSubscriptionStore(defaults: .standard)
        // Normalize (tests share .standard); use unique ids that won't collide with real data.
        store.unfollow("ts-aaaa", on: .signet)
        store.unfollow("ts-aaaa", on: .testnet4)

        store.follow("ts-aaaa", on: .signet)
        #expect(store.isFollowed("ts-aaaa", on: .signet))
        #expect(!store.isFollowed("ts-aaaa", on: .testnet4))   // a different network is unaffected

        let after = store.toggle("ts-aaaa", on: .signet)        // toggle off
        #expect(!after.contains("ts-aaaa"))
        #expect(!store.isFollowed("ts-aaaa", on: .signet))
    }

    // MARK: - Topic manager view model

    @Test func topicsViewModelFollowsAndFiltersTheFeed() async {
        let feed = await loadedFeed()
        let store = TopicSubscriptionStore(defaults: .standard)
        store.unfollow("aaaa", on: .signet)   // normalize

        let vm = TopicsViewModel(feed: feed, subscriptions: store, makeCreateTopic: { _ in nil })
        let t = feed.topics.first { $0.topicHex == "aaaa" }!

        #expect(!vm.isFollowed(t))
        vm.toggleFollow(t)
        #expect(vm.isFollowed(t))
        #expect(feed.followed.contains("aaaa"))           // mirrored into the feed for .followed

        vm.showTopic(t)
        #expect(feed.feedFilter == .topic("aaaa"))
        #expect(feed.visibleItems.count == 2)
        #expect(vm.isShowing(t))

        vm.showAll()
        #expect(feed.feedFilter == .all)
        #expect(vm.isShowingAll)

        store.unfollow("aaaa", on: .signet)   // cleanup
    }

    // MARK: - Network availability (code-level capability)

    @Test func coinNewsOffOnBitcoinOnly() {
        #expect(!CoinNewsAvailability.isAvailable(on: .bitcoin))
        #expect(CoinNewsAvailability.isAvailable(on: .signet))
        #expect(CoinNewsAvailability.isAvailable(on: .testnet4))
        #expect(CoinNewsAvailability.isAvailable(on: .regtest))
    }

    // MARK: - Seeded client is network-scoped

    @Test func seededClientServesOnlyItsNetwork() async throws {
        let signet = SeededCoinNewsClient(network: .signet)
        #expect(try await signet.topics().count == 2)
        #expect(try await !signet.frontPage(limit: 50).isEmpty)

        let mainnet = SeededCoinNewsClient(network: .bitcoin)
        #expect(try await mainnet.topics().isEmpty)
        #expect(try await mainnet.frontPage(limit: 50).isEmpty)
    }
}
