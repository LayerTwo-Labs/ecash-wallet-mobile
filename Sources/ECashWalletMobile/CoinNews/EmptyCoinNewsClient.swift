// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation

/// A `CoinNewsFetching` that returns nothing — used for networks with no hosted CoinNews indexer
/// yet (so the News tab shows a clean empty state instead of fabricated/seeded content).
struct EmptyCoinNewsClient: CoinNewsFetching {
    func topics() async throws -> [CoinNewsTopic] { [] }
    func frontPage(limit: Int) async throws -> [CoinNewsItem] { [] }
    func newFeed(limit: Int) async throws -> [CoinNewsItem] { [] }
}
