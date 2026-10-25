# Concurrency and Playback

Read for tasks, actors, isolation, callbacks, scrolling/playback, inference, or
future speech work. Follow [AGENTS.md](../../AGENTS.md); also read
[Data and Privacy](DataAndPrivacy.md) for persistence or source revisions and
[Testing and Validation](TestingAndValidation.md) before verification.

## Ownership and isolation

- Preserve the compiler/concurrency baseline in AGENTS.md. Approachable Concurrency
  already enables `InferIsolatedConformances` and `NonisolatedNonsendingByDefault`;
  resolve diagnostics through explicit ownership rather than weakening these settings.
- Keep SwiftUI presentation, AppKit windows, focus, and display interactions on
  `MainActor`. Give each mutable service one owner, normally an actor or
  `@ModelActor`; views and callbacks do not compete with that owner.
- Neither `async` nor `Task {}` guarantees work leaves `MainActor`. With the current
  settings, plain `nonisolated async` functions run on the caller's actor. Use a
  worker actor or a narrowly scoped `@concurrent` function with `Sendable` inputs
  and results for CPU-heavy work that must leave the UI actor.
- Pass stable IDs or immutable `Sendable` snapshots across actors, never live
  SwiftData models or `ModelContext`. Refetch in the owning context.
- Actors serialize state; they do not make blocking calls nonblocking. Isolate
  unavoidable blocking work behind a narrow adapter and keep UI work responsive.
- Avoid detached tasks and unchecked isolation escapes. Any necessary exception
  documents ownership, synchronization, cancellation, and safe captures.

## Task lifecycle

- Prefer structured concurrency and view-lifetime tasks. Long-lived tasks have
  an explicit owner, cancellation path, and deterministic teardown.
- Use focused enums for legal playback, loading, and generation transitions.
  Treat cancellation, failure, retry, and replacement intentionally.
- Give asynchronous operations an identity and source revision. After relevant
  suspension points, reject cancelled, deleted, replaced, or stale work before
  mutation. Cancellation alone does not roll back committed data.
- Bound task counts, queues, buffers, and retries. Streams need an explicit
  buffering policy and termination cleanup; continuations resume exactly once,
  including callback/cancellation races.
- Remove observers and callbacks symmetrically. Repeated activation must not
  install duplicate handlers or leave tasks running after their owner closes.

## Scrolling and reading position

- Playback means teleprompter scrolling. Keep one source of truth for the active
  script, play/pause state, speed, and logical reading anchor.
- Derive movement from elapsed time rather than assuming a fixed timer or frame
  rate. Pause/resume and window lifecycle changes must not cause position jumps.
- Anchor position to script content rather than only pixel offsets. Reconcile
  anchors after edits, reflow, font/spacing changes, resizing, and display changes;
  define a safe fallback when the anchored content is removed.
- Keep per-frame work small. Do not run persistence, inference, whole-script
  layout, or unrelated view invalidation on every scroll update.
- Persist meaningful checkpoints, not every frame. Stop display updates and
  timers when idle; closing a playback window tears down its work.

## Optional inference and future voice-following

- Section suggestions use bounded snapshots and must not block editing or
  scrolling. Accept results only against the script revision they analyzed.
- Voice-following is future scope. If requested, give capture, recognition, and
  matching clear owners, explicit start/stop intent, and bounded buffers.
- Define behavior for silence, repeated phrases, recognition gaps, permission
  denial, asset unavailability, device changes, and interruption. Preserve a
  useful manual playback fallback.
- Verify macOS API availability and callback contracts; do not import iOS
  `AVAudioSession` or background-recording assumptions. True real-time callbacks
  must not allocate, lock, create tasks, log, or access persistence; use a bounded
  real-time-safe handoff when required.

Test transitions, reentrancy, stale results, cancellation, teardown, repeated
commands, reflow anchors, and bounded work. Run targeted Thread Sanitizer checks
for relevant concurrency changes; sanitizer results do not prove thread safety.
