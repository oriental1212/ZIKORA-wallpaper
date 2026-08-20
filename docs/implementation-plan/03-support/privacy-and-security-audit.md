# P10-06 Privacy and Security Audit

Date: 2026-08-20

## Entitlement surface

Audited `project.pbxproj` for Debug and Release:

- `ENABLE_APP_SANDBOX = YES`: kept.
- `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES`: kept as the only network capability needed to reach user-configured image URLs.
- `ENABLE_USER_SELECTED_FILES = readonly`: removed. No production code uses `NSOpenPanel`, `fileImporter`, or user-selected file access.
- `REGISTER_APP_GROUPS = YES`: removed. No App Group identifier or shared container is used.
- No camera, microphone, location, contacts, photos, Bluetooth, accessibility, screen recording, incoming network, or personal-use entitlements are configured.

## Data flow

- User enters an HTTP/HTTPS image URL. No account, analytics SDK, cloud sync, or upload path exists.
- Download uses an ephemeral `URLSession` with cookies and cache disabled, streams to a temporary file, enforces a 50 MB limit, validates MIME/magic bytes/dimensions, then atomically commits into the managed Application Support container.
- Source URLs are persisted because they are the product configuration. Query strings remain supported but are redacted in logs and card display through `URLRedactor`.
- Logging records category, event, error code, and `redactedURL` only. It never logs image bytes, query values, passwords, or tokens.

## Filesystem containment

- All deletion paths go through `AtomicWallpaperFileStore.remove(relativePath:)`.
- `ManagedRelativePath` rejects absolute paths, traversal components, backslashes, and NUL bytes.
- `remove` re-resolves symlinks and requires the standardized path to remain under the managed root.
- Tests cover traversal rejection, symlink escapes, current-wallpaper protection, orphan-file preservation, and directory/read-only failures.

## Secrets

- Repository scan found no production API keys, passwords, private keys, bearer tokens, signing identities, or personal absolute paths.
- Fixture tests use fake URLs and fake secret values only for redaction/validation assertions.

## Remaining release steps

- Signed-sandbox entitlement verification and notarization must be run in the release environment with the real development identity; `CODE_SIGNING_ALLOWED=NO` builds cannot prove final entitlement provisioning.
- AppIcon/Logo master assets remain an open asset task per DEC-011.
