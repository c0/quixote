# Quixote Site UI Kit

Web recreation of the marketing site at `c0.github.io/quixote`. Source: `quixote-swift/site/src/`.

## Files

| File | What |
|---|---|
| `index.html` | Full hero page. Open to see the dither background live. |
| `SitePrimitives.jsx` | `QX_SITE` tokens (deeper black palette), `QxSiteButton` (pill), `QxAppleGlyph`, `QxDitherBackground` (exact port of `DitherBackground.astro`). |
| `SiteHero.jsx` | `QxSiteHero` (logo + title + tagline + buttons + meta) and `QxSiteFooter`. |

## What's there

- Animated dithered canvas background — 12fps, 6-tone palette, Bayer 4×4 ordered dither, radial vignette overlay.
- Centered column layout (max-width 720px), 80px vertical gaps.
- Pill buttons: light primary (`rgba(244,247,251,0.94)` on near-black text) and dark secondary.
- Hero logo with strong drop-shadow.

## What's left out

- No routing; this is a single page.
- No real DMG URL — `dmgUrl` prop is a dead `#`.
- Respects `prefers-reduced-motion` and falls back to a static frame.
