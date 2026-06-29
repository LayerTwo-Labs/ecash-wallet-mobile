// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import Foundation
import Observation
import SkipFuse

/// Routes a tapped push notification into an in-app alert sheet.
///
/// The push `NotificationDelegate` lives outside the SwiftUI tree (it's owned by the app delegate),
/// so it needs a stable hand-off point into the UI. This shared, `@Observable` singleton is it:
/// `NotificationDelegate.didReceive` calls `handle(...)`, which sets `pendingAlert`; `RootView`
/// observes this instance and presents `AlertSheet` via `.sheet(item:)`.
///
/// `kind` is the switch. Only pushes WE send carry a recognized `kind` (today just `"alert"`); a
/// push with no/unknown `kind` shows the system banner and does nothing on tap. The `switch` makes
/// adding future routes (e.g. deep-links) a one-case change with no call-site churn.
@MainActor
@Observable
final class PushRouter {
    static let shared = PushRouter()
    private init() {}

    /// The alert to present, if any. `RootView` binds `.sheet(item:)` to this — setting it shows the
    /// sheet, dismissing clears it back to `nil`.
    var pendingAlert: PushAlert?

    /// Handle a tapped notification. `userInfo` is the FCM **data** block (custom key/value pairs),
    /// surfaced cross-platform as the `UNNotification` user-info dictionary. `fallbackTitle/Body`
    /// come from the FCM **notification** block (the tray title/body) so a sender can set the tray
    /// text once and have the sheet reuse it without duplicating it into the data block.
    func handle(userInfo: [AnyHashable: Any], fallbackTitle: String, fallbackBody: String) {
        let kind = (userInfo["kind"] as? String) ?? ""
        switch kind {
        case "alert":
            let title = nonEmpty(userInfo["title"] as? String) ?? fallbackTitle
            let body = nonEmpty(userInfo["body"] as? String) ?? fallbackBody
            // Nothing to show at all → skip (a misconfigured push shouldn't pop an empty sheet).
            guard !title.isEmpty || !body.isEmpty else { return }
            pendingAlert = PushAlert(title: title, body: body)
        default:
            break   // no/unknown kind → no in-app sheet (the system banner already showed)
        }
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}

/// Content of an in-app push alert sheet. `body` is rendered as Markdown (bold/italic/links — see
/// `AlertSheet`). Identifiable so it drives `.sheet(item:)`.
struct PushAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
}
