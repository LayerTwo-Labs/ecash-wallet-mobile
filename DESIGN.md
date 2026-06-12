# eCash Wallet — SwiftUI Design Spec (DESIGN.md)

> Drop this file into your iOS project and reference it from `CLAUDE.md`, e.g.:
> **"All UI must follow `DESIGN.md`. Use the `Theme` tokens — never hard-code colors, fonts, or spacing."**
>
> This is the SwiftUI translation of the eCash Wallet design system. Dark-first, self-custody-Bitcoin seriousness with a single warm Bitcoin-orange accent. Money is precise, copy is calm, networks are color-coded so a testnet wallet can never be mistaken for mainnet.

---

## ★ Core principle — native-first, theme don't rebuild

**Use stock SwiftUI and the iOS 26 Liquid Glass look as much as possible. Brand the app only through `tint`, fonts, and the color tokens — do not re-implement system chrome.**

Concretely:
- **Navigation** → `NavigationStack` + `.navigationTitle` (large titles) + `.toolbar`. Never hand-roll a header bar.
- **Bottom tabs** → the native `TabView` with `Tab` items. On iOS 26 it is **Liquid Glass automatically** — floating, translucent, morphing. Do **not** build a custom tab bar, material, or background. Just set `.tint(Theme.Colors.accent)`.
- **Lists / settings** → `List` with `.listStyle(.insetGrouped)`, `Section(header:)`, `Toggle`, `NavigationLink` (system supplies chevrons, dividers, insets, swipe actions).
- **Sheets** → `.sheet` + `.presentationDetents` + the system grabber/scrim. Don't draw your own sheet container or dim layer.
- **Search** → `.searchable`. **Inputs** → `TextField`/`SecureField` with system styling and `.keyboardType`.
- **Buttons** → system button styles (`.borderedProminent`, `.bordered`, or iOS 26 `.glass` / `.glassProminent`) with `.tint(accent)` and `.controlSize(.large)`.
- **Materials** → system `.regularMaterial` / `.glassEffect()`. Don't fake glass with opacity.

**Where to apply the brand:** global `.tint(Theme.Colors.accent)`; custom fonts via the `Theme.Typography` helpers; the color tokens for content; and a small set of **domain views that have no system equivalent** — `BalanceView`, `AmountText`, `AddressChip`, the seed-word grid, `NetworkBadge`, `TxRow` *content*, and the QR view. Everything else is stock.

Set the brand globally once:

```swift
WindowGroup {
    RootView()
        .tint(Theme.Colors.accent)          // accent drives controls, links, selection
        .preferredColorScheme(.dark)         // dark-first (let users override in Settings)
        .fontDesign(.default)                // custom fonts applied per-Text via Theme helpers
}
```

---

## 0. Setup

**Fonts (bundle these — all OFL/free).** Add the `.ttf`s to the app target and list them in `Info.plist → UIAppFonts`:
- **Space Grotesk** (display, balances, headings) — Regular / Medium / SemiBold / Bold
- **IBM Plex Sans** (UI & body) — Regular / Medium / SemiBold / Bold
- **JetBrains Mono** (addresses, amounts, seed words, txids) — Regular / Medium / SemiBold

If you'd rather not bundle fonts, fall back to `.system(.rounded)` for display and `.system(.monospaced)` for mono — but the brand voice lives in Space Grotesk + JetBrains Mono, so bundling is strongly preferred.

**Icons.** Use **SF Symbols** (native, weight-matched) per the mapping in §4 — do not import Lucide on iOS.

Create three files from the snippets below: `Color+Theme.swift`, `Typography+Theme.swift`, `Theme.swift`. Then build everything from `Theme`.

---

## 1. Color tokens

Dark is the default. Every surface/text token is **adaptive** (resolves per `colorScheme`); the accent, semantic, and network colors are intentionally **theme-invariant** except where noted in the original table.

```swift
// Color+Theme.swift
import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: alpha)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(UIColor(hex: hex, alpha: alpha))
    }
    /// Adaptive light/dark token.
    static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}
```

```swift
// Theme.swift  — Colors
enum Theme {
    enum Colors {
        // Surfaces (adaptive)
        static let bg0    = Color.adaptive(light: 0xFFFFFF, dark: 0x0B0D0E) // app background
        static let bg1    = Color.adaptive(light: 0xF4F5F6, dark: 0x141719) // elevated surface
        static let bg2    = Color.adaptive(light: 0xEAECEE, dark: 0x1C2023) // card / input
        static let border = Color.adaptive(light: 0xD7DBDF, dark: 0x2A2F33) // hairlines, dividers

        // Text (adaptive)
        static let text0  = Color.adaptive(light: 0x0B0D0E, dark: 0xEDEFF1) // primary
        static let text1  = Color.adaptive(light: 0x5B636A, dark: 0x9BA3A9) // secondary / muted
        static let text2  = Color.adaptive(light: 0x9BA3A9, dark: 0x5C656B) // faint / placeholder

        // Brand / action  (Bitcoin orange — placeholder, VERIFY with brand)
        static let accent      = Color(hex: 0xF7931A)
        static let accentText  = Color(hex: 0x0B0D0E)               // text/icon on accent
        static let accentHover = Color.adaptive(light: 0xE2850C, dark: 0xFFA938)
        static let accentTint  = Color(hex: 0xF7931A, alpha: 0.12)  // faint wash behind chips
        static let brandAmber  = Color(hex: 0xE8A84A)               // the LOGO mark color

        // Semantic status (adaptive light/dark per the source table)
        static let positive     = Color.adaptive(light: 0x1F8F5F, dark: 0x3FB67E) // received / confirmed
        static let negative     = Color.adaptive(light: 0xCE2C31, dark: 0xE5484D) // sent / error / destructive
        static let warning      = Color.adaptive(light: 0xB7791F, dark: 0xE2A03F) // unconfirmed / caution
        static let positiveTint = Color(hex: 0x3FB67E, alpha: 0.12)
        static let negativeTint = Color(hex: 0xE5484D, alpha: 0.12)
        static let warningTint  = Color(hex: 0xE2A03F, alpha: 0.12)

        // Network identity — NEVER reuse the brand orange for a network other than mainnet.
        static let netMainnet     = Color(hex: 0xF7931A) // Bitcoin
        static let netMainnetText = Color(hex: 0x0B0D0E)
        static let netTestnet     = Color.adaptive(light: 0x6A3DF0, dark: 0x7A4DFF) // high-contrast violet
        static let netTestnetText = Color(hex: 0xFFFFFF)
        // Reserved for after the hardfork (block 964,000):
        static let netEcash       = Color(hex: 0xE8A84A) // placeholder = amber
        static let netEcashTest   = Color.adaptive(light: 0x1B9AA6, dark: 0x2BB3C0)
    }
}
```

**Rules**
- App background is `bg0`; cards/inputs sit on `bg1`/`bg2` separated by a 1px `border` hairline — prefer the surface-step + hairline over heavy shadows.
- `accent` is the **single** primary-action color (buttons, active tab, focus). Don't introduce new accents.
- Status colors are reserved for their meaning only. Tints (`*Tint`, ~12%) back badges and icon chips.
- The **logo mark** uses `brandAmber` (`#E8A84A`), which is distinct from the action `accent` (`#F7931A`). (Open question with the brand — keep them split unless told otherwise.)

---

## 2. Typography

```swift
// Typography+Theme.swift
import SwiftUI

extension Font {
    static func grotesk(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom(groteskPS(weight), size: size)              // display / balances / headings
    }
    static func plex(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(plexPS(weight), size: size)                 // UI & body
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(monoPS(weight), size: size)                 // addresses / amounts / seeds
    }

    private static func groteskPS(_ w: Font.Weight) -> String {
        switch w { case .medium: "SpaceGrotesk-Medium"; case .semibold: "SpaceGrotesk-SemiBold"
                   case .bold: "SpaceGrotesk-Bold"; default: "SpaceGrotesk-Regular" }
    }
    private static func plexPS(_ w: Font.Weight) -> String {
        switch w { case .medium: "IBMPlexSans-Medium"; case .semibold: "IBMPlexSans-SemiBold"
                   case .bold: "IBMPlexSans-Bold"; default: "IBMPlexSans" }
    }
    private static func monoPS(_ w: Font.Weight) -> String {
        switch w { case .medium: "JetBrainsMono-Medium"; case .semibold: "JetBrainsMono-SemiBold"
                   default: "JetBrainsMono-Regular" }
    }
}
```

**Type scale** (size · family · weight · usage):

| Token | SwiftUI | Usage |
|---|---|---|
| display | `.grotesk(40, .bold)` + `.tracking(-0.8)` | hero balance |
| h1 | `.grotesk(28, .semibold)` + `.tracking(-0.5)` | screen titles |
| h2 | `.grotesk(22, .semibold)` | section heads |
| h3 | `.plex(18, .semibold)` | row titles |
| body | `.plex(16)` | default copy |
| sm | `.plex(14)` | secondary UI |
| xs | `.plex(12, .medium)` | captions |
| overline | `.plex(11, .semibold)` + `.tracking(0.9)` + `.textCase(.uppercase)` | labels / section headers (`text2`) |
| mono | `.mono(14)` | addresses, txids, seeds |

**Numerals.** Any balance/amount/quantity must use tabular figures so columns don't jitter:

```swift
Text("0.84210000").font(.grotesk(40, .bold)).monospacedDigit()
```

Apply `.monospacedDigit()` to every Space-Grotesk or JetBrains-Mono number. Show **full 8-dp BTC precision** in detail views and prefix fiat estimates with `≈` (e.g. `≈ $270.52`).

---

## 3. Spacing, radius, elevation, motion

```swift
// Theme.swift  — layout
extension Theme {
    enum Space {           // 4px base grid
        static let x1: CGFloat = 4,  x2: CGFloat = 8,  x3: CGFloat = 12, x4: CGFloat = 16
        static let x5: CGFloat = 20, x6: CGFloat = 24, x8: CGFloat = 32, x10: CGFloat = 40, x12: CGFloat = 48
        static let gutter: CGFloat = 20   // screen side padding
        static let tap: CGFloat = 44      // min hit target
    }
    enum Radius {
        static let xs: CGFloat = 6, sm: CGFloat = 10, md: CGFloat = 14   // md = default card / input
        static let lg: CGFloat = 20, xl: CGFloat = 28                    // lg = grouped cards / sheets
        static let pill: CGFloat = 999
    }
    enum Motion {           // quick, no bounce
        static let fast = 0.12, base = 0.20, slow = 0.32
        static let ease = Animation.easeOut(duration: base)
        static let press = Animation.easeOut(duration: fast)
    }
}

// Soft elevation — most separation comes from the hairline, not shadow.
extension View {
    func cardShadow() -> some View {            // shadow-md
        shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 4)
    }
    func accentGlow() -> some View {            // reserved for the raised Scan/Send FAB only
        shadow(color: Theme.Colors.accent.opacity(0.28), radius: 20, x: 0, y: 6)
    }
}
```

**Press feedback.** System button styles already provide the correct Liquid-Glass press response — prefer them. If you build a custom interactive surface, match the house feel: scale to **0.97** (icon-only **0.92**) with `Theme.Motion.press`, no springy overshoot.

---

## 4. Iconography → SF Symbols

Use SF Symbols at weight `.regular`/`.semibold` to match the 1.75-stroke web set. Map the system's icon names to symbols:

| Wallet concept | SF Symbol |
|---|---|
| wallet (tab) | `wallet.pass` |
| send / outgoing | `arrow.up.right` |
| receive / incoming | `arrow.down.left` |
| scan | `qrcode.viewfinder` |
| qr code | `qrcode` |
| copy | `doc.on.doc` |
| check / confirmed | `checkmark` |
| close | `xmark` |
| add | `plus` |
| back | `chevron.left` |
| disclosure | `chevron.right` · `chevron.down` |
| settings | `gearshape` |
| reveal / hide | `eye` · `eye.slash` |
| swap | `arrow.left.arrow.right` |
| backup / security | `checkmark.shield` |
| seed / key | `key` |
| caution | `exclamationmark.triangle` |
| time / pending | `clock` |
| share | `square.and.arrow.up` |
| refresh / new address | `arrow.clockwise` |
| more | `ellipsis` |
| search | `magnifyingglass` |
| remove | `trash` |
| rename | `pencil` |
| import | `square.and.arrow.down` |
| info | `info.circle` |
| app lock | `lock` |
| theme | `moon` · `sun.max` |
| activity list | `list.bullet` |

Direction/status icons sit in a 40pt circle filled with the matching tint (`positiveTint` for received, `bg2` for sent, `negativeTint`/`warningTint` for failed/pending). **No emoji anywhere.** Unicode glyphs allowed: `·` separator, `≈` estimate, `…` truncation, `−` outgoing sign.

---

## 5. Components (SwiftUI recipes)

Build **chrome from native components** (see "Chrome" below). Reserve these custom views for money/domain content that has no system equivalent. Keep them in a `Components/` folder.

### Buttons — native styles, accent tint

Use system button styles; the global `.tint(accent)` colors them. Prefer these over any custom style:

```swift
// Primary CTA (full-width, filled accent)
Button { send() } label: { Text("Review & send").frame(maxWidth: .infinity) }
    .buttonStyle(.borderedProminent)          // iOS 26: .glassProminent
    .controlSize(.large)
    .font(.plex(16, .semibold))

// Secondary
Button("Import existing wallet") { }
    .buttonStyle(.bordered)                    // iOS 26: .glass
    .controlSize(.large)

// Tertiary / destructive
Button("Cancel") { }.buttonStyle(.borderless)
Button("Remove wallet", role: .destructive) { }   // system renders it `negative`
```

Label buttons with `Label("Send", systemImage: "arrow.up.right")` so the SF Symbol comes along. Only drop to a custom `ButtonStyle` if a design truly needs the filled-accent look where `.borderedProminent` won't sit right — match height 48 (lg 56), radius `Radius.md`, press-scale 0.97. Don't reach for it by default.

### Card

```swift
struct Card<Content: View>: View {
    var elevated = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(Theme.Space.x4)
            .background(Theme.Colors.bg1, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg).stroke(Theme.Colors.border, lineWidth: 1))
            .modifier(elevated ? AnyViewModifier { $0.cardShadow() } : AnyViewModifier { $0 })
    }
}
```
Use `Card` for **content panels** (the balance header, the receive panel) — not for settings groups, which should be a native inset-grouped `List` (see Chrome). Inputs/small cards use `Radius.md`.

### Badge & NetworkBadge

```swift
struct Badge: View {
    enum Tone { case neutral, accent, positive, negative, warning }
    var tone: Tone = .neutral
    var text: String
    var systemImage: String? = nil
    var body: some View {
        let (fg, bg): (Color, Color) = {
            switch tone {
            case .neutral:  (Theme.Colors.text1, Theme.Colors.bg2)
            case .accent:   (Theme.Colors.accent, Theme.Colors.accentTint)
            case .positive: (Theme.Colors.positive, Theme.Colors.positiveTint)
            case .negative: (Theme.Colors.negative, Theme.Colors.negativeTint)
            case .warning:  (Theme.Colors.warning, Theme.Colors.warningTint)
            }
        }()
        HStack(spacing: 6) {
            if let s = systemImage { Image(systemName: s).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.plex(12, .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10).frame(height: 24)
        .background(bg, in: Capsule())
    }
}
```
`NetworkBadge`: a leading 7pt dot in the network color + label; `.solid` variant fills with the network color (white text on testnet violet). Testnet should almost always be **solid** so it's unmissable.

### Balance, Amount, AddressChip

```swift
struct BalanceView: View {
    var amount: String; var unit = "BTC"; var fiat: String?
    var hidden = false
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(hidden ? "••••••" : amount).font(.grotesk(40, .bold)).monospacedDigit()
                    .foregroundStyle(Theme.Colors.text0).tracking(-0.8)
                Text(unit).font(.grotesk(17, .semibold)).foregroundStyle(Theme.Colors.text1)
            }
            if let fiat { Text(hidden ? "•••••" : fiat).font(.plex(15, .medium))
                .foregroundStyle(Theme.Colors.text1).monospacedDigit() }
        }
    }
}

// Amount: monospace, color-coded. "in" = positive(green) "+", "out" = text0 "−".
struct AmountText: View {
    enum Dir { case incoming, outgoing, neutral }
    var value: String; var unit = "BTC"; var dir: Dir = .neutral
    var body: some View {
        let color = dir == .incoming ? Theme.Colors.positive : Theme.Colors.text0
        let sign  = dir == .incoming ? "+" : dir == .outgoing ? "−" : ""
        (Text(sign + value).foregroundStyle(color)
         + Text(" " + unit).foregroundStyle(Theme.Colors.text2))
            .font(.mono(15, .medium)).monospacedDigit()
    }
}
```
`AddressChip`: monospace, middle-truncated (`bc1qar0srrr…wf5mdq`) on a `bg2`/hairline rounded-`sm` field with a trailing copy button that flips to a green checkmark for ~1.4s.

### TxRow (content of a native list row)

This is **row content placed inside a native `List`** (system dividers, `NavigationLink` to push the detail) — not a hand-built list. The content: a 40pt tinted circle (icon `arrow.down.left`/`arrow.up.right`) · title (“Received”/“Sent”) + meta line (`text1`, e.g. `Today 14:02 · 6 conf`) · trailing `AmountText` + fiat in `text2`. Pending → amber, failed → red with `xmark` and a “Failed” `Badge`.

### Settings rows — native List, not a custom row

Don't build a custom `ListRow`. Use a native inset-grouped `List`:

```swift
List {
    Section("This wallet") {
        LabeledContent("Network") { NetworkBadge(.testnet) }
        NavigationLink { BackupView() } label: { Label("Backup wallet", systemImage: "checkmark.shield") }
    }
    Section("General") {
        Toggle(isOn: $dark) { Label("Dark theme", systemImage: "moon") }   // tint = accent
        Picker("Currency", selection: $ccy) { Text("USD").tag("USD") }
    }
    Section {
        Button("Remove this wallet", role: .destructive) { }
    }
}
.listStyle(.insetGrouped)
```

The system supplies the icon-label layout, chevrons, dividers, insets, and grouped-card background. Brand it only via `.tint(accent)`, the SF Symbols from §4, and `Theme` fonts/colors on the labels.

### Chrome — all native

- **Bottom tabs → native `TabView` (iOS 26 Liquid Glass, automatic).** Do not customize its background or build a bar.
  ```swift
  TabView(selection: $tab) {
      Tab("Wallet",   systemImage: "wallet.pass", value: .wallet)   { WalletHome() }
      Tab("Activity", systemImage: "list.bullet", value: .activity) { Activity() }
      Tab("Settings", systemImage: "gearshape",   value: .settings) { Settings() }
      Tab(value: .scan, role: .search) { ScanView() }   // search-role tab floats on the glass bar
  }
  .tint(Theme.Colors.accent)
  .tabBarMinimizeBehavior(.onScrollDown)   // iOS 26 shrink-on-scroll
  ```
  Need a persistent Scan/Send affordance above the tabs? Use `.tabViewBottomAccessory { … }` (iOS 26) or a toolbar item — not a hand-placed floating FAB.
- **Headers → `NavigationStack` + `.navigationTitle(…)`** (large titles on top-level screens, `.navigationBarTitleDisplayMode(.inline)` on pushed flows). Back button, large-to-inline transition, and the glass nav bar are free. Put actions in `.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }`.
- **Sheets → `.sheet` + `.presentationDetents([.medium, .large])`** with the system grabber + scrim (wallet switcher, confirm-send). Pin the primary action with `.safeAreaInset(edge: .bottom)`. Don't draw your own sheet container or dim layer.
- **Search → `.searchable(text:)`** on the Activity list. **Confirm dialogs → `.confirmationDialog`**; **alerts → `.alert`**.

---

## 6. Voice & copy

- Speak as **"you"**, never "I". **Sentence case** for everything except tiny uppercase overlines. Buttons are **verbs** with no trailing punctuation (*Send*, *Create new wallet*, *Review & send*, *I've written it down*).
- Security copy is matter-of-fact, one sentence, paired with the warning color + `exclamationmark.triangle` — never alarmist. Example: *"Anyone with this phrase controls your coins — and your eCash airdrop."*
- Tie Bitcoin custody to the airdrop as the user benefit; reference block **964,000** / Drivechain only in technical or footer contexts, not primary CTAs.
- Numbers: full 8-dp BTC precision in detail, `≈` before fiat, `tBTC` unit on testnet (never imply real value). **No emoji.**

---

## 7. Screen conventions

Every screen lives in a `NavigationStack` inside the native `TabView`. Top-level screens use **large titles**; pushed flows (Send, Backup, Import, Tx detail) use inline titles with the system back button. Let `List`/`ScrollView` own the layout and safe-area insets — the system handles the glass nav bar, tab bar, and content insets; don't add manual padding to dodge them. Use `.safeAreaInset(edge: .bottom)` to pin a primary-action button above the keyboard/tab bar. Keep `Space.gutter` (20pt) as the side margin only where you're outside a `List`. Give the hero balance generous breathing room, color-code the active network on every screen via `NetworkBadge`, and honor Reduce Motion (drop scales/spinners to a fade).

> See the live web UI kit (`ui_kits/wallet/`) for the canonical look of each screen: Welcome, Choose network, Create, Import, Backup reveal + verify, Home, Activity, Transaction detail, Send → review → sent, Receive, Manage wallets, Settings, Network backends.
