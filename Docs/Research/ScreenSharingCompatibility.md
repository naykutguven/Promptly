# Screen-sharing compatibility research

**Status:** No tests recorded.

This document holds technical capture-visibility results for [PRD-06](../PRD.md#prd-06--screen-sharing-privacy). Product requirements and disclosure policy remain in the PRD.

## Coverage

Test Zoom, Microsoft Teams, Google Meet, macOS screenshot and screen-recording tools, and a named ScreenCaptureKit-based application.

Cover entire-display and individual-window capture where supported. Record exact application and macOS versions, display configuration, and the prompter's placement for each test.

## Compatibility matrix

Add one row per completed test and capture configuration. Visibility values are **Visible**, **Not visible**, or **Unknown**; untested combinations remain Unknown.

| Application / tool | Version | macOS version | Capture mode | Display configuration | Promptly visibility | Limitations / procedure / evidence |
|---|---|---|---|---|---|---|
| No tests recorded | — | — | — | — | Unknown | — |

## Reproduction record

For each test:

1. Record the application and macOS versions, capture mode, display configuration, and prompter size and placement.
2. Load synthetic text and confirm the prompter is visible locally on the display being tested.
3. Start capture and inspect the actual shared or recorded output.
4. Record observed visibility, exact reproduction steps, limitations, and synthetic evidence when available.
5. Record changed modes, displays, or versions as separate tests.

A result applies only to the configuration tested. Do not treat an untested combination as protected.
