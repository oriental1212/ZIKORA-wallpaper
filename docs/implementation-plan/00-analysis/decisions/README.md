# P00 decision records

| Record | Status | Decision |
|---|---|---|
| [ADR-0001](ADR-0001-platform-baseline.md) | accepted | macOS 14 minimum |
| [ADR-0002](ADR-0002-persistence.md) | accepted | SwiftData behind repository boundaries |
| [ADR-0003](ADR-0003-native-design-system.md) | accepted implementation baseline | Native macOS structure with restrained Vivid Lumina semantics |
| [ADR-0004](ADR-0004-network-and-image-validation.md) | accepted; P04 verification pending | URLSession + ImageIO with streaming cap and outgoing client only |
| [ADR-0005](ADR-0005-system-integration.md) | accepted; P06 manual checks pending | AppKit + MenuBarExtra + SMAppService + system notifications |

Records are append-only. A superseding decision should add a new ADR and mark the previous record `superseded`.
