// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse
import WalletService

/// Drives the topic manager (`ManageTopicsView`) for ONE network. Browses the network feed's topics,
/// follows/unfollows them in the per-network `TopicSubscriptionStore`, applies the feed's filter
/// (all / following / a single topic), and vends a `CreateTopicViewModel`. Everything is scoped to
/// the feed's network — CoinNews topics + subscriptions are per network.
@MainActor
@Observable
final class TopicsViewModel {
    private let feed: CoinNewsViewModel
    private let subscriptions: TopicSubscriptionStore
    private let makeCreate: (@escaping @MainActor (CoinNewsTopic) -> Void) -> CreateTopicViewModel?

    /// Followed topic IDs for this network (mirrors the store; also pushed into the feed so its
    /// `.followed` filter works).
    private(set) var followed: Set<String>

    init(feed: CoinNewsViewModel,
         subscriptions: TopicSubscriptionStore,
         makeCreateTopic: @escaping (@escaping @MainActor (CoinNewsTopic) -> Void) -> CreateTopicViewModel?) {
        self.feed = feed
        self.subscriptions = subscriptions
        self.makeCreate = makeCreateTopic
        let initial = subscriptions.followed(on: feed.network)
        self.followed = initial
        feed.followed = initial
    }

    var network: WalletNetwork { feed.network }
    var topics: [CoinNewsTopic] { feed.topics }
    var hasTopics: Bool { !feed.topics.isEmpty }

    // MARK: - Follow / subscribe (local, per network)

    func isFollowed(_ topic: CoinNewsTopic) -> Bool { followed.contains(topic.topicHex) }

    func toggleFollow(_ topic: CoinNewsTopic) {
        followed = subscriptions.toggle(topic.topicHex, on: network)
        feed.followed = followed
    }

    // MARK: - Feed filter

    var isShowingAll: Bool { feed.feedFilter == .all }
    var isShowingFollowed: Bool { feed.feedFilter == .followed }
    func isShowing(_ topic: CoinNewsTopic) -> Bool { feed.feedFilter == .topic(topic.topicHex) }

    func showAll() { feed.feedFilter = .all }
    func showFollowed() { feed.feedFilter = .followed }
    func showTopic(_ topic: CoinNewsTopic) { feed.feedFilter = .topic(topic.topicHex) }

    // MARK: - Create

    /// A create-topic VM that, on success, auto-follows the new topic (it's already optimistically
    /// added to the feed by `AppState`).
    func makeCreateTopicViewModel() -> CreateTopicViewModel? {
        makeCreate { [self] topic in
            followed = subscriptions.follow(topic.topicHex, on: network)
            feed.followed = followed
        }
    }

    func refresh() async {
        await feed.refresh()
        // Re-sync the local follow set (defensive; the store is the source of truth).
        followed = subscriptions.followed(on: network)
        feed.followed = followed
    }
}
