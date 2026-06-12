// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import WalletService
#if os(iOS)
import UIKit
#endif

/// Cross-platform "copy text to the system clipboard". SwiftUI has no portable clipboard API, so
/// this bridges per platform: `UIPasteboard` on iOS; on Android we delegate to the transpiled
/// WalletService (`Platform.copyToClipboard`), which does the Kotlin `ClipboardManager` call —
/// reliable, unlike calling Android APIs from this Fuse module's native Swift via AnyDynamicObject.
enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(Android)
        PlatformBridge.copyToClipboard(text)
        #endif
    }
}
