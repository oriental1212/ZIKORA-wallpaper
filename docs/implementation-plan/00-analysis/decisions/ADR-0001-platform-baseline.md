# ADR-0001 — Platform baseline

- Status: accepted
- Date: 2026-08-18
- Related: DEC-001, P00-01

## Evidence

- Xcode: 26.6 (build 17F113).
- SDK: macOS 26.5.
- Original project deployment target before this decision: macOS 26.5 in Debug and Release.
- Production language mode: Swift 5 with approachable concurrency and MainActor default isolation.
- `MenuBarExtra` and `SMAppService.mainApp` are available from macOS 13.
- SwiftData is available from macOS 14.
- The current Debug app target builds successfully from the command line with signing disabled.

The SDK version and deployment target are independent. Keeping the current deployment target means users on macOS 26.4 and earlier cannot install the app.

## Decision

The minimum supported release is macOS 14.0 for Debug, Release, and tests. This keeps SwiftData, `MenuBarExtra`, and `SMAppService` available without compatibility persistence or lifecycle fallbacks.

The project continues to compile in Swift 5 language mode against the installed SDK. API availability must be assessed against macOS 14 rather than the SDK version.

The user accepted this baseline on 2026-08-18. Debug and Release now both set `MACOSX_DEPLOYMENT_TARGET = 14.0`; bundle identifier and signing configuration are unchanged.
