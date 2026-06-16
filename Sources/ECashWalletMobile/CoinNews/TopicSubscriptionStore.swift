// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import WalletService

/// Local, per-network "followed topics" — a **client preference**, not on-chain state. CoinNews
/// topics live per network (different chains), so subscriptions are keyed by `network.rawValue` in
/// UserDefaults. Following only affects what the app shows (the `.followed` feed filter); it never
/// broadcasts anything.
@MainActor
final class TopicSubscriptionStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ network: WalletNetwork) -> String { "coinnews.subs.\(network.rawValue)" }

    /// The followed topic IDs (hex) for a network. Persisted as a comma-joined string (topic IDs are
    /// hex, never contain commas) — `stringArray(forKey:)` isn't available in the Android SDK's
    /// Foundation, but `string(forKey:)` is.
    func followed(on network: WalletNetwork) -> Set<String> {
        guard let raw = defaults.string(forKey: key(network)), !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map { String($0) })
    }

    func isFollowed(_ topicHex: String, on network: WalletNetwork) -> Bool {
        followed(on: network).contains(topicHex)
    }

    @discardableResult
    func follow(_ topicHex: String, on network: WalletNetwork) -> Set<String> {
        var ids = followed(on: network)
        ids.insert(topicHex)
        save(ids, on: network)
        return ids
    }

    @discardableResult
    func unfollow(_ topicHex: String, on network: WalletNetwork) -> Set<String> {
        var ids = followed(on: network)
        ids.remove(topicHex)
        save(ids, on: network)
        return ids
    }

    /// Toggle membership; returns the new set so callers can mirror it without a re-read.
    @discardableResult
    func toggle(_ topicHex: String, on network: WalletNetwork) -> Set<String> {
        var ids = followed(on: network)
        if ids.contains(topicHex) { ids.remove(topicHex) } else { ids.insert(topicHex) }
        save(ids, on: network)
        return ids
    }

    private func save(_ ids: Set<String>, on network: WalletNetwork) {
        defaults.set(ids.sorted().joined(separator: ","), forKey: key(network))
    }
}
