# P00 isolated probes

These probes validate architecture assumptions before the production target is changed. They do not register a login item, set a desktop wallpaper, mutate entitlements, or access public network resources.

Run from the repository root:

```bash
swift run --package-path Spikes/P00 --scratch-path /tmp/zikora-p00-spikes P00Spikes
```

The executable checks:

- a minimal SwiftData schema can be saved, reopened, and keep wallpaper history after a source is deleted;
- PNG metadata can be decoded with ImageIO, while an invalid MIME type and an over-limit stream are rejected;
- URLSession can enforce a byte cap while receiving chunks from an isolated `URLProtocol` fixture;
- AppKit desktop wallpaper, SwiftUI Menu Bar, ServiceManagement login item, and relevant system-event APIs compile against the selected SDK;
- read-only status inspection does not perform any production mutation.

Passing this executable is not a substitute for the signed App Sandbox manual checks listed in P00-04 and P00-05.

