// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Temporary centered placeholder built only from `Theme` tokens. Used by the not-yet-built
/// tab screens; removed as each real screen lands in its PLAN.md slice.
struct PlaceholderScreen: View {
    var heading: String
    var note: String

    var body: some View {
        ZStack {
            Theme.Colors.bg0.ignoresSafeArea()
            VStack(spacing: Theme.Space.x3) {
                Text(heading)
                    .textStyle(.h2)
                    .foregroundStyle(Theme.Colors.text0)
                Text(note)
                    .textStyle(.body)
                    .foregroundStyle(Theme.Colors.text1)
                    .multilineTextAlignment(.center)
            }
            .padding(Theme.Space.gutter)
        }
    }
}
