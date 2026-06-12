// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Custom numeric keypad for money entry — digits, decimal point, backspace. Built entirely
/// from Theme tokens (DESIGN.md): JetBrains Mono digits on `bg2` chips, `Radius.md` corners,
/// ≥44pt targets. Stateless: the owning view model applies the editing rules
/// (`WalletService.AmountEntry`).
///
/// Android (Compose) layout discipline: shallow modifier stacks per key, no per-key flexible
/// children beyond the single `maxWidth` chip frame (the proven `actionRow` pattern).
struct Keypad: View {
    let onDigit: (Int) -> Void
    let onDot: () -> Void
    let onBackspace: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.x2) {
            row([1, 2, 3])
            row([4, 5, 6])
            row([7, 8, 9])
            HStack(spacing: Theme.Space.x2) {
                key(label: ".") { onDot() }
                digitKey(0)
                key(icon: Icon.backspace) { onBackspace() }
            }
        }
    }

    private func row(_ digits: [Int]) -> some View {
        HStack(spacing: Theme.Space.x2) {
            digitKey(digits[0])
            digitKey(digits[1])
            digitKey(digits[2])
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        key(label: "\(digit)") { onDigit(digit) }
    }

    private func key(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.jbMono(24, .medium))
                .foregroundStyle(Theme.Colors.text0)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Theme.Colors.bg2, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private func key(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(icon: icon)
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Theme.Colors.text1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.Colors.bg2, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
