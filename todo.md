# solana-client-zig TODO

Snapshot: 2026-03-06
Current commit: `926a42d`

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

## Comparison Summary

### Module-Level Parity

| Rust module | Status in Zig | Notes |
| --- | --- | --- |
| `rpc_client` | Mostly implemented | Core blocking RPC surface is largely present and now split across `src/client/rpc_client/*.zig`. |
| `rpc_config` / `rpc_filter` / `rpc_request` / `rpc_response` / `rpc_custom_error` | Partially implemented | Zig has many equivalent structs/options, but not a full Rust-style public module layout. |
| `blockhash_query` | Not implemented | No durable-nonce-oriented blockhash query helper layer yet. |
| `nonce_utils` | Not implemented | Durable nonce helpers are still missing. |
| `pubsub_client` | Not implemented | No websocket subscription client. |
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
| Constructor semantic parity | Partial | Default commitment constructor args now persist and are used; request timeout semantics are still not wired into transport. |
| Typed legacy transaction/message API | Implemented | Legacy typed SDK, signing, serialization, and typed send/simulate/fee wrappers now exist. |
| Versioned transaction / v0 / ALT support | Partial | Minimal `VersionedMessageV0` / `VersionedTransaction` support exists, but high-level v0 compilation/builder ergonomics are still incomplete. |
| Public raw RPC escape hatch | Partial | Public `sendRequest(method, params_json)` exists, but there is still no Rust-style `RpcRequest` + typed generic `send<T>`. |
| Spinner variants | Missing | Rust `*_with_spinner*` variants are not present. |
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
- timeout arguments still do not affect HTTP request behavior

So this remains a real parity gap, but only for timeout-related behavior now.

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

- higher-level v0 compilation from `Instruction` + account metas + ALT references
- broader transaction-construction ergonomics beyond the current minimal SDK surface
- nonce-aware builders / helpers

So the project has crossed the line into "minimal client SDK", but still does
not yet match Rust's typed convenience end-to-end.

### 3. High-Level Transaction Builders Are Still Thin

The project can now build and sign legacy and minimal v0 transactions through
typed SDK structs, and it still has direct SOL transfer helpers.

What it does not yet have is a high-level builder layer comparable to Rust's
more ergonomic typed construction flow, especially for:

- v0 compiled instruction assembly
- address lookup table driven message compilation
- nonce-aware message building

### 4. Raw RPC Escape Hatch Exists, But Only at the Lowest Level

`sendRequest(method, params_json)` is now public, which helps with fast-following
new RPC methods.

Still missing is a public equivalent of Rust's generic `send<T>(RpcRequest, params)`
style API with:

- typed request identifiers
- typed result decoding
- less manual JSON parameter construction at call sites

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
- [ ] Add a higher-level v0 builder that compiles from instruction/account meta input.
- [ ] Add ergonomic ALT-driven message compilation helpers.

Why this phase is second:

- It covers the biggest real-world SDK gap after legacy transaction building.
- It avoids prematurely implementing all of Agave's transport stack.

### Phase 3: Fix Core Client Semantics

- [x] Make constructor commitment arguments actually persist as client defaults.
- [ ] Make constructor timeout arguments actually affect request behavior.
- [ ] Decide whether to add explicit `confirm_transaction_initial_timeout`
  semantics similar to Rust.
- [x] Expose a low-level public raw RPC hook via `sendRequest(method, params_json)`.
- [ ] Add a more Rust-like typed/raw RPC layer, for example:
  - [ ] `sendRaw`
  - [ ] or `sendJsonRpc`
  - [ ] or `sendTyped(request, params, ResultType)`
- [ ] Add minimal nonce/blockhash query helpers once typed message support exists.

Why this phase is third:

- It tightens parity with Rust `rpc-client`.
- It improves maintainability and extensibility after the typed SDK exists.

## Explicitly Deferred Work

These items are valid Agave features, but they should not be the next thing:

- [ ] `pubsub_client`
- [ ] `nonblocking` async client
- [ ] `connection_cache`
- [ ] `tpu_client`
- [ ] `transaction_executor`
- [ ] `send_and_confirm_transactions_in_parallel`
- [ ] Rust-style spinner helpers
- [ ] Rust-style mock sender surface

Reason for defer:

- These are expensive, multi-module features.
- They are not required to make the Zig client materially more useful right now.
- They become easier to evaluate after the minimal typed SDK exists.

## Recommended Immediate Order

If work resumes from here, the best sequence is:

1. Add durable nonce / blockhash query helpers.
2. Add a higher-level v0 / ALT message builder from instruction input.
3. Add a more typed raw RPC escape hatch above `sendRequest`.
4. Reassess real transport timeout support in the current Zig HTTP stack.
5. Only then decide whether pubsub / async is worth starting before TPU/QUIC.

## Notes

- Do not chase Agave's full transport stack before the SDK layer exists.
- Do not treat `_with_timeout` naming alone as parity; actual transport behavior
  still matters.
- The project now has a real minimal SDK and a cleaner test layout under `tests/`.
- Prefer preserving the current project direction: blocking HTTP RPC first,
  minimal SDK second, heavy transport features last.
