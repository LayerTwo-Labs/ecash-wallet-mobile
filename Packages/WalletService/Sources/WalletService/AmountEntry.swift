// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

#if !SKIP_BRIDGE

import Foundation

/// Pure editing rules for a keypad-driven coin-amount string ("0.0012", "1.", "42").
/// Lives in WalletService (not the view layer) so the money-input rules are parity-tested on
/// both platforms next to `Amount.fromCoin`, which consumes the result. Bridged (public,
/// String/Int only). Stateless — the view model owns the string and applies these.
///
/// Invariants enforced: digits and at most one "." only; at most 8 fractional digits (sats
/// precision); at most 10 whole-coin digits (keeps `Amount.fromCoin`'s Int64 guard satisfied);
/// a lone leading "0" is replaced rather than extended (no "05").
public enum AmountEntry {
    /// Append digit 0–9. Out-of-range digits and inputs that would break an invariant return
    /// `text` unchanged.
    public static func appendDigit(_ text: String, digit: Int) -> String {
        if digit < 0 || digit > 9 { return text }
        if let dotIndex = text.firstIndex(of: ".") {
            // Fractional part: cap at 8 digits (1 sat).
            let fracCount = text.distance(from: text.index(after: dotIndex), to: text.endIndex)
            if fracCount >= 8 { return text }
            return text + "\(digit)"
        }
        // Whole part: cap at 10 digits; replace a bare "0" instead of building "05".
        if text == "0" { return "\(digit)" }
        if text.count >= 10 { return text }
        return text + "\(digit)"
    }

    /// Append the decimal point. No-op if one is already present; an empty string becomes "0.".
    public static func appendDot(_ text: String) -> String {
        if text.contains(".") { return text }
        if text.isEmpty { return "0." }
        return text + "."
    }

    /// Delete the last character. Empty input stays empty.
    public static func backspace(_ text: String) -> String {
        if text.isEmpty { return text }
        return String(text.dropLast())
    }
}

#endif // !SKIP_BRIDGE — bridged module: bodies excluded from the bridge compile
