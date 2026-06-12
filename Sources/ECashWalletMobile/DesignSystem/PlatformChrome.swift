// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Small helpers that apply iOS-only chrome modifiers and no-op elsewhere, so call sites stay
/// clean and we honor native-first: iOS gets the Apple idiom, Android falls back to its own
/// native default (which Skip renders via Compose/Material). Keeps `#if` out of the screens.
extension View {
    /// Inset-grouped list styling on iOS; native default on Android/macOS.
    @ViewBuilder
    func groupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }

    /// Large control size on iOS; native default sizing on Android/macOS.
    @ViewBuilder
    func largeControlSize() -> some View {
        #if os(iOS)
        self.controlSize(.large)
        #else
        self
        #endif
    }

    /// `fullScreenCover` on iOS/Android; plain `sheet` on the macOS host build, where
    /// `fullScreenCover` doesn't exist (macOS is only the transpile/test target — §3).
    @ViewBuilder
    func fullScreenFlow<Content: View>(isPresented: Binding<Bool>,
                                       @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(macOS)
        self.sheet(isPresented: isPresented, content: content)
        #else
        self.fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }

    /// Disable auto-capitalization on iOS (addresses/URIs are case-sensitive); Android's
    /// Compose text field doesn't capitalize plain fields, and macOS lacks the API.
    @ViewBuilder
    func noAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
