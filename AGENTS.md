# Repository Guidelines

## Project Goal & Contributor Priority

The long-term product goal is to make this CLI capable of calling any Solana on-chain program, not only fixed built-in RPC workflows. When choosing between equivalent tasks, prefer work that moves the repository toward:

- generic instruction construction from CLI inputs
- account meta and signer handling
- transaction building, simulation, sending, and confirmation for arbitrary programs
- reusable RPC/client surfaces that can support contract invocation end to end

Feature work that improves generic program interaction should take priority over narrow one-off command coverage.

## Project Structure & Module Organization

- `src/root.zig`: public entry point and main export surface.
- `src/client/rpc_client/`: blocking JSON-RPC client modules such as `accounts.zig`, `assets.zig`, and `network.zig`.
- `src/client/nonblocking/`: async wrappers around the blocking client.
- `src/client/pubsub/`: websocket pubsub client and typed subscription helpers.
- `src/cli.zig` and `src/commands.zig`: CLI parsing and command execution.
- `tests/root/`: integration-style root tests.
- `tests/support/`: mock servers, mock senders, and shared assertions.
- `vendor/`: vendored dependencies. Avoid editing unless updating a dependency snapshot.

## Build, Test, and Development Commands

- `zig build`: build the project and configured artifacts.
- `zig build test`: run the full test suite; use this before every commit or PR.
- `zig test src/root.zig`: quick check for the exported API surface.
- `zig build run -- --help`: run the CLI locally and inspect available commands.

When iterating on one subsystem, use targeted tests locally, but always finish with `zig build test`.

## Coding Style & Naming Conventions

- Follow standard Zig formatting; run `zig fmt` on changed files before submitting.
- Use `PascalCase` for types, `lowerCamelCase` for functions and methods, and lowercase module/file names.
- Keep modules focused by feature area. New blocking RPC methods usually belong in `src/client/rpc_client/*.zig`, then get exported through `src/root.zig`.
- Be explicit about ownership. If code allocates strings or slices, add matching free helpers in tests.

## Testing Guidelines

- Tests use Zig’s built-in `std.testing`.
- Add new behavior coverage under `tests/root/*.zig`; place reusable mocks or assertion helpers in `tests/support/`.
- Use descriptive test names such as `test "root.NonblockingRpcClient getAccountInfoAsync sends requested account"`.
- For RPC work, prefer mocked HTTP/websocket responses and assert both parsed values and request payload fragments.

## Commit & Pull Request Guidelines

- Match existing commit history: `area: imperative summary`.
  - Examples: `nonblocking: add async multiple account queries`, `pubsub: add queue helpers`
- Keep each commit scoped to one subsystem or API family.
- PRs should include:
  - what changed and why
  - affected modules
  - commands run, especially `zig build test`
  - any CLI behavior changes or ownership/async semantics worth reviewing closely

## Security & Configuration Tips

- Never commit real private keys, RPC credentials, or production validator URLs.
- Prefer local mocks and test senders for write-path features and contract interaction coverage.
