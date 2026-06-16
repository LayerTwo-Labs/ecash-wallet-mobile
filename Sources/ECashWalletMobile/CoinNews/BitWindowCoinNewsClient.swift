// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// CoinNews via **BitWindow's local `misc.v1.MiscService`** (ConnectRPC on `:30301`, gated by the
/// `Authorization: Bearer <token>` from `<bitwindowDir>/.auth.cookie`). This is the dev/test backend
/// — live whenever BitWindow is running. It's simpler than the standalone indexer: items carry a fee
/// but no HN ranking, so `frontPage` == `newFeed` (newest-first). For the public, richer feed see
/// `CoinNewsV1Client`.
struct BitWindowCoinNewsClient: CoinNewsFetching {
    private static let service = "misc.v1.MiscService"
    private let rpc: ConnectRPCClient

    init(endpoint: CoinNewsEndpoint, fetch: @escaping ConnectRPCClient.Fetch = ConnectRPCClient.defaultFetch) {
        self.rpc = ConnectRPCClient(baseURL: endpoint.baseURL, bearerToken: endpoint.bearerToken, fetch: fetch)
    }

    func topics() async throws -> [CoinNewsTopic] {
        let res: ListTopicsResponse = try await rpc.unary(service: Self.service, method: "ListTopics", request: EmptyRequest())
        return (res.topics ?? []).map {
            CoinNewsTopic(topicHex: $0.topic ?? "", name: $0.name ?? "", retentionDays: $0.retentionDays ?? 0)
        }
    }

    func frontPage(limit: Int) async throws -> [CoinNewsItem] { try await listCoinNews(limit: limit) }
    func newFeed(limit: Int) async throws -> [CoinNewsItem] { try await listCoinNews(limit: limit) }

    private func listCoinNews(limit: Int) async throws -> [CoinNewsItem] {
        let res: ListCoinNewsResponse = try await rpc.unary(service: Self.service, method: "ListCoinNews", request: EmptyRequest())
        let items = (res.coinNews ?? []).map { wire -> CoinNewsItem in
            CoinNewsItem(
                id: wire.id ?? "",
                topicHex: wire.topic ?? "",
                headline: wire.headline ?? "",
                body: wire.content,
                createdAtRaw: wire.createTime,
                feeSats: wire.feeSats.flatMap { Int64($0) })
        }
        return limit > 0 ? Array(items.prefix(limit)) : items
    }
}

// MARK: - misc.v1 wire shapes (proto3 JSON; all fields optional — proto3 omits zero/default values)

private struct ListTopicsResponse: Decodable {
    let topics: [Topic]?
    struct Topic: Decodable {
        let id: String?
        let topic: String?
        let name: String?
        let createTime: String?
        let confirmed: Bool?
        let retentionDays: Int?
    }
}

private struct ListCoinNewsResponse: Decodable {
    let coinNews: [News]?
    struct News: Decodable {
        let id: String?
        let topic: String?
        let headline: String?
        let content: String?
        let feeSats: String?   // proto int64 → JSON string ("133700")
        let createTime: String?
    }
}
