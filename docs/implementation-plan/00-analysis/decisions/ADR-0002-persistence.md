# ADR-0002 — Persistence boundary and candidate store

- Status: accepted
- Date: 2026-08-18
- Related: DEC-003, P00-02

## Decision

Use repository protocols as the stable application boundary and SwiftData as the production store. ADR-0001 selected macOS 14, so no Core Data compatibility implementation is required.

## Probe result

The isolated `Spikes/P00` executable successfully verified that a minimal SwiftData store can:

- save source, wallpaper, and daily retry records;
- close and reopen while preserving retry state;
- delete a source without deleting wallpaper history;
- preserve the downloaded source-name snapshot.

## Constraints discovered

- `contentHash` and task keys can use unique attributes.
- The “only one current wallpaper” rule is a cross-row invariant and must be enforced in a repository transaction after the system wallpaper operation succeeds; it must not be assumed from a per-field schema attribute.
- Source references are stored as optional IDs/snapshots rather than cascade relationships, matching the requirement that history survives source deletion.
- A versioned schema and reopen/migration tests remain mandatory in P02.

## Rollback

Because Domain/Application code depends on repositories rather than SwiftData types, changing the store implementation does not change feature contracts.
