<!-- Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V4 -->

# ADR-0003 — Native macOS design-system baseline

- Status: accepted implementation baseline
- Date: 2026-08-18
- Related: DEC-002, P00-03
- Audience: macOS users who value a quiet, lightweight automation utility
- Primary job: configure reliable automatic wallpaper updates and understand current status
- Tone: restrained, soft, utilitarian

## Decision

Use native macOS window, navigation, controls, focus, keyboard, accessibility, and system-material behavior. Apply Vivid Lumina as a restrained semantic skin, while preserving the root `DESIGN.md` principles that content—especially wallpaper imagery—must remain the visual focus.

The prototype HTML is structural reference material, not production component code.

## Semantic token contract

| Role | SwiftUI direction | Rule |
|---|---|---|
| `background` | dynamic window background | No full-window decorative gradient |
| `surface` | system control/background material | Default content surface |
| `elevatedSurface` | restrained secondary/system material | Sheets, popovers, selected regions |
| `sidebarMaterial` | native sidebar material | Glass-like treatment is limited to structural chrome |
| `primaryAction` | system accent with Electric Blue brand intent | Single main interactive hue |
| `critical` | system red | Destructive/error only |
| `warning` | system orange/yellow semantic color | Never used as decoration |
| `success` | system green semantic color | Status plus text/icon, never color alone |
| `primaryText` | `.primary` | Dynamic light/dark contrast |
| `secondaryText` | `.secondary` | Metadata and descriptions |
| `separator` | system separator | Prefer hairline/surface change over shadow |
| `focus` | native focus effect | Immediate, visible, not custom-delayed |

Typography uses the macOS system font and semantic text styles. No Plus Jakarta Sans or Inter dependency is added. Spacing follows a 4-point base with structural values at 8/12/16/24/32. Card radii remain restrained; pill shapes are reserved for primary actions or genuine capsule controls.

## Material and motion rules

- Do not reproduce web-style glass cards on every surface. Native materials are limited to sidebar, toolbar, popover, and carefully chosen overlays.
- Do not use decorative glow, gradient text, or heavy card shadows.
- Wallpaper imagery may provide atmosphere; UI should not manufacture competing atmosphere.
- Use system control states. Additional motion is limited to informative opacity/scale transitions.
- Reduce Motion removes nonessential movement. Reduce Transparency replaces translucent material with an opaque dynamic surface.
- Interactive controls cover default, hover where useful, keyboard focus, pressed, disabled, loading, error, and success behavior.

## Page structure consequences

- Dashboard: image-led, few status summaries, no generic card dashboard.
- Sources: operational list + seven-day plan + default source, optimized for scanning.
- Library: thumbnail grid with stable geometry and an explicit current marker.
- Settings: native form rhythm, bounded reading width, destructive storage action separated.

## Missing assets

Dashboard screenshot export, Onboarding, Source Sheet, Menu Bar states, confirmation dialogs, Wallpaper Detail, failure/empty states, narrow-window rules, and a scalable logo/AppIcon source remain asset tasks. Until supplied, high-risk flows use native macOS component patterns rather than invented high-fidelity decoration.

## Hallmark influence

Hallmark tightened the original proposal by rejecting pervasive glassmorphism, invented content, repeated card structures, and decorative motion. The resulting system keeps the blue brand cue and soft surfaces without turning the native utility into a web mockup.

