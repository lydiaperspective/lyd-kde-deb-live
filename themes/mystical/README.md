# Mystical

A cute, polished, mystical lunar appearance for KDE Plasma and the early boot experience. The desktop should feel like a premium purple KDE experience first, with a gentle cartoon illustration style and thoughtful celestial and nature symbolism.

## Visual identity

- **Style:** rounded cartoon-vector artwork, soft shading, warm highlights, and restrained outlines.
- **Mood:** mystical, peaceful, nature-connected, and charming—not gothic or spooky.
- **Signature motifs:** moon phases and triple-moon imagery, stars, delicate botanical elements, crystals, and occasional subtle pentacle geometry.
- **Artwork balance:** use symbols intentionally. Not every icon needs to be a moon, and the desktop should not be crowded with decorative motifs.

## Palette

| Role | Name | Hex |
|---|---|---|
| Main background | Midnight Plum | #21152E |
| Raised surfaces | Deep Royal Plum | #30203F |
| Primary accent | Royal Purple | #583477 |
| Highlight | Amethyst | #9874C4 |
| Restrained accent | Antique Gold | #B69A55 |
| Soft text | Soft Lavender | #D7C8E8 |
| Warm light text | Warm Ivory | #E9E1D5 |

### KDE colour-role mapping

The installable KDE colour scheme applies the palette beyond application backgrounds:

- Window and view surfaces use midnight and deep plum, with subtle alternate-row contrast.
- Buttons, headers, and tooltips use raised plum surfaces.
- Selected items use royal purple and amethyst with high-contrast ivory text.
- Focus indicators use antique gold; hover indicators use amethyst.
- Active window decorations use royal purple, while inactive decorations recede into midnight plum.
- Link, visited-link, positive, neutral, and negative states retain distinct semantic colours.

These roles are designed to work with Breeze's existing widget geometry and interaction states. The colour scheme changes appearance, not layout.

## Appearance rules

- Breeze is the layout and spacing reference. Do not independently change margins, padding, widget dimensions, or control spacing.
- Use consistent, modest corner rounding compatible with Breeze.
- Use antique gold for focus, small highlights, and symbolic icon details; do not use it as a large text or surface colour.
- Keep typography clean and readable.
- Avoid heavy gothic styling, noisy textures, oversized pill controls, and excessive ornament.
- Use botanical and celestial-inspired details mainly in branding, wallpapers, splash screens, and selected icons.

## Current cartoon icon family

The SVG assets are original theme artwork and can be used independently in branding, launcher artwork, wallpapers, and future icon-theme work.

| Asset | Motif |
|---|---|
| icons/lyd-ark-mystical-moon.svg | Rounded antique-gold crescent with lavender sparkle |
| icons/triple-moon.svg | Waxing crescent, full moon, and waning crescent |
| icons/amethyst-crystal.svg | Softly faceted amethyst cluster |
| icons/lavender-sprig.svg | Lavender flowers and botanical leaves |
| icons/sage-leaf.svg | Sage leaves with gentle green shading |
| icons/pentacle.svg | Restrained antique-gold pentacle emblem |

These are standalone SVG artwork assets, not yet a complete installable KDE icon theme. A full icon theme needs application and system icon coverage, naming, inheritance, and size variants.

## Boot splash

The early-boot Plymouth theme uses a cartoon-inspired Lyd Ark crescent logo, midnight-plum background, and LYD ARK LINUX wordmark. Eight gold moon phases cross-fade in a continuous loop independent of Plymouth's boot-progress estimate. The Plymouth theme retains password and question prompts for encrypted installations.

The later KDE Plasma splash remains a separate component and uses the approved golden crescent and shooting-star artwork.

## Component status

- [x] Initial KDE colour scheme (colors/Mystical.colors)
- [x] Expanded KDE colour roles for windows, views, buttons, headers, selections, tooltips, and window decorations
- [x] Plasma 6 startup splash package (QML + SVG artwork; runtime validation pending)
- [x] Plymouth lunar boot theme with a progress-independent looping phase animation (runtime validation pending)
- [ ] Wallpapers with celestial and botanical motifs
- [x] Cartoon crescent launcher emblem
- [x] Initial Mystical cartoon SVG icon family
- [ ] Full installable KDE icon theme with application/system icon coverage
- [ ] Optional coordinated cursors
- [ ] Login-screen branding, where supported by the target Plasma version

## System Manager integration

Lyd Ark System Manager should use native KDE/Qt styling and follow the active system palette and Plasma theme. It should not impose a separate Mystical-only layout or spacing system.
