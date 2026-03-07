# solana-client-zig TODO

Snapshot: 2026-03-07
Current commit: `70c0739`

## Purpose

This file tracks feature parity work against Agave's Rust client stack and
turns the comparison into an implementation backlog for this Zig project.

Primary upstream references:

- `agave/client`: <https://github.com/anza-xyz/agave/tree/master/client>
- `agave/rpc-client`: <https://github.com/anza-xyz/agave/tree/master/rpc-client>
- `rpc-client/src/rpc_client.rs`: <https://github.com/anza-xyz/agave/blob/master/rpc-client/src/rpc_client.rs>
- `client/src/lib.rs`: <https://github.com/anza-xyz/agave/blob/master/client/src/lib.rs>

Local code anchors:

- Core RPC client facade: [src/root.zig](./src/root.zig)
- Core RPC client implementation: [src/client/rpc_client/client.zig](./src/client/rpc_client/client.zig)
- Typed SDK layer: [src/client/sdk.zig](./src/client/sdk.zig)
- CLI parsing: [src/cli.zig](./src/cli.zig)
- CLI command execution: [src/commands.zig](./src/commands.zig)
- Root integration tests: [tests/root](./tests/root)

## Current Positioning

This Zig project is already much closer to Agave's blocking `rpc-client` than
to the full `client` crate.

That distinction matters:

- `rpc-client` is mostly JSON-RPC request/response, polling, and convenience wrappers.
- `client` also includes TPU/QUIC sending, connection cache, async/nonblocking,
  pubsub, nonce helpers, and parallel transaction execution.

So "feature parity with Rust client" should be read in two layers:

1. Reach strong parity with blocking `rpc-client`.
2. Only then decide how much of `client`'s higher-level transport stack is
   actually worth porting to Zig.

## Status At A Glance

### Completed

- The planned blocking `rpc-client` phases in this document are complete.
- Core blocking RPC coverage is present: read RPCs, encoded send/simulate,
  signature status, confirm/poll helpers, airdrop variants, and UI wrappers.
- The project now has a minimal typed SDK for both legacy and v0 transactions:
  typed messages/transactions, signing, serialization, base64 helpers, ALT
  compilation, nonce-aware builders, and owned-message helpers.
- Core client semantics that were previously placeholders are now real:
  default commitment persistence, request timeout behavior, initial
  send-and-confirm timeout handling, raw/typed RPC escape hatches, and
  spinner-style confirmation convenience.

### Remaining

- Full Agave `client` parity is not complete.
- The heavy transport/client-stack features are still absent:
  `nonblocking`, `connection_cache`, `tpu_client`,
  `transaction_executor`, and `send_and_confirm_transactions_in_parallel`.
- Some parity areas are only partial rather than complete:
  `pubsub_client`, `blockhash_query`, `nonce_utils`, Rust-style mock sender
  helpers, full raw request catalog breadth, and broader typed builder
  ergonomics.
- So the current state is: blocking Zig client roadmap mostly done, full Rust
  Agave client parity still incomplete.

## Comparison Summary

### Module-Level Parity

| Rust module | Status in Zig | Notes |
| --- | --- | --- |
| `rpc_client` | Mostly implemented | Core blocking RPC surface is largely present and now split across `src/client/rpc_client/*.zig`. |
| `rpc_config` / `rpc_filter` / `rpc_request` / `rpc_response` / `rpc_custom_error` | Partially implemented | Zig has many equivalent structs/options, but not a full Rust-style public module layout. |
| `blockhash_query` | Partially implemented | Minimal `BlockhashQuery` / `resolveBlockhashQuery` support now exists, but the broader Rust helper surface is still incomplete. |
| `nonce_utils` | Partially implemented | Nonce account parsing, nonce blockhash lookup, and minimal nonce-aware transfer/instruction builders now exist, but the broader durable-nonce utility surface is still incomplete. |
| `pubsub_client` | Partially implemented | A minimal websocket-based pubsub client now exists with `signatureSubscribe`, `logsSubscribe`, `accountSubscribe`, `programSubscribe`, `slotSubscribe`, and `rootSubscribe`, plus subscription dispatch, typed notification helpers, and integration tests; the broader Rust pubsub surface is still incomplete. |
| `nonblocking` | Not implemented | No async RPC client surface. |
| `connection_cache` | Not implemented | No QUIC/UDP connection cache abstraction. |
| `tpu_client` | Not implemented | No direct-to-leader TPU sending path. |
| `transaction_executor` | Not implemented | No background pending-transaction executor. |
| `send_and_confirm_transactions_in_parallel` | Not implemented | No parallel sender/re-sign/retry flow. |
| mock sender helpers | Not implemented | Tests currently use local mock HTTP servers, not a Rust-style mock sender API. |

### Blocking `rpc-client` Surface

| Capability group | Status | Notes |
| --- | --- | --- |
| Basic read RPCs | Implemented | Slot, block height, balance, account, program account, token, block, transaction, supply, inflation, vote, block production, etc. |
| Signature status / confirm / poll helpers | Implemented | Recently completed and in good shape. |
| `requestAirdrop` config / blockhash variants | Implemented | Config variants are present. |
| UI convenience wrappers | Implemented | `getAccountData`, `getUiAccount*`, `getTokenAccount*`, `getProgramUiAccounts*`. |
| `getNewLatestBlockhash` | Implemented | Library and CLI both expose it now. |
| Send / simulate / send-and-confirm for encoded tx | Implemented | Base64 signed transaction path is available. |
| Constructor semantic parity | Mostly implemented | Default commitment and HTTP request timeout constructor args now persist and affect transport behavior; `confirm_transaction_initial_timeout` now extends the initial "transaction not found" window for send-and-confirm convenience flows. |
| Typed legacy transaction/message API | Implemented | Legacy typed SDK, signing, serialization, generic builder conveniences, and typed send/simulate/fee wrappers now exist. |
| Versioned transaction / v0 / ALT support | Mostly implemented | Minimal v0 typed support exists, a higher-level compiler from `Instruction` + ALT account input now exists, and SDK convenience builders can now directly sign v0 transactions; broader ergonomics are still incomplete. |
| Public raw RPC escape hatch | Mostly implemented | Public `sendRequest(method, params_json)`, `sendRaw`, `sendJsonRpc`, `sendTyped`, and `RpcRequest` helpers now exist, though the request identifier surface is still lighter than Rust's full module layout. |
| Spinner variants | Mostly implemented | High-level send-and-confirm spinner convenience methods and blockhash-aware `confirmTransactionWithSpinner` now exist; broader Rust spinner surface is still lighter than upstream. |
| Mock constructors | Missing | No `new_mock*` or similar public test helpers. |
| Async runtime / inner client accessors | Partial | `getDefaultCommitment()` now exists, but there is still no `get_inner_client()` / runtime equivalent. |

## Known Gaps Worth Tracking Explicitly

### 1. Constructor Semantics Are Only Partially Complete

These APIs exist in Zig:

- `newWithCommitment`
- `newWithTimeout`
- `newWithTimeoutAndCommitment`
- `newWithTimeoutsAndCommitment`

Current state:

- default commitment is now stored on `RpcClient` and used when call sites pass `null`
- HTTP request timeout arguments now affect transport behavior via socket read/write timeouts
- `confirm_transaction_initial_timeout` is now used by send-and-confirm convenience flows as an initial
  "transaction not found" window

So this remains a smaller parity gap focused on the confirmation-initial-timeout side.

### 2. Typed SDK Exists, But Is Not Yet Full-Fidelity

Rust `rpc-client` works with typed:

- `Transaction`
- `VersionedTransaction`
- legacy messages
- `v0::Message`

Current Zig client now supports:

- typed legacy messages and transactions
- typed versioned/v0 messages and transactions
- typed send/simulate/fee/send-and-confirm wrappers

What is still missing:

- broader transaction-construction ergonomics beyond the current minimal SDK surface
- broader ownership-friendly / multi-signer builder coverage beyond the current helper set

So the project has crossed the line into "minimal client SDK", but still does
not yet match Rust's typed convenience end-to-end.

### 3. High-Level Transaction Builders Are Still Thin

The project can now build and sign legacy and minimal v0 transactions through
typed SDK structs, and it still has direct SOL transfer helpers.

What it does not yet have is a high-level builder layer comparable to Rust's
more ergonomic typed construction flow, especially for:

- fuller transaction builder APIs around the current v0 compile/sign helpers
- richer address lookup table driven message / transaction construction ergonomics
- broader nonce-aware typed transaction helpers beyond the current prepend/build convenience layer

### 4. Raw RPC Escape Hatch Exists, But Is Still Lighter Than Rust

The client now exposes:

- `sendRequest(method, params_json)`
- `sendRaw(method, params)`
- `sendJsonRpc(method, params, ResultType)`
- `sendTyped(RpcRequest, params, ResultType)`
- `RpcRequest` method identifiers plus `RpcRequest.custom(...)`

That closes the biggest ergonomics gap, but it is still lighter than Rust's
full request module layout.

What is still missing here is mainly API breadth and polish rather than the
core escape hatch itself:

- broader parity in the request identifier catalog
- deeper integration of the raw layer into all convenience paths

### 5. Agave `client` Transport Stack Is Largely Unstarted

The following are still absent and should be treated as a separate effort:

- QUIC/UDP connection cache
- TPU client
- pending transaction executor
- parallel send-and-confirm helpers
- pubsub websocket client
- async/nonblocking client

## Next-Stage Implementation Checklist

### Phase 1: High Value, Do First

- [x] Introduce a minimal legacy typed SDK layer.
- [x] Add `Pubkey`, `Hash`, `Signature`, `Keypair`, `AccountMeta`, `Instruction`,
  `Message`, and `Transaction`.
- [x] Promote the current legacy SOL transfer builder into a general legacy
  message/transaction builder.
- [x] Add typed convenience APIs on top of existing encoded RPC paths:
  - [x] `sendTransactionTyped`
  - [x] `simulateTransactionTyped`
  - [x] `getFeeForMessageTyped`
  - [x] `sendAndConfirmTransactionTyped`
- [x] Keep the first cut focused on blocking, legacy transactions only.

Why this phase is first:

- It changes the project from "RPC caller" into "client that can build and sign".
- It unlocks most of the remaining parity work without jumping into TPU/async.
- It builds directly on the transfer work already done.

### Phase 2: Minimal v0 / ALT Support

- [x] Add `VersionedMessageV0`.
- [x] Add `VersionedTransaction`.
- [x] Add minimal address lookup table reference structures.
- [x] Extend typed send/simulate/fee helpers to support versioned transactions.
- [x] Keep scope tight: enough to build, sign, serialize, and submit v0 txs.
- [x] Add a higher-level v0 builder that compiles from instruction/account meta input.
- [x] Add ergonomic ALT-driven message compilation helpers.

Why this phase is second:

- It covers the biggest real-world SDK gap after legacy transaction building.
- It avoids prematurely implementing all of Agave's transport stack.

### Phase 3: Fix Core Client Semantics

- [x] Make constructor commitment arguments actually persist as client defaults.
- [x] Make constructor timeout arguments actually affect request behavior.
- [x] Decide whether to add explicit `confirm_transaction_initial_timeout`
  semantics similar to Rust.
- [x] Expose a low-level public raw RPC hook via `sendRequest(method, params_json)`.
- [x] Add a more Rust-like typed/raw RPC layer, for example:
  - [x] `sendRaw`
  - [x] or `sendJsonRpc`
  - [x] or `sendTyped(request, params, ResultType)`
- [x] Add minimal nonce/blockhash query helpers once typed message support exists.
- [x] Extend nonce support into higher-level transaction/message builders.

Why this phase is third:

- It tightens parity with Rust `rpc-client`.
- It improves maintainability and extensibility after the typed SDK exists.

## Explicitly Deferred Work

These items are valid Agave features, but they should not be the next thing:

- [ ] `pubsub_client`
  minimal websocket-based `signatureSubscribe` / `logsSubscribe` /
  `accountSubscribe` / `programSubscribe` / `slotSubscribe` /
  `rootSubscribe` is now in place.
  still missing broader subscription coverage, reconnect/re-subscribe behavior,
  and a more Rust-like receiver/channel surface.
- [ ] `nonblocking` async client
- [ ] `connection_cache`
- [ ] `tpu_client`
- [ ] `transaction_executor`
- [ ] `send_and_confirm_transactions_in_parallel`
- [x] Rust-style spinner helpers
- [ ] Rust-style mock sender surface

Reason for defer:

- These are expensive, multi-module features.
- They are not required to make the Zig client materially more useful right now.
- They become easier to evaluate after the minimal typed SDK exists.

## Recommended Immediate Order

If work resumes from here, the best sequence is:

1. Keep the project blocking-only for now and continue broadening blocking RPC/SDK parity.
2. Focus next on higher-level typed builder ergonomics and testability before touching TPU/QUIC or pubsub.

## Notes

- Do not chase Agave's full transport stack before the SDK layer exists.
- Do not treat `_with_timeout` naming alone as parity; actual transport behavior
  still matters.
- The project now has a real minimal SDK and a cleaner test layout under `tests/`.
- The project now also has a minimal nonce/blockhash query foundation and a
  higher-level v0 compiler; it can also build durable-nonce transfer flows, but
  it still does not expose the broader Rust durable-nonce helper surface.
- The project now also has a real typed/raw JSON-RPC escape hatch above
  `sendRequest`, so new RPC coverage no longer requires hand-written param JSON.
- Constructor-level HTTP request timeouts now affect real network behavior in
  transport, rather than existing as name-only placeholders.
- `confirm_transaction_initial_timeout` now has concrete effect in the
  high-level send-and-confirm path, without changing the semantics of the
  lower-level confirm/poll helpers.
- High-level spinner flows now cover both send-and-confirm and blockhash-aware
  confirmation, including an explicit `BlockhashExpired` error when the
  signature is never observed before the recent blockhash becomes invalid.
- SDK convenience helpers now cover generic nonce-instruction prepending,
  generic legacy durable-nonce message/sign flows, and direct v0 compile+sign
  convenience for callers that do not want to wire those steps manually.
- SDK convenience helpers now also cover generic legacy message/signed-tx/base64
  builders and generic v0 message bytes/base64 builders, reducing the amount of
  struct assembly callers need to do by hand.
- Legacy builders now also have an owned-message path, so callers can clone,
  hold, and sign reusable legacy instruction sets later, similar to the owned
  v0 compile flow already in the SDK.
- Prefer preserving the current project direction: blocking HTTP RPC first,
  minimal SDK second, heavy transport features last.
