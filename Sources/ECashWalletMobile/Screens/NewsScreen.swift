// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// The News tab — a CoinNews feed for the current network. Reads `AppState.coinNews` (a long-lived
/// `CoinNewsViewModel`) so the feed survives tab switches. Uses a `List` (Compose `LazyColumn`) —
/// the robust virtualized row container — never a VStack+ForEach, which recursed in SkipUI's Compose
/// layout (same rule as `ActivityScreen`).
struct NewsScreen: View {
    @Environment(AppState.self) var app
    @State var showCompose = false   // not `private` — Fuse bridges @State
    @State var showTopics = false

    var body: some View {
        content
            .navigationTitle(Text("News", bundle: .module, comment: "news screen title"))
            .toolbar {
                // Topics manager (browse / create / follow / filter) beside compose.
                ToolbarItem(placement: .primaryAction) {
                    Button { showTopics = true } label: { Image(icon: Icon.topics) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCompose = true } label: { Image(icon: Icon.add) }
                }
            }
            .sheet(isPresented: $showCompose) {
                if let vm = app.makePostStoryViewModel() {
                    PostStoryView(viewModel: vm)
                }
            }
            .sheet(isPresented: $showTopics) {
                if let vm = app.makeTopicsViewModel() {
                    ManageTopicsView(viewModel: vm)
                }
            }
            .task { await app.coinNews.load() }
    }

    @ViewBuilder private var content: some View {
        let vm = app.coinNews
        switch vm.state {
        case .idle, .loading where vm.items.isEmpty:
            ZStack {
                Theme.Colors.bg0.ignoresSafeArea()
                ProgressView()
            }
        case .failed(let message) where vm.items.isEmpty:
            ZStack {
                Theme.Colors.bg0.ignoresSafeArea()
                VStack(spacing: Theme.Space.x3) {
                    Text("Couldn't load news", bundle: .module, comment: "news load error heading")
                        .textStyle(.h2)
                        .foregroundStyle(Theme.Colors.text0)
                    Text(verbatim: message)   // dynamic, user-safe error detail
                        .textStyle(.body)
                        .foregroundStyle(Theme.Colors.text1)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Space.gutter)
            }
        default:
            feedList(vm)
        }
    }

    /// Read-only active-filter indicator — the FIRST row inside the List (so it scrolls with the
    /// feed instead of staying pinned like a section header). The filter is changed/cleared from the
    /// topic manager, not here; the topics icon hints where.
    @ViewBuilder private func filterIndicator(_ vm: CoinNewsViewModel) -> some View {
        HStack(spacing: Theme.Space.x2) {
            Image(icon: Icon.topics)
                .resizable().scaledToFit().frame(width: 13, height: 13)
                .foregroundStyle(Theme.Colors.text2)
            Text(verbatim: filterLabel(vm))
                .textStyle(.sm)
                .foregroundStyle(Theme.Colors.text1)
            Spacer()
        }
    }

    // Empty-state copy depends on WHY the feed is empty — an unfiltered empty feed vs. a "Following"
    // filter with nothing followed vs. a topic with no stories are very different situations.
    @ViewBuilder private func emptyHeading(_ vm: CoinNewsViewModel) -> some View {
        switch vm.feedFilter {
        case .all:
            Text("Nothing here yet", bundle: .module, comment: "empty news feed heading")
        case .followed:
            Text("No followed topics", bundle: .module, comment: "empty followed-filter heading")
        case .topic:
            Text("No stories yet", bundle: .module, comment: "empty topic-filter heading")
        }
    }

    @ViewBuilder private func emptyHint(_ vm: CoinNewsViewModel) -> some View {
        switch vm.feedFilter {
        case .all:
            Text("Pull to refresh, or post a story with +.",
                 bundle: .module, comment: "empty news feed hint")
        case .followed:
            Text("You're not following any topics yet. Open Topics and tap Follow to fill this feed.",
                 bundle: .module, comment: "empty followed-filter hint")
        case .topic:
            Text("Nothing posted to this topic yet. Change the filter in Topics to see all news.",
                 bundle: .module, comment: "empty topic-filter hint")
        }
    }

    private func filterLabel(_ vm: CoinNewsViewModel) -> String {
        switch vm.feedFilter {
        case .all: return ""
        case .followed: return "Following"
        case .topic: return vm.activeTopicName.map { "Topic: \($0)" } ?? "Topic"
        }
    }

    @ViewBuilder private func feedList(_ vm: CoinNewsViewModel) -> some View {
        if vm.visibleItems.isEmpty {
            // ScrollView (not a bare VStack) so pull-to-refresh still works with an empty feed.
            ScrollView {
                VStack(spacing: Theme.Space.x2) {
                    emptyHeading(vm)
                        .textStyle(.h3)
                        .foregroundStyle(Theme.Colors.text0)
                    emptyHint(vm)
                        .textStyle(.sm)
                        .foregroundStyle(Theme.Colors.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Space.x12)
                .padding(Theme.Space.gutter)
            }
            .refreshable { await vm.refresh() }
            .background(Theme.Colors.bg0)
        } else {
            List {
                if vm.feedFilter != .all {
                    // Scrolls away with the feed (a row, not a pinned banner).
                    filterIndicator(vm)
                        #if os(iOS)
                        .listRowSeparator(.hidden)
                        #endif
                }
                ForEach(vm.visibleItems) { item in
                    NewsRow(item: item, topicName: vm.topicName(for: item.topicHex))
                }
            }
            .listStyle(.plain)
            .refreshable { await vm.refresh() }
        }
    }
}
