# Brand Assets

This directory contains the current Archipelago icon assets for macOS packaging and internal product surfaces.

Structure:

- `Source/` keeps raw brand source assets that should not be treated as generated runtime output.
- `AppIcon.appiconset/`, `Archipelago.iconset/`, and `Archipelago.icns` are generated packaging assets used by the current manual macOS bundle packaging flow.
- `Internal/` contains small derived assets for in-app surfaces.

Generation workflow:

- regenerate everything with `python3 scripts/generate_brand_icons.py`
- the script outputs:
  - `AppIcon.appiconset/` for future asset-catalog use
  - `Archipelago.iconset/` and `Archipelago.icns` for current manual macOS bundle packaging
  - `Internal/color/` for in-app colored usage
  - `Internal/template/` for monochrome template-style usage
  - `Internal/badge/` for small boxed icon treatments

Current raw source assets:

- `app-icon-v7.png`: selected 1254x1254 Island+Agents source image for the current macOS app icon
- `Source/logo.png`: legacy raw logo source image retained for reference

macOS app icon sizes included:

- `16x16`
- `16x16@2x`
- `32x32`
- `32x32@2x`
- `128x128`
- `128x128@2x`
- `256x256`
- `256x256@2x`
- `512x512`
- `512x512@2x`

Why both formats exist:

- Apple’s asset-catalog workflow for macOS expects explicit icon sizes for the platform.
- The current Archipelago bundle is assembled manually by `scripts/package-app.sh` and launched for development testing by `scripts/launch-packaged-app.sh`, so it also needs a bundled `.icns` referenced by `CFBundleIconFile`.

Current design direction:

- shell: black glass rounded-square base with a cool metallic rim
- mark: a compact Dynamic Island-style coordinator connected to three agent nodes
- accent: restrained Action Blue glow matching the product design system
- internal surfaces: legacy small mark assets are retained until the in-app micro-icons are redesigned
