// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import SkipFuse
import SwiftUI

/// A logger for the ECashWalletMobile module.
let logger: Logger = Logger(subsystem: "com.layertwolabs.mobile.ecashwallet", category: "ECashWalletMobile")

/// The platform bridge entry, loaded from the platform-specific App delegates below.
/// It stays thin — it just hosts the app's logical root, `RootView`.
/* SKIP @bridge */public struct ECashWalletMobileRootView : View {
    /* SKIP @bridge */public init() {
    }

    public var body: some View {
        RootView()
    }
}

/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
/* SKIP @bridge */public final class ECashWalletMobileAppDelegate : Sendable {
    /* SKIP @bridge */public static let shared = ECashWalletMobileAppDelegate()

    private init() {
    }

    /* SKIP @bridge */public func onInit() {
        logger.debug("onInit")
        FontRegistration.registerBundledFonts()   // iOS: register bundled .ttf with CoreText
    }

    /* SKIP @bridge */public func onLaunch() {
        logger.debug("onLaunch")
    }

    /* SKIP @bridge */public func onResume() {
        logger.debug("onResume")
    }

    /* SKIP @bridge */public func onPause() {
        logger.debug("onPause")
    }

    /* SKIP @bridge */public func onStop() {
        logger.debug("onStop")
    }

    /* SKIP @bridge */public func onDestroy() {
        logger.debug("onDestroy")
    }

    /* SKIP @bridge */public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
