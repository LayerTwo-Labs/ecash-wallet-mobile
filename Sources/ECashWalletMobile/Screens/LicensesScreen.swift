// Copyright (C) 2026 LayerTwo Labs and contributors
// Licensed under the GNU General Public License v2.0 or later
// SPDX-License-Identifier: GPL-2.0-or-later

import SwiftUI

/// Open-source attributions, pushed from Settings → "Open-source licenses". Purely presentational:
/// it renders `OpenSourceLicense.all` (the single source of truth — edit that list to change
/// credits). Each row links out to the project. Native inset-grouped `List` on both platforms.
struct LicensesScreen: View {
    var body: some View {
        List {
            Section {
                ForEach(OpenSourceLicense.all) { lib in
                    licenseRow(lib)
                }
            } header: {
                Text("eCash.com Wallet is open source and builds on these projects.",
                     bundle: .module, comment: "open-source licenses screen intro")
            }
        }
        .groupedListStyle()
        .navigationTitle(Text("Open-source licenses", bundle: .module, comment: "licenses screen title"))
    }

    @ViewBuilder
    private func licenseRow(_ lib: OpenSourceLicense) -> some View {
        if let url = URL(string: lib.url) {
            Link(destination: url) { rowContent(lib, linked: true) }
        } else {
            rowContent(lib, linked: false)
        }
    }

    private func rowContent(_ lib: OpenSourceLicense, linked: Bool) -> some View {
        HStack(spacing: Theme.Space.x3) {
            VStack(alignment: .leading, spacing: 2) {
                // Project name + SPDX id are proper nouns/codes — not translated.
                Text(verbatim: lib.name)
                    .textStyle(.body)
                    .foregroundStyle(Theme.Colors.text0)
                Text(verbatim: lib.license)
                    .textStyle(.xs)
                    .foregroundStyle(Theme.Colors.text2)
            }
            Spacer()
            if linked {
                Image(icon: Icon.disclosure)
                    .resizable().scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Theme.Colors.text2)
            }
        }
    }
}
