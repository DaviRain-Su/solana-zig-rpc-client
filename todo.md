# solana-client-zig TODO

Snapshot: 2026-03-06
Current commit: `c244e36`

## Purpose

This file tracks feature parity work against Agave's Rust client stack and
turns the comparison into an implementation backlog for this Zig project.

Primary upstream references:

- `agave/client`: <https://github.com/anza-xyz/agave/tree/master/client>
- `agave/rpc-client`: <https://github.com/anza-xyz/agave/tree/master/rpc-client>
- `rpc-client/src/rpc_client.rs`: <https://github.com/anza-xyz/agave/blob/master/rpc-client/src/rpc_client.rs>
- `client/src/lib.rs`: <https://github.com/anza-xyz/agave/blob/master/client/src/lib.rs>

Local code anchors:

- Core RPC client: [src/root.zig](./src/root.zig)
- CLI parsing: [src/cli.zig](./src/cli.zig)
- CLI command execution: [src/commands.zig](./src/commands.zig)

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
| `rpc_client` | Mostly implemented | Core blocking RPC surface is largely present in `src/root.zig`. |
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
| Constructor semantic parity | Partial | Timeout / commitment constructor arguments still mostly act as placeholders. |
| Typed transaction/message API | Missing | Rust accepts typed transaction/message values; Zig currently works with encoded payloads plus a limited transfer builder. |
| Versioned transaction / v0 / ALT support | Missing | No minimal SDK layer yet. |
| Public raw RPC escape hatch | Missing | Internal `sendRequest` exists, but there is no public generic/raw request API. |
| Spinner variants | Missing | Rust `*_with_spinner*` variants are not present. |
| Mock constructors | Missing | No `new_mock*` or similar public test helpers. |
| Async runtime / inner client accessors | Missing | No `commitment()`, `get_inner_client()`, or `runtime()` equivalent. |

## Known Gaps Worth Tracking Explicitly

### 1. Constructor Names Exist, But Semantics Are Incomplete

These APIs exist in Zig:

- `newWithCommitment`
- `newWithTimeout`
- `newWithTimeoutAndCommitment`
- `newWithTimeoutsAndCommitment`

But today they mostly discard the extra arguments and fall through to `init`.
This is a real parity gap, not just naming drift.

### 2. Typed Transaction Support Is Still Missing

Rust `rpc-client` works with typed:

- `Transaction`
- `VersionedTransaction`
- legacy messages
- `v0::Message`

Current Zig client mostly expects:

- base64 signed transaction strings
- base64 encoded messages
- one special-case local builder for legacy SOL transfer

That is the main reason the current Zig client still feels more like an RPC
wrapper than a true client SDK.

### 3. Only Legacy Transfer Building Exists

The project can locally construct a legacy SOL transfer transaction, but not
general instructions/messages/transactions. There is no minimal SDK layer yet
for building arbitrary transactions.

### 4. No Public Raw RPC Escape Hatch

`sendRequest` is internal. There is no public equivalent of Rust's generic
`send<T>(RpcRequest, params)` style API for fast-following newly added RPCs.

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

- [ ] Introduce a minimal legacy typed SDK layer.
- [ ] Add `Pubkey`, `Hash`, `Signature`, `Keypair`, `AccountMeta`, `Instruction`,
  `Message`, and `Transaction`.
- [ ] Promote the current legacy SOL transfer builder into a general legacy
  message/transaction builder.
- [ ] Add typed convenience APIs on top of existing encoded RPC paths:
  - [ ] `sendTransactionTyped`
  - [ ] `simulateTransactionTyped`
  - [ ] `getFeeForMessageTyped`
  - [ ] `sendAndConfirmTransactionTyped`
- [ ] Keep the first cut focused on blocking, legacy transactions only.

Why this phase is first:

- It changes the project from "RPC caller" into "client that can build and sign".
- It unlocks most of the remaining parity work without jumping into TPU/async.
- It builds directly on the transfer work already done.

### Phase 2: Minimal v0 / ALT Support

- [ ] Add `VersionedMessageV0`.
- [ ] Add `VersionedTransaction`.
- [ ] Add minimal address lookup table reference structures.
- [ ] Extend typed send/simulate/fee helpers to support versioned transactions.
- [ ] Keep scope tight: enough to build, sign, serialize, and submit v0 txs.

Why this phase is second:

- It covers the biggest real-world SDK gap after legacy transaction building.
- It avoids prematurely implementing all of Agave's transport stack.

### Phase 3: Fix Core Client Semantics

- [ ] Make constructor commitment arguments actually persist as client defaults.
- [ ] Make constructor timeout arguments actually affect request behavior.
- [ ] Decide whether to add explicit `confirm_transaction_initial_timeout`
  semantics similar to Rust.
- [ ] Add a public raw RPC escape hatch, for example:
  - [ ] `sendRaw`
  - [ ] or `sendJsonRpc`
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

1. Build the legacy typed SDK.
2. Add typed send/simulate/fee/send-and-confirm wrappers.
3. Add minimal v0/versioned transaction support.
4. Make client constructor semantics real.
5. Add a public raw RPC escape hatch.
6. Reassess whether nonce helpers should come before or after broader SDK polish.

## Notes

- Do not chase Agave's full transport stack before the SDK layer exists.
- Do not treat `_with_commitment` naming alone as parity; constructor behavior
  matters.
- Prefer preserving the current project direction: blocking HTTP RPC first,
  minimal SDK second, heavy transport features last.
