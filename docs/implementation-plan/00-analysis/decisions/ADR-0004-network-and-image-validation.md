# ADR-0004 — Network and image-validation pipeline

- Status: accepted; production fixture validation remains in P04
- Date: 2026-08-18
- Related: DEC-004, DEC-009, DEC-010, P00-04

## Current evidence

- Production App Sandbox is enabled.
- The user approved the minimum outgoing client capability on 2026-08-18. Debug and Release set `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES`; App Sandbox remains enabled and no broader network capability was added.
- The isolated probe passed ImageIO PNG decoding, MIME rejection, streaming size accounting, and URLSession delegate cancellation when a byte cap is crossed.
- The installed SDK exposes JPG/JPEG, PNG, HEIC, and WebP decoding identifiers. `sips --formats` reports WebP read support and HEIC/JPEG/PNG read/write support.

## Decision

- Enable only the App Sandbox outgoing client entitlement.
- Use an ephemeral or explicitly configured URLSession with a 15-second request timeout and a maximum of five redirects.
- Receive to a temporary file/stream and enforce the 50 MB limit while bytes arrive, including overflow-safe accounting.
- Require successful HTTP status, an image MIME declaration, a supported decoded type, valid nonzero dimensions, and ImageIO decoding before commit.
- Preserve the original supported file format after validation.
- Allow query parameters because signed/parameterized image URLs are common, but redact query values from user errors and logs. No separate credentials are persisted in V1.0.

## Checks owned by P04

- Signed App Sandbox request with only outgoing client entitlement.
- Redirect limit and timeout against a local deterministic fixture server.
- Real HEIC and WebP decode fixtures, including corrupt payloads.
- Download interruption, no `Content-Length`, and disk-full behavior in the production file pipeline.

The project setting that generates the outgoing network client entitlement changed with explicit user approval. Bundle identifier, signing, incoming network access, and file-access capabilities were not broadened.
