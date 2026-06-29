// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// In-app sheet shown when the user taps an announcement push (`PushAlert`, routed by `PushRouter`).
///
/// Layout: brand mark, the title, then the Markdown body, with a "Done" button pinned at the bottom.
/// The body renders as Markdown (bold/italic/links) via the same `LocalizedStringKey` path CoinNews
/// uses — links are tappable and open in the default browser on both platforms. Announcements are
/// company-only and carry no wallet data, so links are rendered and opened directly (no phishing
/// gate). Only inline Markdown is supported (no headings/lists/code-fences) — see `NewsRow`.
///
/// No `NavigationStack`/toolbar (it would render a Material top app bar on Android) — the sheet is
/// swipe-down dismissible and the Done button clears the router (CLAUDE.md §10 sheet-chrome rule).
struct AlertSheet: View {
    let alert: PushAlert
    @Environment(\.dismiss) var dismiss   // not `private` — Fuse bridges @Environment (skip-fuse rule)

    var body: some View {
        ZStack {
            Theme.Colors.bg0.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.x5) {
                        Logo(size: 56)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Theme.Space.x6)

                        if !alert.title.isEmpty {
                            Text(verbatim: alert.title)
                                .textStyle(.h1)
                                .foregroundStyle(Theme.Colors.text0)
                        }

                        if !alert.body.isEmpty {
                            // Markdown body — bold/italic/links via the cross-platform
                            // LocalizedStringKey path (see NewsRow). Dynamic content → no `bundle:`.
                            Text(LocalizedStringKey(stringLiteral: alert.body))
                                .textStyle(.body)
                                .foregroundStyle(Theme.Colors.text1)
                                .tint(Theme.Colors.accent)   // markdown links in the brand accent
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.gutter)
                }
                .scrollIndicators(.hidden)

                WalletButton(title: "Done") { dismiss() }
                    .padding(.horizontal, Theme.Space.gutter)
                    .padding(.bottom, Theme.Space.x4)
            }
        }
    }
}
