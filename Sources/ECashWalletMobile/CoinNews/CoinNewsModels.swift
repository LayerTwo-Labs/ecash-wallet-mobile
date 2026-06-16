// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// A CoinNews item (a Story/post) as the app cares about it — decoupled from any one server's wire
/// shape. Both the BitWindow `misc.v1` API and the standalone `coinnews.v1` indexer map INTO this;
/// fields a given backend doesn't provide are `nil` (e.g. `misc.v1` has `feeSats` but no ranking;
/// `coinnews.v1` has `score`/`points`/`commentCount` but no fee). See `CoinNewsFetching`.
struct CoinNewsItem: Identifiable, Hashable, Sendable {
    /// ItemID (coinnews.v1, hex) or row id (misc.v1). Stable within one backend.
    let id: String
    /// Canonical 4-byte topic id, hex (e.g. "a1a1a1a1").
    let topicHex: String
    let headline: String
    let body: String?
    let url: String?
    /// RFC3339 timestamp string from the API. Kept raw for now — date formatting/sorting is a UI
    /// concern handled later (servers already return the feed in order).
    let createdAtRaw: String?

    // Richer fields — populated by coinnews.v1, nil from misc.v1.
    let authorXpkHex: String?
    let points: Int?
    let commentCount: Int?
    let score: Double?

    // misc.v1 only.
    let feeSats: Int64?
    let blockHeight: Int?

    init(id: String, topicHex: String, headline: String, body: String? = nil, url: String? = nil,
         createdAtRaw: String? = nil, authorXpkHex: String? = nil, points: Int? = nil,
         commentCount: Int? = nil, score: Double? = nil, feeSats: Int64? = nil, blockHeight: Int? = nil) {
        self.id = id
        self.topicHex = topicHex
        self.headline = headline
        self.body = body
        self.url = url
        self.createdAtRaw = createdAtRaw
        self.authorXpkHex = authorXpkHex
        self.points = points
        self.commentCount = commentCount
        self.score = score
        self.feeSats = feeSats
        self.blockHeight = blockHeight
    }
}

/// A CoinNews topic (board), e.g. "US Weekly". Topic IDs are canonical (4-byte, hex); `name` is
/// display-only metadata.
struct CoinNewsTopic: Identifiable, Hashable, Sendable {
    let topicHex: String
    let name: String
    let retentionDays: Int
    var id: String { topicHex }

    init(topicHex: String, name: String, retentionDays: Int = 0) {
        self.topicHex = topicHex
        self.name = name
        self.retentionDays = retentionDays
    }
}
