# Release & distribution (fastlane)

> How the app is built, signed, and shipped to the **App Store / TestFlight** (iOS) and **Google
> Play** (Android), via fastlane. Secrets are gitignored and supplied locally (templates committed).
>
> **Status (2026-06-19):** Version **0.1.0** (build 1) — nothing shipped yet. iOS is **connected**
> (App Store Connect API key in place, auth + app record verified) → push via `fastlane beta`
> (TestFlight). Android ships as a **pass-around APK** (arm64) for now (§2a); Google Play upload via
> fastlane is documented (§2b) but not wired in this checkout (no service-account JSON / upload keystore).

All fastlane commands run from the platform subdir: `cd Darwin` (iOS) / `cd Android` (Android).
Bundle id / package = `com.layertwolabs.mobile.ecashwallet` (from `Skip.env`, shared by both).

**Version** is centralized in `Skip.env` — `MARKETING_VERSION` (semantic, currently `0.1.0`) +
`CURRENT_PROJECT_VERSION` (build number, currently `1`), shared by iOS and Android. **Bump
`CURRENT_PROJECT_VERSION` before each repeat TestFlight/Play upload** (build numbers must be unique).

---

## 1. iOS — App Store / TestFlight ✅ connected

### Lanes (`Darwin/fastlane/Fastfile`)
- **`fastlane assemble`** — archive/build the iOS app only (`build_app`, scheme "ECashWalletMobile App").
- **`fastlane beta`** — `assemble` → **upload to TestFlight** (no review submission). Use this first.
- **`fastlane release`** — `assemble` → **upload to App Store + submit for review** (Deliverfile).

### Auth — App Store Connect API key (the key secret)
`Darwin/fastlane/apikey.json` (gitignored; template `apikey.json.example`) holds the **ASC API key**:
`key_id`, `issuer_id`, and the `.p8` private key (inline). Generate at App Store Connect → Users and
Access → Integrations → App Store Connect API (Team Key, role App Manager); download the `.p8` once.
Every lane authenticates via `api_key_path: "fastlane/apikey.json"` — no Apple-ID password / 2FA.

### Signing
Automatic signing during archive, using `DEVELOPMENT_TEAM` from the gitignored
`Darwin/DeveloperSettings.xcconfig` (also pulled into `Darwin/fastlane/AppStore.xcconfig`). The API
key lets fastlane fetch/create the App Store provisioning profile. If a first run reports a missing
**distribution certificate**, uncomment `get_certificates(api_key_path: "fastlane/apikey.json")` in
the relevant lane — it creates one via the API key.

### Verify auth without building
```
cd Darwin && fastlane run latest_testflight_build_number \
  api_key_path:"fastlane/apikey.json" app_identifier:"com.layertwolabs.mobile.ecashwallet"
```
"Could not find a build upload … Result: 1" = auth OK + app found, no builds yet (the healthy
fresh-app state).

---

## 2. Android — distribution

### 2a. Pass-around APK (current method) ✅
Share a signed release **APK** with testers — no Play needed:
```
scripts/build-apk.sh            # arm64 → .build/dist/eCashWallet-<version>-aarch64.apk
ARCH=all scripts/build-apk.sh   # every ABI (much bigger; only for x86/armv7 devices)
```
- **arm64 (aarch64) by default** — covers ~all modern phones. The Swift runtime makes each ABI
  ~170 MB, so we don't ship `all` unless needed.
- **Signing:** falls back to the **debug keystore** (no `keystore.properties`) → sideload-installable
  (testers enable "install unknown apps"), **not** Play-grade. Set up an upload keystore (§2b.3) only
  when going to Play. (Nothing's published, so switching to a proper key later is still safe.)
- Under the hood: `skip export --release --no-ios --arch aarch64` — skips the iOS archive and the
  armv7/x86_64 native compiles (~7 min → ~1–2 min; flags in `scripts/run-android.sh` +
  `Android/gradle.properties`). `scripts/run-android.sh` is the same build but installs to a device.

### 2b. Google Play (optional, not wired) ⬜
The fastlane config exists (`Android/fastlane/` — `assemble` builds an AAB via gradle `bundleRelease`;
`release` runs `upload_to_play_store`), but the **credentials + signing aren't wired** in this
checkout (and its AAB output path is the skip-template default, not our build). To connect it:

1. **Google Play Console app.** Create the app in Play Console with package
   `com.layertwolabs.mobile.ecashwallet`. **First upload must be done manually** through the Play
   Console UI (Google blocks API uploads until at least one AAB has been uploaded by hand) — plan a
   one-time manual first release, then fastlane for everything after.
2. **Play service-account JSON** → `Android/fastlane/apikey.json` (gitignored). Create a service
   account (Play Console → Setup → API access → link a Google Cloud project → create service account
   → grant it release permissions), download the JSON key. This is the Android analog of the iOS ASC
   key. Verify with `cd Android && fastlane run validate_play_store_json_key json_key:"fastlane/apikey.json"`.
3. **Upload keystore + `Android/app/keystore.properties`** (both gitignored). `build.gradle.kts`
   reads `keyAlias` / `keyPassword` / `storeFile` / `storePassword` from `keystore.properties` and
   signs the release AAB with it (falls back to the debug key if the file is absent — fine for local
   testing, **not** for Play). Recommended: enroll in **Play App Signing** (Google holds the app
   signing key; you sign uploads with an *upload* key) — generate an upload keystore:
   ```
   keytool -genkey -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   then point `keystore.properties` at it. Keep `upload.jks` out of git (it's gitignored).
4. **`minSdkVersion 28`** is already emitted; no extra config.

### Lanes (`Android/fastlane/Fastfile`), once the above exist
- **`fastlane assemble`** — gradle `bundleRelease` → `.build/Android/app/outputs/bundle/release/app-release.aab`.
- **`fastlane release`** — `assemble` → `upload_to_play_store` (defaults to the production track;
  add `track: "internal"` for an internal-testing first push, the Play analog of TestFlight).

### Note: AAB vs APK
Play wants an **`.aab`** (App Bundle); the `adb install` debug flow we use for on-device testing uses
the debug **APK** (`skip export --debug`). Different artifacts — the release path is the AAB.

---

## 3. Secrets (all gitignored — never committed)

| File | Platform | What |
|---|---|---|
| `Darwin/fastlane/apikey.json` | iOS | App Store Connect API key (`.p8` inline) |
| `Darwin/DeveloperSettings.xcconfig` | iOS | `DEVELOPMENT_TEAM` |
| `Android/fastlane/apikey.json` | Android | Play service-account JSON |
| `Android/app/keystore.properties` | Android | release keystore alias + passwords + path |
| `Android/app/*.jks` / `upload.jks` | Android | the keystore itself |

Committed **templates**: `Darwin/fastlane/apikey.json.example`, `Darwin/DeveloperSettings.xcconfig.example`.

## 4. TODO / open
- **Build-number bumping:** TestFlight/Play require a unique build number per upload. Build 1 is fine
  now; add `increment_build_number` (or a timestamp) before the second upload.
- **CI:** lanes are local-only today; wiring them into CI (with the secrets injected) is future.
- **Store metadata / screenshots / privacy:** `fastlane/metadata/` + Deliverfile exist but need real
  copy, screenshots, and the privacy-nutrition / data-safety forms filled before public release.
- **Android first manual upload** (see §2.1) before `fastlane release` can push.
