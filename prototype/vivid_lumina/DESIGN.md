---
name: Vivid Lumina
colors:
  surface: '#f9f9ff'
  surface-dim: '#d8d9e5'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f3fe'
  surface-container: '#ecedf9'
  surface-container-high: '#e6e8f3'
  surface-container-highest: '#e0e2ed'
  on-surface: '#181c23'
  on-surface-variant: '#414755'
  inverse-surface: '#2d3039'
  inverse-on-surface: '#eef0fc'
  outline: '#717786'
  outline-variant: '#c1c6d7'
  surface-tint: '#005bc1'
  primary: '#0058bc'
  on-primary: '#ffffff'
  primary-container: '#0070eb'
  on-primary-container: '#fefcff'
  inverse-primary: '#adc6ff'
  secondary: '#005ab3'
  on-secondary: '#ffffff'
  secondary-container: '#0073e0'
  on-secondary-container: '#fefcff'
  tertiary: '#9e3d00'
  on-tertiary: '#ffffff'
  tertiary-container: '#c64f00'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d8e2ff'
  primary-fixed-dim: '#adc6ff'
  on-primary-fixed: '#001a41'
  on-primary-fixed-variant: '#004493'
  secondary-fixed: '#d6e3ff'
  secondary-fixed-dim: '#aac7ff'
  on-secondary-fixed: '#001b3e'
  on-secondary-fixed-variant: '#00468d'
  tertiary-fixed: '#ffdbcc'
  tertiary-fixed-dim: '#ffb595'
  on-tertiary-fixed: '#351000'
  on-tertiary-fixed-variant: '#7c2e00'
  background: '#f9f9ff'
  on-background: '#181c23'
  surface-variant: '#e0e2ed'
  vivid-azure: '#0A84FF'
  electric-blue: '#007AFF'
  glass-surface: rgba(255, 255, 255, 0.7)
  glass-border: rgba(255, 255, 255, 0.3)
  glow-accent: rgba(10, 132, 255, 0.15)
typography:
  headline-hero:
    fontFamily: Plus Jakarta Sans
    fontSize: 56px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  display-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.5'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  button-text:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: '1'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  gutter: 24px
  margin-mobile: 20px
  margin-desktop: 64px
  container-max: 1440px
---

## Brand & Style

This design system shifts away from clinical precision toward a vibrant, high-energy digital environment inspired by modern spatial computing interfaces. The brand personality is optimistic, energetic, and premium, targeting a tech-savvy audience that values both aesthetics and performance. 

The design style is a hybrid of **Glassmorphism** and **Modern Apple-inspired Minimalism**. It relies on dynamic translucency, where the UI feels like a series of light-emitting panes floating over a rich, colorful background. Surfaces are not just containers but lenses that blur and tint the content beneath them. Every interaction should feel fluid and physical, utilizing subtle scaling and soft depth changes to provide tactile feedback.

## Colors

The palette is anchored by **Electric Blue** (#007AFF), a high-vibrancy primary color designed to pop against translucent backgrounds. While the default mode is `light`, the "lightness" is derived from semi-transparent white layers rather than solid fills.

- **Primary & Secondary:** Use these for interactive states, key call-to-actions, and active indicators.
- **Glass Surfaces:** Use semi-transparent whites (70-80% opacity) for cards and sidebars.
- **Dynamic Glows:** Behind major components or active states, apply soft radial gradients using the `glow-accent` to simulate light emitting from the component.
- **Backgrounds:** This system performs best when placed over high-resolution, colorful abstract wallpapers which can be seen through the blurred UI layers.

## Typography

The typography strategy balances the friendly, rounded nature of **Plus Jakarta Sans** for headlines with the functional precision of **Inter** for body text and UI labels.

Headlines should use tighter letter-spacing and heavier weights to maintain a strong presence on vibrant backgrounds. Body text is optimized for legibility through standard line heights and neutral character shapes. For mobile, hero headlines must scale down to ensure they do not break across too many lines, maintaining the "museum gallery" editorial feel.

## Elevation & Depth

Hierarchy is established through **Backdrop Blurs** and **Ambient Shadows** rather than flat color changes.

- **Surface Tiers:** 
  - *Tier 1 (Base):* The colorful background wallpaper.
  - *Tier 2 (Panels):* Sidebars and navigation bars with 30px backdrop blur and `glass-surface` fills.
  - *Tier 3 (Floating Cards):* Content cards with 20px backdrop blur and subtle white inner borders (1px) to catch "light."
- **Shadows:** Use extremely soft, large-radius shadows (Blur: 40px, Spread: -5px, Opacity: 10%) tinted with the primary blue color to simulate a neon-like glow on the surface below.
- **State Changes:** When an item is hovered or active, it should scale up (1.02x) and the shadow intensity should increase, moving the element visually closer to the user.

## Shapes

The shape language is consistently **Rounded**, reflecting a soft and approachable "VisionOS" aesthetic. 

Small components like checkboxes or tags use `rounded-md` (0.5rem), while main content containers and cards use `rounded-lg` (1rem). Buttons and search inputs should leverage the **Pill-shaped** (rounded-full) aesthetic to emphasize interactivity and a friendly touch. Avoid sharp corners entirely to maintain the fluid, organic feel of the interface.

## Components

- **Buttons:** Primary buttons use a solid `vivid-azure` fill with a subtle 10% brightness increase on hover. Secondary buttons should be glass-morphic with a thin white border.
- **Cards:** Must feature `backdrop-filter: blur(25px)` and a 1px `glass-border`. To add "vibrancy," include a faint radial gradient glow in the top-right corner of the card.
- **Inputs:** Search and text fields should be pill-shaped with a semi-transparent white background that becomes more opaque on focus.
- **Chips:** Highly rounded with a subtle "active" blue dot indicator for selected states.
- **Sidebars/Top Bars:** Should span the full edge but feel detached through the use of margins and high blur values, creating a "floating" chrome effect.
- **Interactivity:** All interactive elements must have a `transition: all 0.3s cubic-bezier(0.25, 0.1, 0.25, 1.0)` to ensure smooth, natural motion.