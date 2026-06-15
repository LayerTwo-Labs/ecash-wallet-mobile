# CoinNews integration — design record (TO BUILD)

> **Status:** 🟡 PLANNED — not built. Captures how the wallet will **fetch** and **publish** CoinNews
> once we're ready. The protocol itself is summarized in memory `coinnews-protocol`; the canonical
> spec is the CoinNews draft (BSD-2). Reference code lives in `LayerTwo-Labs/drivechain-frontends`:
> the wire codec at **`coinnews/codec/`** (Go) and a standalone hostable indexer+API at
> **`coinnews/server/`** (Go, ConnectRPC) with a Next.js consumer at `coinnews/app/` — NOT the
> BitWindow desktop GUI (that's a separate consumer of the same on-chain data).
>
> CoinNews is a trustless, server-less bulletin board (Topics → Stories → signed Comments/Votes)
> encoded entirely in Bitcoin `OP_RETURN` outputs. Every indexer rebuilds the identical view by
> scanning blocks in canonical `(block_height, tx_index, vout_index)` order. eCash is byte-identical
> Bitcoin, so it runs on our chain. Complements `docs/backends-and-endpoints.md`, `docs/key-storage.md`,
> and `docs/wallet-and-network-model.md`.

---

## 1. Scope

Two independent halves, very different in difficulty:

- **Fetch (read):** show a CoinNews feed — front page (ranked Stories), threads (Comments), scores.
- **Publish (write):** post a Story, reply with a Comment, cast an Up/Downvote, create a Topic.

Both are **network-scoped** (CoinNews on Testnet4 ≠ on eCash mainnet) and resolve through the same
`NetworkRegistry` seam as backends/explorers — a CoinNews wallet on network X reads/writes X's board.

Likely build order: **read-only feed first** (lower risk, no new signing), then publishing.

## 2. Architecture overview

Three pieces; keep them separate:

1. **`CoinNewsCodec` (pure Swift, cross-platform).** Encode/decode the wire format from the spec:
   envelope (`"CN" ‖ TypeTag`), compact-size varints, the six message types, the TLV layer, ItemID
   truncation (`sha256(txid_LE ‖ vout_LE)[0:12]`), and the per-type BIP-340 tagged-hash domains. No
   platform deps → compiles natively on both platforms in Fuse (same posture as `QRCodeGenerator`).
   Mirror **`coinnews/codec/`** (Go: `encode.go`/`decode.go`/`sign.go`/`itemid.go`/`tlv.go`/
   `varint.go`); port `codec_test.go`'s vectors verbatim (the spec also ships hex vectors — §"Test
   Vectors"). This is shared by both the reader (verify) and the publisher (build).
2. **`CoinNewsReader` (indexer client).** Fetches the ranked feed / threads (see §4).
3. **`CoinNewsPublisher` (compose + sign + broadcast).** Builds the `OP_RETURN` tx via the
   WalletService/BDK seam and signs the author Schnorr signature (see §3).

## 3. Publishing (write) — closest to what we already do

A CoinNews message is a transaction with **one `OP_RETURN` output** carrying the payload. We already
do build → sign → broadcast; this adds an `OP_RETURN` output and an author signature.

### 3.1 Building the OP_RETURN tx
- BDK `TxBuilder` can add an `OP_RETURN`/data output. **VERIFY:** does `bdk-swift` 2.3.1 expose
  `add_data` / an OP_RETURN output on `TxBuilder`? (rust-bdk has `TxBuilder::add_data`.) If the FFI
  doesn't surface it, that's a `bdk-ffi` extension — same "regenerate Swift+Kotlin together" path as
  the future BIP300/301 work (CLAUDE §12).
- The tx still needs a funding input + change; the `OP_RETURN` output is value-0. Normal coin
  selection + fee. Reuses the watch-only-build / sign-on-demand path (`docs/key-storage.md §3`).
- **ItemID** of the new Item = `sha256(txid_LE ‖ vout_LE)[0:12]` of the message's own output — known
  only *after* the tx is built (txid). For references (a Comment's `parent_id`, a Vote's `target_id`),
  the publisher already holds the target outpoint (it's rendering the target) and hashes it.

### 3.2 Author identity + Schnorr signing — THE gap
- CoinNews authors are **BIP-340 x-only secp256k1 pubkeys**, distinct from the wallet's BIP-84
  spend addresses. We need a **dedicated CoinNews identity key** derived from the wallet seed (a
  fixed derivation path — DECIDE which; one identity per wallet to start). Derive/sign on demand,
  never persist the private key (Golden Rule §2 / `docs/key-storage.md`).
- Comments/Votes are signed with **BIP-340 Schnorr over a per-type tagged hash**
  (`tagged_hash("CoinNews/Vote", …)`, `tagged_hash("CoinNews/Comment", …)`). **VERIFY:** does the BDK
  binding expose raw Schnorr signing of an arbitrary 32-byte message? Standard wallet FFIs often
  don't — this may require extending `bdk-ffi` or pulling a `secp256k1`/`rust-secp` Schnorr primitive
  into `WalletService`. Per Golden Rule §1 (BDK owns crypto), do NOT hand-roll Schnorr — surface it
  through the Rust core. This is the single biggest unknown for publishing.
- Stories are **unsigned** (attribution = first input address), so a Story-only publisher needs no
  Schnorr — useful for a first publishing slice.

### 3.3 Relay policy — the 111-byte problem
- A **Vote/Comment is 111 bytes** of `OP_RETURN`, above the **80-byte** standard relay default. The
  publishing node/relay needs **`-datacarriersize ≥ 111`**. Our default public backends
  (mempool.space, blockstream) likely **reject** it. **VERIFY** eCash/drivechain relay policy; if it
  doesn't allow 111-byte data, publishing Votes/Comments requires a permissive relay or own node
  (ties into the custom-endpoint feature, `docs/backends-and-endpoints.md`). Stories (often ≤80 B)
  may broadcast on default relays; longer payloads chunk via Continuation (§9 of the spec).

## 4. Fetching (read) — the harder half

A feed needs an **indexer**: scan every block's `OP_RETURN`s, decode, resolve ItemIDs, verify
signatures, dedup votes, rank (HN formula). **The Electrum/Esplora protocols our BDK backend speaks
can't enumerate `OP_RETURN`s** — they're keyed by scriptPubKey/txid (no content scan) — so we cannot
derive a feed from our existing sync path. The indexing itself happens server-side against a node.

**This already exists as a standalone, hostable service.** In `LayerTwo-Labs/drivechain-frontends`
there's **`coinnews/server`** (Go), decoupled from the BitWindow desktop GUI:
- connects to a **Bitcoin Core node via RPC** (`COINNEWS_BITCOIND_URL`), scans blocks through
  `coinnews/codec`, persists to **SQLite**, and serves a **ConnectRPC** API on `:8080`;
- `-scan`/`COINNEWS_SCAN` toggles the scanner — **`scan=false` = read-only API mode**, so the heavy
  scanning and the API can be split (one scanner fills the DB; light API servers serve it);
- the reference consumer is the **Next.js `coinnews/app`** (web), which talks to it via Connect —
  i.e. the architecture is already "hostable server ← thin clients", which is exactly our model.

**`CoinNewsService` (read-only RPCs):** `ListFrontPage`, `ListNewFeed`, `GetItem`, `ListThread`,
`ListByAuthor`, `ListByTopic`, `ListTopics` — paginated (`limit`/`offset`), filterable by
`subtype`/`topic_hex`; returns `Item`/`Comment`/`Topic` (hex IDs, score, points, block height/time).
No publish RPCs — publishing stays wallet-side (§3).

| Option | What | Mobile fit | Trust |
|---|---|---|---|
| **A. Consume `coinnews/server`** | Call its ConnectRPC over **HTTP/JSON** (URLSession; or `connect-swift`) | ✅ Best for a phone | Trusted for *availability/ordering*; verifiable for *authorship* (§4.1) |
| **B. + client verification** | Same API, client re-verifies sigs + ItemIDs against on-chain data | ✅ Good | Low — indexer can omit but not forge |
| **C. Embedded indexer** | Scan blocks on-device | ❌ Not viable on mobile (a node + full scan) | None |

**Recommendation:** ship **A → B**. `CoinNewsReader` calls the `coinnews/server` ConnectRPC — Connect
unary calls are plain `POST /coinnews.v1.CoinNewsService/<Method>` with a JSON body, so **URLSession
is enough; no gRPC dependency** (or use the pure-Swift `connect-swift` client). The endpoint is a
`NetworkRegistry`-resolved default + user override (same pattern as backends). Then layer client-side
verification: `CoinNewsCodec` verifies each Item's Schnorr sig and recomputes its ItemID from the
cited outpoint (fetched via the wallet's own Electrum/Esplora backend). The spec's "no trusted server"
ethos holds — *anyone* can run `coinnews/server` and clients can verify; the phone never scans.

### 4.1 What the client can verify regardless of the indexer
Given an Item's `(txid, vout)`, the wallet independently: recomputes the ItemID, fetches the tx
(backend), reads the `OP_RETURN`, decodes it, and verifies the Schnorr signature. So a hostile
indexer can **hide** Items or **misrank** them, but **cannot forge** authorship or content. Surface
verification state in the UI when we get to B.

## 5. Where it lives in the app

- **`CoinNewsCodec`** — pure-Swift, app-module or its own SwiftPM package (no platform deps). Shared
  by reader + publisher; this is where the spec's test vectors live as unit tests.
- **Schnorr signing + `OP_RETURN` tx build** — through the **WalletService/BDK seam** (the only place
  with key material and consensus logic, Golden Rule §1/§3). Likely a `bdk-ffi` extension.
- **`CoinNewsReader`** — an HTTP client (URLSession; remember `import FoundationNetworking` on
  Fuse-Android, memory `fuse-networking-and-pricing`). Endpoint per network via `NetworkRegistry` +
  override, mirroring backends.
- **Identity key** — derived in `WalletService` from the seed at a fixed path; sign-on-demand.
- **UI** — a CoinNews tab/section (feed, thread, compose). Out of scope until the data layer lands.

## 6. Key unknowns to resolve before building

1. **Schnorr signing primitive** — does the BDK binding expose BIP-340 signing of an arbitrary
   tagged hash, or do we extend `bdk-ffi`? (Blocks Comment/Vote publishing.)
2. **`OP_RETURN` output via `TxBuilder`** — confirm `add_data` is in `bdk-swift` 2.3.1 or needs FFI work.
3. **Relay `datacarriersize`** on eCash/drivechain — can 111-byte `OP_RETURN`s be broadcast on the
   default backends, or only via a permissive/own node?
4. **Identity derivation path** — one CoinNews author key per wallet; pick a path; relation to the
   wallet's BIP-84 keys (separate, by design).
5. **Indexer hosting — NO public endpoint exists yet (probed 2026-06-15).** The API
   (`coinnews/server` ConnectRPC `CoinNewsService`) and its shape are known, but a scan of L2L hosts
   found only the signet **faucet** (`node.signet.drivechain.info`) and **explorer**
   (`explorer.signet.drivechain.info`) — no live `CoinNewsService` anywhere, and `coinnews.*`/`news.*`
   subdomains don't resolve. Matches the repo (web client defaults to `localhost:8080`; README runs
   locally). So **we must self-host `coinnews/server`** (signet/eCash Core node + scanner) and point
   the wallet at it, or wait for L2L to deploy a public one. This blocks only the **read** phase;
   the codec phase (Phase 1) needs no server.

## 7. Phased plan

1. **Codec + vectors.** `CoinNewsCodec` encode/decode all six types + TLV + ItemID, ported Go test
   vectors. No chain, no UI. Pure unit tests, both platforms.
2. **Read-only feed (Option A).** `CoinNewsReader` against a configurable indexer endpoint; a feed +
   thread UI. Render-only; no keys.
3. **Publish Stories.** Compose an `OP_RETURN` Story tx (unsigned — no Schnorr yet) via WalletService;
   broadcast; optimistic insert. Resolves unknowns #2 and #3 on the easiest message.
4. **Identity + signed Comment/Vote.** Add the Schnorr identity key + signing (unknown #1), then
   Comments and Votes. Voting needs the 111-byte relay (#3).
5. **Trust-minimized read (Option B).** Client-side sig/ItemID verification against on-chain data.

## 8. Out of scope (for now)
Embedded on-device indexing; running our own CoinNews indexer; the metadata-registry tooling
(§11 of the spec — informational); moderation/curation beyond the spec's ranking.
