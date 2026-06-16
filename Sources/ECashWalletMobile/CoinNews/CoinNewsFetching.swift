// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// Read-only CoinNews feed source. The app depends on THIS, not on a concrete server, so we can
/// swap backends without touching the UI/view model:
///   • `BitWindowCoinNewsClient` — BitWindow's local `misc.v1.MiscService` (auth-gated; live today,
///     used for development/testing against a running BitWindow).
///   • `CoinNewsV1Client` — the standalone `coinnews.v1.CoinNewsService` indexer (public, richer);
///     drop-in once L2L stands up a public endpoint.
/// Both speak ConnectRPC over plain HTTP+JSON (no protobuf runtime — see `ConnectRPCClient`).
protocol CoinNewsFetching: Sendable {
    /// Known topics (boards).
    func topics() async throws -> [CoinNewsTopic]
    /// Ranked front page. Backends without ranking (misc.v1) return newest-first.
    func frontPage(limit: Int) async throws -> [CoinNewsItem]
    /// Newest items in canonical scan order.
    func newFeed(limit: Int) async throws -> [CoinNewsItem]
}

/// Where a CoinNews backend lives + how to authenticate. `bearerToken` is set for BitWindow's local
/// `.auth.cookie`; the public coinnews server is unauthenticated (CORS-open public data) → `nil`.
struct CoinNewsEndpoint: Sendable, Equatable {
    let baseURL: URL
    let bearerToken: String?

    init(baseURL: URL, bearerToken: String? = nil) {
        self.baseURL = baseURL
        self.bearerToken = bearerToken
    }
}

enum CoinNewsError: Error, Equatable {
    case badURL
    case server(status: Int, message: String?)
    case decode(String)
    case network
}
