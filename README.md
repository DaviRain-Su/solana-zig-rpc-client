# solana-zig-rpc-client

Blocking Solana RPC, pubsub, and CLI tooling in Zig.

This repository is moving toward a single core goal: make both the library and the CLI capable of calling arbitrary Solana on-chain programs, not only fixed built-in RPC workflows.

## Status

The codebase already supports three generic invocation families:

- `instructions`
  - invoke from an arbitrary instruction set
- `program-invoke`
  - invoke from `program_id + accounts + raw data`
- `anchor-idl-invoke`
  - invoke from Anchor IDL + instruction name + args + account bindings

These families now share a reusable end-to-end stack for:

- instruction construction
- account meta and signer handling
- message and transaction building
- simulation
- sending
- send-and-confirm
- fee estimation
- planning, validation, and preferred legacy/versioned mode selection

## Build and test

```bash
zig build
zig build test
```

Useful local commands:

```bash
zig test src/root.zig
zig build run -- --help
```

## Repository layout

- `src/root.zig`
  - public export surface
- `src/client/rpc_client/`
  - blocking JSON-RPC client modules
- `src/client/pubsub/`
  - websocket pubsub client
- `src/client/instructions_invoke.zig`
  - generic invocation from arbitrary instruction sets
- `src/client/program_invoke.zig`
  - generic invocation from `program_id/accounts/data`
- `src/client/anchor_idl/invoke.zig`
  - generic invocation from Anchor IDL
- `src/client/invoke.zig`
  - family-agnostic dispatch, planning, validation, preferred-mode helpers
- `src/cli.zig`
  - CLI parsing
- `src/commands.zig`
  - CLI command execution
- `tests/root/`
  - root and integration-style coverage

## Generic invocation architecture

The repository now has a layered generic invocation model.

### 1. Family-specific builders

Use one of these when you already know your input shape:

- `client.instructions_invoke`
- `client.program_invoke`
- `client.anchor_idl_invoke`

Each family supports reusable helpers for:

- instruction construction
- owned legacy/versioned message building
- message bytes/base64
- signed legacy/versioned transaction building
- transaction base64
- latest blockhash and `BlockhashQuery` flows
- simulate / send / send-and-confirm
- spinner-based confirm helpers
- fee estimation

### 2. Canonical invocation-spec normalization

`client.invoke` sits above the family-specific builders.

It accepts one of the three invocation families and normalizes them into a common invocation shape so higher-level code does not need to care whether the source came from:

- raw instructions JSON
- `program_id + accounts + data`
- Anchor IDL

### 3. Family-agnostic execution

`client.invoke` provides generic dispatch for:

- build message / transaction
- send
- simulate
- send-and-confirm
- fee estimation

This is the reusable library surface the CLI is being moved onto.

## Preferred legacy/versioned mode support

`client.invoke` now exposes a preferred-mode layer over generic invocation specs.

It can:

- inspect whether legacy and versioned transactions are buildable
- choose a preferred mode automatically
- honor an explicit requested mode
- optionally fall back if the requested mode is not buildable

Current preference rule is intentionally simple:

- if address lookup tables are present and versioned is buildable, prefer `versioned`
- otherwise prefer `legacy`

Relevant public surfaces in `client.invoke` include:

- mode reports
- preferred build helpers
- preferred send/simulate/confirm helpers
- preferred fee helpers
- result wrappers that return both:
  - the selected mode
  - the built or executed result
- execution reports that retain:
  - requested mode
  - selected mode
  - whether fallback happened
  - whether the selected mode is executable

## Planning, validation, and introspection

Beyond build/send helpers, `client.invoke` now provides reusable pre-execution analysis:

- normalized invocation specs
- resolved invocations
- account role introspection
- signer extraction
- invocation summaries
- invocation plans
- preflight reports
- validation reports
- lookup table coverage reports
- unified invocation reports
- preferred invocation reports
- preferred invocation analysis
- preferred prepared signed transactions

This is intended to let higher-level code answer questions such as:

- which accounts are writable or signers
- which program IDs are touched
- whether required signers are missing
- whether duplicate signers or duplicate lookup tables exist
- whether lookup tables fully cover candidate addresses
- whether the invocation should run as legacy or versioned
- whether a durable nonce flow is in use

## CLI direction

The CLI still includes many fixed RPC-style commands, but current development priority is the generic invoke path.

High-priority command families are:

- `send/simulate-*instructions`
- `send/simulate-*program-invoke`
- `send/simulate-*idl-invoke`

These paths are being progressively consolidated onto the reusable client surfaces above instead of maintaining separate command-specific transaction assembly logic.

## Current development priority

When adding new work, prefer changes that improve one of these:

- generic instruction construction from CLI inputs
- account meta and signer handling
- transaction build / simulate / send / confirm for arbitrary programs
- reusable RPC/client surfaces that support contract invocation end to end

That direction is intentional. Narrow one-off command coverage is lower priority than improving the shared generic invocation path.
