// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// The eCash brand mark. Rendered from `logo.imageset` (a PNG rasterized from ecash-logo.svg)
/// so the same asset ships to iOS and Android (Compose can't consume SVG directly). The mark's
/// amber (#E8A84A = `brandAmber`) is baked into the PNG, so it reads on both light and dark.
struct Logo: View {
    var size: CGFloat = 72

    var body: some View {
        Image("logo", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text("eCash", bundle: .module, comment: "app logo"))
    }
}
