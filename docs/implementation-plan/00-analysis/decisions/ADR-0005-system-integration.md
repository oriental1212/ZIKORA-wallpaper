# ADR-0005 — macOS system integration baseline

- Status: accepted baseline; signed/manual behavior scheduled for P06
- Date: 2026-08-18
- Related: DEC-005, DEC-006, DEC-007, P00-05

## Decision

- Desktop wallpaper: AppKit `NSWorkspace.setDesktopImageURL(_:for:options:)`, called for every current `NSScreen` and returning per-screen results.
- Menu Bar: SwiftUI `MenuBarExtra` first; bridge to AppKit only if window activation/status behavior cannot meet requirements.
- Login launch: `SMAppService.mainApp`; reflect `notRegistered`, `enabled`, `requiresApproval`, and `notFound` without pretending registration succeeded.
- Sleep/wake: `NSWorkspace.willSleepNotification` and `didWakeNotification`.
- Clock/time-zone: system clock and time-zone change notifications, converted into a serialized domain event stream.
- Shutdown: cancel owned tasks, preserve retry state and atomically committed data, and clean temporary files; never wait without a bound.

## Probe result

The isolated executable compiled and read these APIs without mutating system state. On the current machine it observed two screens and a login item status of `notFound`, expected for an unsigned standalone probe rather than the application bundle.

## Manual signed checks owned by P06

1. Set one image on one and multiple displays.
2. Capture partial-display failure behavior and Space behavior.
3. Close/hide/reopen the main window from Dock and Menu Bar.
4. Register, require approval, unregister, and externally change the login item.
5. Sleep/wake on the same day and across a day boundary.
6. Confirm quit cancels retry/rotation tasks without corrupting an in-progress temporary download.

The user confirmed that P00 should not mutate wallpaper or login-item state. These checks remain explicit P06 acceptance work and do not block the architecture baseline.
