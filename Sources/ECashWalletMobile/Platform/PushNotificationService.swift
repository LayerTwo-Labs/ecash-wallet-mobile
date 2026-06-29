// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse
import SkipFirebaseMessaging

/// Push-notification client (Firebase Cloud Messaging via SkipFirebaseMessaging).
///
/// Scope (docs/notifications.md): manual broadcast announcements only — no backend that knows wallet
/// data. Firebase is configured + delegates assigned in `ECashWalletMobileAppDelegate.onInit`, and
/// permission is requested in `onLaunch`. This type fetches the FCM token (for display/diagnostics)
/// and subscribes the device to the `announcements` topic so the Firebase console can broadcast to
/// every device (iOS + Android) in one send. Idempotent; called from `MainTabView`.
@MainActor
@Observable
public final class PushNotificationService {
    /// Topic every device joins, so a single console broadcast reaches all of them. (Even without
    /// topics, the SDK lets the console target the app directly; the topic is the reliable fallback.)
    public static let topic = "announcements"

    public enum Status: Equatable {
        case idle
        case working
        case registered
        case failed(String)
    }

    public private(set) var status: Status = .idle
    /// The FCM registration token (same on a refresh), once registered. Shown in the dev Settings row.
    public private(set) var token: String?

    public init() {}

    /// Fetch the FCM token and subscribe to the announcements topic. Idempotent — no-ops once
    /// registered/in-flight, retries after a failure.
    public func register() async {
        switch status {
        case .working, .registered: return
        case .idle, .failed: break
        }
        status = .working
        do {
            let t = try await Messaging.messaging().token()
            token = t
            try await Messaging.messaging().subscribe(toTopic: Self.topic)
            status = .registered
            logger.debug("FCM registered + subscribed to \(Self.topic)")
        } catch {
            status = .failed("\(error)")
            logger.error("push register failed: \(error)")
        }
    }
}
