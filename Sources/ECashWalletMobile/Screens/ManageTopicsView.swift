// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Topic manager for the selected wallet's network (CoinNews topics + subscriptions are per network).
/// Browse known topics, follow/unfollow them (local preference), filter the News feed (All /
/// Following / a single topic), and create a new topic. Presented as a sheet from the News tab.
struct ManageTopicsView: View {
    @Environment(\.dismiss) var dismiss   // not `private` — Fuse bridges view properties
    @State var vm: TopicsViewModel
    @State var showCreate = false

    init(viewModel: TopicsViewModel) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Topics", bundle: .module, comment: "topic manager title"))
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showCreate = true } label: { Image(icon: Icon.add) }
                    }
                }
                .sheet(isPresented: $showCreate) {
                    if let cvm = vm.makeCreateTopicViewModel() {
                        CreateTopicView(viewModel: cvm)
                    }
                }
        }
    }

    // Native inset-grouped `List` to match Settings (`.groupedListStyle()`); never VStack+ForEach
    // (recurses in SkipUI's Compose layout — same rule as ActivityScreen / NewsScreen).
    @ViewBuilder private var content: some View {
        List {
            Section(header: showHeader) {
                filterRow(title: "All news", active: vm.isShowingAll) { vm.showAll(); dismiss() }
                filterRow(title: "Following", active: vm.isShowingFollowed) { vm.showFollowed(); dismiss() }
            }
            .listRowBackground(Theme.Colors.bg2)

            Section(header: sectionHeader(Text("Topics", bundle: .module, comment: "topics list section header"))) {
                if vm.hasTopics {
                    ForEach(vm.topics) { topic in topicRow(topic) }
                } else {
                    Text("No topics yet on this network. Create one with +.",
                         bundle: .module, comment: "empty topics state")
                        .textStyle(.sm).foregroundStyle(Theme.Colors.text2)
                }
            }
            .listRowBackground(Theme.Colors.bg2)
        }
        .groupedListStyle()
        .themedGroupedListBackground()
        .refreshable { await vm.refresh() }
    }

    private var showHeader: some View {
        HStack {
            sectionHeader(Text("Show", bundle: .module, comment: "feed filter section header"))
            Spacer()
            NetworkBadge(network: vm.network)
        }
    }

    /// Section header in the brand font (matches SettingsScreen) — a plain `Section("…")` title
    /// renders in the system font.
    private func sectionHeader(_ text: Text) -> some View {
        text.textStyle(.overline).foregroundStyle(Theme.Colors.text1)
    }

    // MARK: - Rows

    // A plain `Button` in a `List` (no `.buttonStyle(.plain)`) is tappable across the WHOLE row — the
    // list cell owns the tap (same as SettingsScreen). `.plain` would shrink the hit target to just
    // the text, and `.contentShape(Rectangle())` to expand it isn't available in Skip.
    private func filterRow(title: LocalizedStringKey, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title, bundle: .module)
                    .textStyle(.body)
                    .foregroundStyle(Theme.Colors.text0)
                Spacer()
                if active {
                    Image(icon: Icon.check)
                        .resizable().scaledToFit().frame(width: 18, height: 18)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
    }

    private func topicRow(_ topic: CoinNewsTopic) -> some View {
        HStack(spacing: Theme.Space.x3) {
            // Primary tap (filter to this topic) spans the row's left region; the follow pill is a
            // `.borderless` accessory so it captures its own tap independently.
            Button {
                vm.showTopic(topic); dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: topic.name)
                        .textStyle(.body)
                        .foregroundStyle(Theme.Colors.text0)
                    Text(verbatim: subtitle(topic))
                        .textStyle(.xs)
                        .foregroundStyle(Theme.Colors.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            followPill(topic)
        }
    }

    private func followPill(_ topic: CoinNewsTopic) -> some View {
        let following = vm.isFollowed(topic)
        return Button { vm.toggleFollow(topic) } label: {
            Text(following ? "Following" : "Follow", bundle: .module, comment: "follow toggle")
                .textStyle(.xs)
                .foregroundStyle(following ? Theme.Colors.accentText : Theme.Colors.text1)
                .padding(.horizontal, Theme.Space.x3)
                .padding(.vertical, Theme.Space.x1)
                .background(
                    Capsule().fill(following ? Theme.Colors.accent : Theme.Colors.bg2))
                .overlay(
                    Capsule().stroke(following ? Color.clear : Theme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.borderless)   // isolates the pill's tap from the row's primary tap
    }

    private func subtitle(_ topic: CoinNewsTopic) -> String {
        let retention = topic.retentionDays == 0 ? "kept forever" : "\(topic.retentionDays)d retention"
        return "\(topic.topicHex) · \(retention)"
    }
}
