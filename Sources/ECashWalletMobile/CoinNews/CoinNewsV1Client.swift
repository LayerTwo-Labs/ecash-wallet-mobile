// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// CoinNews via the **standalone `coinnews.v1.CoinNewsService`** indexer — the public, richer feed
/// (HN-style ranking: `score`/`points`/`commentCount`, real `ItemID`s, authors, threads). This is
/// the production target: once L2L stands up a public endpoint, point a `CoinNewsEndpoint` at it
/// (unauthenticated, CORS-open) and use this client. No code changes elsewhere — both clients
/// satisfy `CoinNewsFetching`.
///
/// Ready but not yet live-tested (no public server running). The wire mapping follows the proto3
/// JSON shape of `coinnews/server/proto/coinnews/v1/coinnews.proto`.
struct CoinNewsV1Client: CoinNewsFetching {
    private static let service = "coinnews.v1.CoinNewsService"
    private let rpc: ConnectRPCClient

    init(endpoint: CoinNewsEndpoint, fetch: @escaping ConnectRPCClient.Fetch = ConnectRPCClient.defaultFetch) {
        self.rpc = ConnectRPCClient(baseURL: endpoint.baseURL, bearerToken: endpoint.bearerToken, fetch: fetch)
    }

    func topics() async throws -> [CoinNewsTopic] {
        let res: ListTopicsResponse = try await rpc.unary(service: Self.service, method: "ListTopics", request: EmptyRequest())
        return (res.topics ?? []).map {
            CoinNewsTopic(topicHex: $0.topicHex ?? "", name: $0.name ?? "", retentionDays: $0.retentionDays ?? 0)
        }
    }

    func frontPage(limit: Int) async throws -> [CoinNewsItem] {
        let res: ItemsResponse = try await rpc.unary(
            service: Self.service, method: "ListFrontPage", request: FeedRequest(limit: limit))
        return (res.items ?? []).map(Self.map)
    }

    func newFeed(limit: Int) async throws -> [CoinNewsItem] {
        let res: ItemsResponse = try await rpc.unary(
            service: Self.service, method: "ListNewFeed", request: FeedRequest(limit: limit))
        return (res.items ?? []).map(Self.map)
    }

    private static func map(_ w: Item) -> CoinNewsItem {
        CoinNewsItem(
            id: w.itemIdHex ?? "",
            topicHex: w.topicHex ?? "",
            headline: w.headline ?? "",
            body: w.body,
            url: w.url,
            createdAtRaw: w.blockTime,
            authorXpkHex: w.authorXpkHex,
            points: w.points,
            commentCount: w.commentCount,
            score: w.score,
            blockHeight: w.blockHeight)
    }
}

// MARK: - coinnews.v1 wire shapes (proto3 JSON; fields optional — proto3 omits zero/default values)

private struct FeedRequest: Encodable {
    let limit: Int
    let offset: Int = 0
}

private struct ItemsResponse: Decodable {
    let items: [Item]?
}

private struct Item: Decodable {
    let itemIdHex: String?
    let topicHex: String?
    let headline: String?
    let url: String?
    let body: String?
    let lang: String?
    let nsfw: Bool?
    let authorXpkHex: String?
    let blockHeight: Int?
    let blockTime: String?     // google.protobuf.Timestamp → RFC3339 string
    let points: Int?
    let commentCount: Int?
    let score: Double?
}

private struct ListTopicsResponse: Decodable {
    let topics: [Topic]?
    struct Topic: Decodable {
        let topicHex: String?
        let name: String?
        let retentionDays: Int?
        let createdHeight: Int?
        let txid: String?
    }
}
