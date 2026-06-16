// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// One CoinNews story row: headline + optional body snippet + a meta line (topic · date). Text-only
/// for now — the protocol has no image URL (media is a content hash, not surfaced yet), so the
/// design is text-first with room to add media later.
struct NewsRow: View {
    let item: CoinNewsItem
    let topicName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            Text(verbatim: item.headline)
                .textStyle(.h3)
                .foregroundStyle(Theme.Colors.text0)

            if let body = item.body, !body.isEmpty {
                // Render the body as Markdown — bold/italic/links etc. Markdown links are tappable
                // and open in the default browser (SkipUI maps `openURL` to a browser intent on
                // Android). Falls back to plain text if it isn't valid Markdown.
                bodyText(body)
                    .textStyle(.sm)
                    .foregroundStyle(Theme.Colors.text1)
                    .lineLimit(4)
            }

            HStack(spacing: Theme.Space.x2) {
                if let topicName, !topicName.isEmpty {
                    Text(verbatim: topicName)
                        .textStyle(.overline)
                        .foregroundStyle(Theme.Colors.accent)
                }
                if let date = item.createdAtRaw, date.count >= 10 {
                    Text(verbatim: String(date.prefix(10)))   // YYYY-MM-DD (no DateFormatter on Android)
                        .textStyle(.xs)
                        .foregroundStyle(Theme.Colors.text2)
                }
            }
        }
        .padding(.vertical, Theme.Space.x2)
    }

    /// Body as Markdown. A `LocalizedStringKey` is the cross-platform path: both SwiftUI and SkipUI
    /// parse Markdown (bold/italic/links) from it, and markdown links are tappable → open in the
    /// default browser. (`AttributedString(markdown:)` isn't available in Fuse's Android Foundation.)
    /// Non-Markdown text just renders as-is. No `bundle:` — this is dynamic content, not a localized
    /// string, so it's rendered verbatim-with-formatting, not looked up for translation.
    private func bodyText(_ body: String) -> Text {
        Text(LocalizedStringKey(stringLiteral: body))
    }
}
