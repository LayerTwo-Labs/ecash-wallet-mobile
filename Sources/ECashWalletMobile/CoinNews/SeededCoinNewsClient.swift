// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import WalletService

/// A `CoinNewsFetching` seeded with the real data we pulled from BitWindow's L2L-signet board — so
/// the News tab renders real headlines on any sim/emulator with **no token / cleartext / host-IP
/// plumbing**. It exercises the full protocol path (async, loading/empty states) through a clean
/// stand-in transport.
///
/// **Network-scoped**: CoinNews is per network, so the seed only stands in for the network it was
/// captured on (L2L **signet**). Other networks return an empty feed — switching to a Bitcoin
/// mainnet wallet correctly shows "no news yet" rather than signet's board.
///
/// **TEMPORARY**: swap for `CoinNewsV1Client(endpoint:)` once L2L's public `coinnews.v1` endpoint is
/// up (one line in `AppState`). Live BitWindow fetch on-device is possible but needs the rotating
/// `.auth.cookie` token + a cleartext-HTTP exception + `10.0.2.2` on Android — throwaway work the
/// public (https, no-auth) endpoint won't need.
struct SeededCoinNewsClient: CoinNewsFetching {
    let network: WalletNetwork

    /// The seed was captured on L2L signet; only stand in for that network.
    private var isSeeded: Bool { network == .signet }

    func topics() async throws -> [CoinNewsTopic] {
        guard isSeeded else { return [] }
        return [
            CoinNewsTopic(topicHex: "a1a1a1a1", name: "US Weekly", retentionDays: 7),
            CoinNewsTopic(topicHex: "a2a2a2a2", name: "Japan Weekly", retentionDays: 7),
        ]
    }

    func frontPage(limit: Int) async throws -> [CoinNewsItem] {
        guard isSeeded else { return [] }
        return Array(Self.seed.prefix(max(limit, 0) == 0 ? Self.seed.count : limit))
    }
    func newFeed(limit: Int) async throws -> [CoinNewsItem] { try await frontPage(limit: limit) }

    private static let seed: [CoinNewsItem] = [
        CoinNewsItem(
            id: "4", topicHex: "a1a1a1a1", headline: "Introducing SidΞcoin",
            body: "Bitcoin is becoming a platform. **Sidecoin is the interface** — check out the [interactive demo](https://wallet.sidecoin.app).",
            createdAtRaw: "2026-06-15T18:20:01Z", feeSats: 133_700, blockHeight: 936),
        CoinNewsItem(
            id: "3", topicHex: "a2a2a2a2", headline: "私はサトシです。このフォークを支持します。",
            createdAtRaw: "2026-06-13T13:20:01Z", feeSats: 200, blockHeight: 618),
        CoinNewsItem(
            id: "2", topicHex: "a1a1a1a1",
            headline: "If you see this message, broadcast more news here in coin news!",
            createdAtRaw: "2026-06-11T03:00:05Z", feeSats: 192, blockHeight: 379),
        CoinNewsItem(
            id: "1", topicHex: "a1a1a1a1",
            headline: "Are fees supposed to be the only anti-spam measure in coin news?",
            createdAtRaw: "2026-06-11T02:10:05Z", feeSats: 193, blockHeight: 378),
    ]
}
