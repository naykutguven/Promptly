# MCP Swift SDK evaluation

Evaluated on **2026-10-31** against upstream release **0.12.1**, published
2026-05-07 and reported as the latest release by GitHub on the evaluation date.
This is a source and manifest evaluation, not an integration or compatibility
test. Current MVP requirements are defined in [PRD-07](../PRD.md#prd-07--mcp-integration).
No dependency, helper target, entitlement, or runtime behavior is added.
[Release evidence](https://github.com/modelcontextprotocol/swift-sdk/releases/tag/0.12.1).

**Recommendation:** Keep the official Swift SDK as the preferred candidate for
Promptly's future stdio helper. Defer adoption until the intended clients'
protocol compatibility, bounded input handling, lifecycle, and signed sandboxed
IPC have been validated. It supplies useful protocol machinery; Promptly must
own authorization, script scope, edit safety, and playback policy.

## Fit and constraints

| Area | Finding and implication |
| --- | --- |
| Native package | The `MCP` library declares macOS 13.0+, below Promptly's macOS 26.0 minimum. Its main manifest requires Swift tools 6.1; a Swift 6.0 manifest also exists. The main manifest parsed with the installed Swift 6.4.2 toolchain. This establishes manifest compatibility only. Preserve Promptly's Swift 6 language mode and concurrency settings. [Manifests](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Package.swift), [6.0 variant](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Package@swift-6.0.swift). |
| Server role | `Server` is an actor with typed asynchronous method handlers. Tools and resources can represent script operations and snapshots. Promptly needs the server role in a helper; it does not need to become an MCP client or request model sampling. [Server implementation](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Server.swift). |
| Local transport | `StdioTransport` uses file descriptors and newline framing. It fits the README's client-launched helper without an HTTP listener. XPC and Unix domain socket bridging to the app are application work, not supplied by this transport. Network transports are unnecessary for the proposed path. [Stdio implementation](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/StdioTransport.swift). |
| Dependency footprint | The `MCP` target depends on Swift System, Swift Log, and EventSource on macOS. The main manifest also declares SwiftNIO for its conformance server and a DocC plugin on `main`; these are not `MCP` target dependencies. Evaluate the resolved graph and build cost rather than assuming a stdio-only package. Pin the selected SDK release and resolved revisions when integration is authorized. [Package manifest](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Package.swift). |
| Licensing | The tagged license records an Apache-2.0 transition with some existing contributions remaining MIT and documentation under CC-BY-4.0. Record the actual SDK and transitive license/notice files when packaging; do not describe this release simply as MIT. [Tagged license](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/LICENSE). |

### Protocol compatibility is an adoption gate

Release 0.12.1's supported version set ends at **2025-11-25**; it also lists
2025-06-18, 2025-03-26, and 2024-11-05. Its server uses an `initialize` handshake.
The checked default-branch version file lists the same versions, so switching
to `main` does not resolve the observed gap.
[Release version implementation](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Versioning.swift),
[default-branch version implementation](https://github.com/modelcontextprotocol/swift-sdk/blob/main/Sources/MCP/Base/Versioning.swift).

The current MCP revision is **2026-07-28**, which uses per-request version and
capability metadata and `server/discover`. Its compatibility rules allow clients
supporting both eras to probe a legacy stdio server and fall back to `initialize`.
A client supporting only the current era cannot be assumed to work with this
SDK. Test the actual intended clients and negotiated versions before choosing a
release; if current-era support is required, wait for or evaluate an upstream
implementation rather than claim compatibility from the shared transport name.
[Current version](https://modelcontextprotocol.io/docs/2026-07-28/learn/versioning),
[compatibility rules](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning),
[stdio fallback](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio#backward-compatibility).

## Current MVP integration direction — 2026-11-13

This section records the approved PRD-07 direction. It replaces the earlier
library-based assumptions about persistent stores, per-script grants, and
save-before-send workflows. The SDK source findings above remain dated
2026-10-31 evidence.

The preferred implementation candidate is a lightweight Swift stdio helper using
`MCP`, launched by the external client, forwarding typed requests through secured
local IPC to the running app. XPC and Unix domain sockets remain candidates.
The process layout, IPC mechanism, packaging, and peer-validation design must be
validated before selection; they are not fixed product requirements. The app
owns the active reading session and preferences, without a second state owner
in the helper. MCP documents the [client-launched stdio process](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio).

- MCP is disabled by default. Enabling it grants access to any local MCP client
  running under the same macOS user, without per-client approval for MVP.
- Script access includes the active prompter script and future replacements
  until MCP is disabled. Unfinished editor drafts remain private, and protected
  integration/security settings remain user-only. Explain this scope and possible
  remote processing by external clients when enabling MCP.
- Enforce the enabled state and same-user boundary in app-owned services. For a
  helper-based design, authenticate the helper/app peers. Peer checks do not
  automatically identify the MCP client that launched the helper; client-supplied
  names are not proof of identity. Apple's [XPC peer signing requirement](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement%28_%3A%29)
  is one mechanism to evaluate, not a validated IPC design.
- Preserve the PRD's latest-request-wins script loading, mandatory layout
  revisions for navigation, and validated atomic partial settings updates.
  Successful script loads reveal the prompter in Stopped state; they never
  start playback. Never overwrite unfinished editor drafts.
- Revalidate enablement, user boundary, operation identity, and relevant source
  or layout revision after suspension and at the final commit or disclosure
  point. Disabling MCP must prevent pending MCP work from committing or disclosing
  content. Cancellation cannot undo already committed work.
- Use immutable `Sendable` snapshots across IPC and keep AppKit/presentation on
  `MainActor`. Preserve the configured concurrency and import-visibility baseline.
- Provide local stdio integration without a network listener. Secured helper-to-app
  communication must work within the app's sandbox and packaging constraints.
- Initial client validation targets are [Codex](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
  and [Claude Desktop](https://modelcontextprotocol.io/docs/develop/connect-local-servers).
  Their documented local server support does not establish Promptly compatibility;
  test and record actual client versions and negotiated protocol behavior.
- Line retrieval starts at index 0, defaults to 100 lines, and accepts at most
  200 per request. Follow pagination with the first page's layout revision to
  retrieve the complete layout without mixing revisions.

The SDK models tool annotations as hints. Validate argument structure and bounds
in the application instead of relying on schema descriptions or client behavior.
[Tool types](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Tools.swift).

### Source findings that need mitigation or measurement

- **Input and energy:** The stdio implementation uses a default unbounded
  `AsyncThrowingStream` and accumulates bytes until a newline without an explicit
  frame-size limit. When input would block, it sleeps for 10 milliseconds and
  retries. A handler-level limit is too late to bound transport buffering.
  Require bounded framing/queues before decoding, and measure idle wakeups;
  consider a focused transport adapter or upstream fix if needed. These are
  source observations, not measured memory or energy results.
  [Stdio source](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transports/StdioTransport.swift),
  [custom transport contract](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Base/Transport.swift).
- **Request lifetime:** The server creates tasks for incoming requests without
  an exposed concurrency limit. Its `stop()` disconnects and clears outbound
  pending responses but does not explicitly cancel all incoming handler tasks.
  Bound admission before task fan-out and independently invalidate app-side
  operations on disconnect/revocation. Verify EOF, cancellation races, backpressure,
  and repeated start/stop rather than treating `stop()` as a transaction barrier.
  [Server source](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Server.swift).
- **Diagnostics:** The default stdio logger is a no-op, but enabling SDK logging
  can expose client-controlled request IDs, cancellation reasons, or error text.
  Retain no-op logging or use a deliberately filtered logger. Never log script
  text, titles, arguments, credentials, or arbitrary client strings, including to
  stderr. Keep stdout exclusively for MCP messages.
  [Server logging sites](https://github.com/modelcontextprotocol/swift-sdk/blob/0.12.1/Sources/MCP/Server/Server.swift),
  [stdio channel rules](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio).

## Validation and next decision

Completed: reviewed the release metadata, tagged manifests, protocol versions,
server/tool/transport source, license, and current protocol compatibility rules.
`xcrun swift --version` reported Apple Swift **6.4.2** on arm64. An isolated
`swift package dump-package` of both copied manifests selected the tools-6.1
main manifest and passed using temporary cache/configuration paths. This did not
resolve dependencies or compile SDK source. An initial attempt failed because
the compiler's default module cache was outside the writable sandbox; redirecting
that cache allowed manifest evaluation to succeed.

The successful command, with `mcpEvaluationRoot` pointing to the temporary
directory containing the two unmodified tagged manifests, was:

```sh
CLANG_MODULE_CACHE_PATH="$mcpEvaluationRoot/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$mcpEvaluationRoot/module-cache" \
xcrun swift package --package-path "$mcpEvaluationRoot" \
  --scratch-path "$mcpEvaluationRoot/build" \
  --cache-path "$mcpEvaluationRoot/cache" \
  --config-path "$mcpEvaluationRoot/configuration" \
  --security-path "$mcpEvaluationRoot/security" \
  --disable-sandbox dump-package
```

Documentation checks passed: `git diff --check`, plus a local Markdown link,
anchor, whitespace, and final-newline check covering all three changed documents,
including this new file (22 local links).

Before adoption, a separately scoped synthetic-content spike must establish:

1. Actual client versions, discovery/fallback behavior, and unsupported-version
   failures; recheck the latest SDK release and current protocol at that time.
2. Helper/SDK compilation with the intended Swift 6.4 settings and macOS 26.0
   deployment, plus affected app and test targets, without weakening checks.
3. Signed sandboxed IPC, same-user and enablement enforcement, install/discovery,
   app-not-running behavior, and disabling access with network access disabled.
   No entitlement or signing changes are approved by this evaluation.
4. Disabled and wrong-user calls, active-script replacement, editor-draft
   isolation, metadata leakage, pagination/revision boundaries, stale results,
   cancellation/disconnect before commit, and safe playback behavior.
5. Oversized/unterminated frames, request floods, slow consumers, EOF, teardown,
   repeated sessions, private diagnostics, idle CPU/energy, and offline behavior.

No SDK integration build, client interoperability, signed IPC, minimum-OS,
network-traffic, performance, or native enablement-UI validation has been run.
The current window prototype has no script/edit/playback services for the helper
to expose. Revisit adoption with those contracts available; retain this document
as the dated evaluation rather than a claim of implemented MCP support.
