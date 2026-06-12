// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI
import QRCodeGenerator

/// Renders `content` as a QR code — crisp black modules on a white card (high contrast for
/// scanners, deliberately theme-independent so it scans in dark mode too). Generation is pure
/// Swift (`QRCodeGenerator`); rendering is a plain grid of `Rectangle`s (SkipUI has no `Canvas`),
/// so it works identically on iOS and Android with no platform-specific code.
struct QRCodeView: View {
    let content: String
    var size: CGFloat = 240
    /// White quiet-zone border (points) — scanners need it to lock on.
    private var quiet: CGFloat { size * 0.08 }

    var body: some View {
        // Medium error-correction balances density against scan robustness. Encoding can't really
        // fail for a bech32 address; if it ever did we show a blank white card rather than crash.
        let qr = try? QRCode.encode(text: content, ecl: .medium)
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.white)
            if let qr = qr {
                let count = qr.size
                let cell = (size - quiet * 2) / CGFloat(count)
                VStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { y in
                        HStack(spacing: 0) {
                            ForEach(0..<count, id: \.self) { x in
                                Rectangle()
                                    .fill(qr.getModule(x: x, y: y) ? Color.black : Color.white)
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}
