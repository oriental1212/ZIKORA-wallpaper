# Command-line feedback loop

Run these commands from any directory. They require Xcode but do not require a
GUI, Apple ID, signing identity, personal Keychain entry, or public network.

```bash
./scripts/test
./scripts/build
./scripts/check
```

- `test` runs the complete Swift Testing target in Debug with signing disabled.
- `build` builds Debug by default. Set `ZIKORA_CONFIGURATION=Release` when needed.
- `check` runs the complete test suite and then a Release build.
- All commands write DerivedData to `${TMPDIR:-/tmp}/zikora-wallpaper-derived`.
  Override it with `ZIKORA_DERIVED_DATA=/another/writable/path`.

## Focused tests

Pass normal `xcodebuild` arguments through the script:

```bash
./scripts/test -only-testing:ZIKORA-wallpaperTests/DiagnosticsTests
```

## Restricted-environment diagnostics

If a build reports a Swift macro or Preview plugin connection failure, keep
application code unchanged and retry with a writable DerivedData location:

```bash
ZIKORA_DERIVED_DATA=/tmp/zikora-wallpaper-derived ./scripts/test
```

Preview rendering is a development convenience, not a substitute for the CLI
build/test result. Signed sandbox checks for wallpaper and login-item behavior
remain in P06 because `CODE_SIGNING_ALLOWED=NO` cannot validate them.
