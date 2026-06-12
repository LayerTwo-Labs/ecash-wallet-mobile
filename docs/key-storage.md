# Key Storage — security decision record

How the wallet persists and protects private key material. Complements `CLAUDE.md` §7 (security
model) and the Golden Rules (§2). Keep in sync with `KeyStore.swift` / `WalletStore.swift`.

---

## 1. What we persist

**Exactly one secret: the BIP39 mnemonic phrase** (the words, as a `String`), one entry per wallet.

- Stored via `KeychainKeyStore` (`KeyStore.swift`), key `ecashwallet.mnemonic.<walletId>`.
- We do **NOT** persist the seed bytes, the `xprv`, or any private descriptor. BDK **derives**
  those from the mnemonic at runtime (to build descriptors / sign) and they are dropped — never
  written to disk.
- `WalletStore` (a JSON file) holds **public data only**: label, network, xpub-based descriptors,
  backup flag, order. No key material.

Rationale: the mnemonic is the minimal, standard, human-restorable secret; everything else is
either derivable from it or public. Storing the phrase (not seed/xprv) is what the backup/reveal
and cross-wallet-import flows need.

## 2. Where it lives (SkipKeychain, per platform)

| | iOS | Android |
|---|---|---|
| Backing | native **Keychain** (`SecItem…`) | **EncryptedSharedPreferences** (Jetpack Security), file `tools.skip.SkipKeychain` |
| At rest | Keychain class keys protected by the **Secure Enclave** | values **AES-256-GCM**, keys AES-256-SIV, under a **master key in the Android Keystore** (hardware-backed where a TEE/StrongBox exists) |
| Our access flag | `.unlockedThisDeviceOnly` → `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (decryptable only while unlocked; **no iCloud sync**; does not migrate to a new device) | ⚠️ **the access flag is iOS-only** — on Android it's a no-op; EncryptedSharedPreferences encrypts at rest but does not bind to device-unlock/biometric |

Both platforms give **encryption at rest with a hardware-protected key**. The master key is
device-bound on both, so the secret cannot be decrypted on another device.

## 3. Core principle: the mnemonic must be readable for normal operation

Every sync / balance / send needs BDK to re-derive keys from the mnemonic, so we **cannot** put a
biometric prompt on every read — that would prompt on routine activity. Therefore:

- The mnemonic is stored at **device-unlocked** readability (not per-read auth-gated).
- Protection of **sensitive actions** is an **app-level gate**, not a per-read Keychain ACL — see §5.

This is the standard mobile-wallet pattern. The consequence to accept: on an unlocked device with
the app running, the mnemonic is readable by the app process. Mitigations are the app-lock (§5) and,
optionally, auth-bound keys (§6).

**Planned engine shape — watch-only tracking, sign-on-demand (do at the Send slice).** Only
*signing* needs the private keys; balance/addresses/sync/history need only the **public** (xpub)
descriptor. So the everyday `Wallet` should be built from the **public** descriptors (watch-only,
**no mnemonic read at all**), and the mnemonic loaded → private descriptors **only to sign a send**,
then dropped. Today `BDKWalletEngineFactory.engine(for:)` builds from the **private** descriptors,
so the mnemonic is read on every engine construction (wallet load) and the wallet can sign for the
whole session. Narrowing to sign-on-demand shrinks the secret's in-memory window to a few seconds
per send and pairs naturally with the per-send gate (§5). Current code is correct, just broader than
necessary — land this with the Send slice + its tests.

## 4. Backup handling (DECIDED + shipped)

Android `allowBackup` is `true` (Skip default) and useful for the harmless public data (wallet-list
metadata, chain cache). But the encrypted mnemonic prefs must **not** be backed up: the Keystore
master key is device-bound, so a backed-up copy is undecryptable elsewhere **and** triggers
SkipKeychain's silent-wipe-on-restore path (`AEADBadTagException`).

**Shipped:** targeted exclusion of `tools.skip.SkipKeychain` from both backup paths —
`Android/app/src/main/res/xml/backup_rules.xml` (API ≤30 `fullBackupContent`) and
`data_extraction_rules.xml` (API 31+ `cloud-backup` + `device-transfer`), referenced from
`AndroidManifest.xml`. Verified building via `skip export --debug`.

iOS needs no equivalent: `WhenUnlockedThisDeviceOnly` already excludes the item from iCloud and
device migration.

## 5. App-lock & action gates (DESIGN — not built yet; UI/hardening milestone)

The planned protection layer (CLAUDE.md §7). Lives in the **app module** (Fuse), platform-bridged;
gates the UI/flows, **not** the KeyStore read (which stays device-unlock readable so sync works).

- **Launch / resume gate:** biometric-or-passcode on cold launch and on foreground after an idle
  timeout. Settings toggle; default on. Failure → locked screen, no wallet data shown.
- **Per-action gate — reveal seed:** biometric/passcode → reveal words → confirm N random words →
  mark `isBackedUp`. **Screenshot-blocked:** `FLAG_SECURE` on Android, obscure-on-backgrounding on
  iOS.
- **Per-action gate — send:** biometric/passcode confirm immediately before broadcast. Default on
  (toggle in Settings). This is in addition to the explicit recipient/amount/fee/**network** review.
### Mechanism — two complementary primitives (don't conflate them)

There are **two different** auth mechanisms; we use both, for different jobs:

- **(b) Standalone auth prompt — used by THIS section (app-lock + action gates).** Just asks "is it
  you?" and returns a **boolean**. Gates things that are *not* reading a stored secret: launch/resume
  lock, the Send confirm, a sensitive settings change, re-revealing in-memory data.
  ⚠️ This is a **UX gate, not a cryptographic boundary** — on a rooted/jailbroken device the boolean
  can be subverted. Use it freely for UX; do **not** rely on it to protect the seed itself.
- **(a) Auth-*bound* key — §6, used to protect the seed at rest.** Cryptographically ties *using* the
  stored secret to a fresh auth (the data is undecryptable without it). Stronger; reserved for the
  mnemonic. See §6.

**There is no first-party Skip biometric API** (verified: SkipKeychain is storage-only; no
`SkipLocalAuthentication`). So (b) is a **bridge seam** in the app module, à la the BDK seam:

```swift
protocol BiometricAuthenticator { func authenticate(reason: String) async -> Bool }
```
- **iOS** (`#if os(iOS)`, native): `LAContext().evaluatePolicy(.deviceOwnerAuthentication, …)` —
  `.deviceOwnerAuthentication` includes the **passcode fallback** (`…WithBiometrics` is bio-only).
- **Android** (`#if SKIP` → transpiled Kotlin): `androidx.biometric.BiometricPrompt` with
  `setAllowedAuthenticators(BIOMETRIC_STRONG | DEVICE_CREDENTIAL)` for the PIN/pattern/password
  fallback. Add **`androidx.biometric:biometric`** to the app Gradle (via `skip.yml`). Needs the host
  **`FragmentActivity`** (via Skip's activity accessor) and bridges its **callback → Swift `async`**
  (continuation). `BiometricPrompt` is API 28+ — matches our floor.
- **Availability/enrollment:** check `BiometricManager.canAuthenticate(...)` / iOS
  `canEvaluatePolicy` first; if nothing is enrolled, fall back to device credential or block the gate
  (don't silently pass).
- **`MockAuthenticator`** (configurable result) so the app-lock / reveal / send view models test on
  both platforms without real biometrics.

## 6. Optional hardening — auth-bound keys (deferred; evaluate before mainnet/funds)

Stronger than §5: bind the secret itself to user authentication, so even a compromised-but-unlocked
device can't read it without a recent auth.

- **iOS:** `SecAccessControl` with `.userPresence` / `.biometryCurrentSet`. Naive use prompts on
  every read; mitigate with the **envelope pattern** — wrap the mnemonic with an Enclave/auth-bound
  key, unwrap **once per authenticated session** into memory.
- **Android:** a Keystore key with `setUserAuthenticationRequired(true)` + a short validity window,
  used to wrap the mnemonic. (SkipKeychain's default master key is NOT auth-bound, so this is a
  custom path beyond SkipKeychain.)

Tradeoff: real UX friction and added complexity. Decision: ship §5 first; revisit §6 specifically
before eCash mainnet / real funds.

## 7. Other exposure notes

- **Process memory:** the mnemonic is a managed `String` during derivation; Swift/Kotlin strings
  aren't zeroed, so it lingers in memory transiently. Hard to fully mitigate in a managed runtime;
  keep the live window short (derive → use → drop references) and don't log it (Golden Rule §2).
- **Remove = purge:** `WalletManager.removeWallet` deletes the Keychain entry + WalletStore rows +
  the BDK chain-data SQLite (Golden Rule §5).

## 8. Status / to-dos

- [x] Persist only the mnemonic; public-only `WalletStore`; no seed/xprv on disk.
- [x] Encryption at rest both platforms (Keychain / EncryptedSharedPreferences).
- [x] iOS `WhenUnlockedThisDeviceOnly` (no iCloud, device-only).
- [x] **Android backup exclusion** of the keychain prefs (§4) — shipped + build-verified.
- [ ] **App-lock + reveal/send gates + screenshot blocking** (§5) — UI/hardening milestone.
- [ ] Decide on **auth-bound keys** (§6) before mainnet/funds.
- [ ] Secret-scrub audit across logs/errors/analytics (CLAUDE.md §7) before release.
