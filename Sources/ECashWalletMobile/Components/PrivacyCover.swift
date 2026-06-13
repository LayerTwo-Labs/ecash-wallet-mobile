// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Full-screen brand cover shown whenever the app is not active — the app-switcher snapshot, a
/// Control Center / notification pull, and the app-lock grace window. It obscures balances and
/// addresses so they never appear in the multitasking preview, independent of whether the lock
/// gate is armed (the grace window deliberately leaves the app unlocked, so the lock screen isn't
/// covering for us there).
///
/// `RootView` shows it instantly when leaving the foreground (so the OS snapshot is already
/// covered — a fade-in would be captured half-drawn) and fades it out on return.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Theme.Colors.bg0.ignoresSafeArea()
            Logo(size: 96)
        }
    }
}
