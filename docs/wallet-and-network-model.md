# Wallet & Network Model — decision record

**Status:** 🟢 DECIDED 2026-06-12. Defines what a "Wallet" is, how networks work, and what we ask at
creation. **Revises Golden Rule §4** (network is no longer a per-wallet *pin*). Complements
`docs/key-derivation.md` (eCash = Bitcoin params) and `docs/accounts-and-labels.md` (accounts/labels).

---

## 1. A "Wallet" = its own seed (mnemonic)

- **Creating a wallet generates a new mnemonic.** savings / checking / inheritance = **three
  separate seeds, three recovery phrases.** Multiple wallets = multiple independent seeds.
- **Why separate seeds (not accounts) by default:** isolation. Losing or *handing off* one phrase
  (e.g. an inheritance wallet) must not expose the others — the account model (`m/84'/c'/k'` under
  one phrase) can't give that (one phrase unlocks everything). Separate seeds is also the simpler
  mental model and is what **import** already requires (each imported wallet is its own seed).
- **Multiple seeds stored simultaneously: yes** (required for import; Keychain is already keyed per
  `walletId`). Each wallet's mnemonic lives in the Keychain under its `walletId`; removal purges it.
- **Accounts-under-one-seed** (one backup → multiple sub-wallets, BIP-84 account level) stays an
  **opt-in power-user feature for later**, never the default. See `docs/accounts-and-labels.md`.

## 2. Network is a switchable VIEW within a wallet — not a pin, not asked at creation

- **We do NOT ask "which network?" at creation.** New wallets default to **Testnet4**; the user
  switches network inside the wallet afterward.
- **Why:** our three near-term networks — **Testnet4, eCash-testnet, eCash-signet** — are all
  "testnet-class": **coin-type `1'`, HRP `tb`** (per `docs/key-derivation.md`). So one mnemonic
  produces the **identical addresses** on all three; the *only* difference is **which node/backend**
  you talk to. "Which network" therefore isn't a key decision at all for these three — it's just
  which chain you're viewing. Asking at creation would be a meaningless step.
- **One descriptor set, many networks.** Because the three share coin-type `1'`, a wallet derives
  **one** BIP84 testnet descriptor set that's valid across all three. Switching network = pointing
  the engine at that network's backend + showing that chain's balance/history.
- **Isolation per (wallet × network):** each network keeps its **own** BDK chain store / balance /
  history, so the same `tb1q…` address never shows testnet4 coins mixed with eCash-signet coins.
- **Unmistakable network (Golden Rule §6 unchanged):** the network badge + label appear on every
  money surface; switching network is explicit and visible.

## 3. eCash mainnet (later) is the deliberate, weighty case

eCash *mainnet* is **coin-type `0'`, HRP `bc`** — genuinely different addresses (a separate
derivation branch), and real money. It is byte-identical to Bitcoin mainnet with **no replay
protection**, so entering it must be deliberate and clearly heavier than the dev networks (extra
confirmation on send, prominent badge). When it lands it's a new `NetworkRegistry` entry + a
distinct (coin-type `0'`) descriptor set on the same seed — not a casual toggle alongside the
testnets.

## 4. What this changes vs. the original CLAUDE.md

- **Golden Rule §4 revised:** "network is a per-wallet property, fixed at creation" → **"a wallet is
  a seed; the selected network is a switchable view, resolved through `NetworkRegistry`."** The
  registry / never-hardcode / unmistakable-network rules all still hold.
- **Create flow:** no network question. `Welcome → Create wallet → generate seed → Home (Testnet4)`,
  with a network switcher available and a "not backed up" nudge until Backup (Slice 3).
- **`ManagedWallet`:** network becomes the *currently-selected* view, not an immutable pin; the
  wallet's descriptors are the shared testnet (coin-type `1'`) set. (Code change lands in Slice 1.)

## 5. Still true (unchanged guarantees)

- Wallets isolated by `walletId`; remove purges every keyed artifact (Golden Rule §5).
- All network params resolve through `NetworkRegistry`; never hardcoded (Golden Rule §4 intent).
- Network unmistakable at every money-touching surface (Golden Rule §6).
- BDK owns keys/consensus; only the mnemonic is persisted (`docs/key-storage.md`).
