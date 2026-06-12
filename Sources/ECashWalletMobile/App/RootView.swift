// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// The app's logical root. Routes first launch (no wallets) to a focused create/import empty
/// state, otherwise the main tab shell. Sets the brand tint and appearance override ONCE,
/// globally. Rendered by `ECashWalletMobileRootView` (the platform bridge entry).
///
/// Native-first: only stock SwiftUI chrome here, so it renders as native SwiftUI on iOS and
/// native Compose/Material on Android. The brand appears only through `Theme` + the tint.
struct RootView: View {
    @AppStorage("appearance") var appearance = ""   // "" = system · "light" · "dark"
    @State var app = AppState()

    var body: some View {
        Group {
            if app.hasWallets {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(app)
        .tint(Theme.Colors.accent)
        .preferredColorScheme(appearance == "dark" ? .dark
                              : appearance == "light" ? .light : nil)
    }
}
