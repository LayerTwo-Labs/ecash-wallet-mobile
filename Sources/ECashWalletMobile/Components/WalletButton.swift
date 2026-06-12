// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Full-width, rounded-rect button. We don't use the platform's default button styles here
/// because they render as full pills/capsules on Android; the design calls for a rounded
/// rectangle (`Theme.Radius.md`). Primary = filled accent; secondary = elevated surface + hairline.
struct WalletButton: View {
    enum Kind { case primary, secondary }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.button)
                .foregroundStyle(kind == .primary ? Theme.Colors.accentText : Theme.Colors.text0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.x4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(kind == .primary ? Theme.Colors.accent : Theme.Colors.bg2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(kind == .secondary ? Theme.Colors.border : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
