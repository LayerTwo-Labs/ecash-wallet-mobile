# Running on a real iPhone — signing & install

A runbook for installing eCash.com Wallet on a physical iOS device for testing. iOS device
installs require **code signing**, which is an interactive Apple-account step done in **Xcode**
(there's no fully-headless Skip CLI path for it — `skip app launch` targets the *simulator*).
After the one-time setup below, you just pick your iPhone in Xcode and hit Run.

> Android is different and fully CLI — see the bottom of this file. The hard part here is iOS only.

## Project facts you'll need

| Thing | Value |
|---|---|
| Workspace | `Project.xcworkspace` (repo root) |
| App scheme / target | `ECashWalletMobile App` |
| Bundle identifier | `com.layertwolabs.mobile.ecashwallet` (set in `Skip.env` → `PRODUCT_BUNDLE_IDENTIFIER`) |
| Min iOS | **26.0** — the test iPhone must be on iOS 26 or newer |

## Free Apple ID vs. paid Developer Program

You can test on your own device with either:

- **Free Apple ID (Personal Team)** — fine for hands-on testing. Caveats: the app **expires
  after 7 days** (just re-run from Xcode to refresh), max ~3 sideloaded apps, no push, no
  TestFlight, and the bundle ID may need to be unique to you (see step 5).
- **Apple Developer Program ($99/yr)** — no 7-day expiry, all capabilities, and unlocks
  **TestFlight** for over-the-air beta installs (the better path once you want other testers).

## One-time setup (≈10 min)

1. **Open the workspace**
   ```bash
   open Project.xcworkspace
   ```

2. **Add your Apple ID to Xcode** — Xcode → **Settings** (⌘,) → **Accounts** → **+** →
   *Apple ID* → sign in.

3. **Select the app target** — in the left project navigator click the project, then select the
   **`ECashWalletMobile App`** target → **Signing & Capabilities** tab.

4. **Enable automatic signing** — check **"Automatically manage signing."**

5. **Pick your Team** — choose *Your Name (Personal Team)* for a free Apple ID, or your org for a
   paid account.
   - If Xcode flags the **bundle identifier** as unavailable (common on a free team if
     `com.layertwolabs.mobile.ecashwallet` is already registered to the L2L paid team), change it
     to something unique like `com.<yourname>.ecashwallet`. **Set it in `Skip.env`**
     (`PRODUCT_BUNDLE_IDENTIFIER`), not just in Xcode — the value is generated from `Skip.env` and
     a direct Xcode edit can be overwritten on the next build. Revert it before committing.

   Xcode will then auto-create a signing certificate + provisioning profile for you.

6. **Enable Developer Mode on the iPhone** (iOS 16+, required for dev-signed apps) — on the phone:
   **Settings → Privacy & Security → Developer Mode → On → Restart.** Easy to miss; the app won't
   launch without it.

7. **Plug in & trust** — connect the iPhone via USB, unlock it, tap **"Trust This Computer,"**
   enter the passcode.

## Build & run

8. In Xcode's toolbar, set the **run destination** (next to the scheme name) to your iPhone.
9. Press **Run (⌘R)**. Xcode builds → signs → installs → launches. (First build is slower — the
   Skip plugin also transpiles the Android side as part of the build.)

10. **Trust the developer (free Apple ID only)** — first launch is blocked with *"Untrusted
    Developer."* On the phone: **Settings → General → VPN & Device Management → Developer App →**
    tap your Apple ID → **Trust.** Then open the app.

## After the first run

- **Wireless installs:** Xcode → **Window → Devices and Simulators** → select the device →
  check **"Connect via network."** From then on you can Run over Wi-Fi (no cable).
- **Free team expiry:** if the app stops launching after ~7 days, just Run again from Xcode.
- `skip devices` lists the connected iPhone (via `devicectl`) so you can confirm it's seen.
- `skip app launch` still targets the **simulator** — for the physical device, run from Xcode
  (or `xcodebuild`/`devicectl` against the device once signing is set up).

## TestFlight / other testers (later)

For beta testers who aren't on your Mac, the path is TestFlight (needs the paid program):
`skip export --release` → signed archive → upload to App Store Connect (typically via **fastlane**;
`Darwin/fastlane/` metadata already exists). That's the `skip-deployment` workflow — separate from
this on-device dev-install runbook.

---

## Android, for contrast (fully CLI)

No signing ceremony — a physical Android device is just another `adb` target:

1. Phone: **Settings → Developer Options → USB debugging** on; plug in; tap **Trust**.
2. `skip devices` (or `adb devices`) to confirm it shows.
3. Build + install:
   ```bash
   skip export --debug
   adb install -r .build/skip-export/ECashWalletMobile-debug.apk
   # multiple devices attached? adb -s <serial> install -r <apk>
   ```
   Or open the generated `Android/` project in Android Studio and Run. Wireless works via
   `adb pair` / `adb connect`.
