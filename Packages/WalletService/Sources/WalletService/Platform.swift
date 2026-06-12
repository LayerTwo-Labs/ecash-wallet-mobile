// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

#if !SKIP_BRIDGE

import Foundation

/// Small platform-glue that needs DIRECT Android/Kotlin interop. It lives here, in the transpiled
/// (Lite) module, on purpose: `#if SKIP` Kotlin interop works cleanly here (same mechanism that
/// runs bdk-android), whereas calling these Android APIs from the Fuse app's NATIVE Swift via
/// `AnyDynamicObject` hits ambiguous-dispatch dead-ends. Bridged to the app like the rest of the
/// public surface; the signature is bridge-safe (String in, nothing out).
public enum PlatformBridge {
    /// Copy text to the Android system clipboard. No-op off Android — the app uses `UIPasteboard`
    /// directly on iOS and only routes here on Android.
    public static func copyToClipboard(_ text: String) {
        #if SKIP
        let context = ProcessInfo.processInfo.androidContext
        // Safe cast: if the service ever isn't a ClipboardManager, copying silently no-ops
        // rather than crashing (no force-unwraps/casts on platform-derived values).
        guard let clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager else {
            return
        }
        clipboard.setPrimaryClip(android.content.ClipData.newPlainText("address", text))
        #endif
    }
}

#endif // !SKIP_BRIDGE
