# Archipelago Server Apple-Style UI Refactor Plan

## Direction

Refactor the Tauri/Next.js Archipelago Server UI so it visually belongs with the macOS Island app: restrained Apple-like surfaces, SF/system typography, Action Blue as the only primary accent, colored symbol tiles, pill controls, and iMessage-inspired chat bubbles.

This task stays inside `modules/collaboration-runtime`. It does not migrate the web UI to SwiftUI and does not change runtime protocols.

## Icon Strategy

Use `lucide-react` as the technical icon source, but do not expose raw lucide styling directly in the main UI. Add an Apple-style icon layer:

- `AppleIcon`: maps semantic icon names to existing lucide glyphs.
- `AppleIconTile`: renders a compact rounded-square/circle color tile with a white or tinted glyph, matching the native settings/sidebar style.
- Palette variants: blue, green, indigo, purple, orange, red, gray.
- Keep `AgentIcon` for Claude Code, Codex, Gemini, and OpenCode provider identity.

Why not bundle SF Symbols directly:

- SF Symbols is Apple-native and designed to integrate with San Francisco, but direct web/font bundling is not a stable or clearly appropriate path for this React/Tauri UI.
- Apple also documents usage restrictions around SF Symbols, especially trademark-like use. We should copy the interaction style, not ship Apple’s symbol assets as a web dependency.

## Visual System

Reuse and tighten the existing `globals.css` Archipelago tokens:

- Typography: `SF Pro Text`, `SF Pro Display`, `system-ui`, `-apple-system`.
- Accent: `#0066cc`, hover/focus `#0071e3`, dark accent `#2997ff`.
- Light surfaces: `#ffffff`, `#f5f5f7`, `#fafafc`.
- Dark surfaces: `#000000`, `#272729`, `#2a2a2c`, `#252527`.
- Borders: hairline `rgb(... / 8-12%)`, not heavy card borders.
- Avoid decorative gradients, oversized shadows, and one-off purple/blue-heavy styling.

## Component Work

### 1. Foundation Components

Add or update shared UI primitives:

- `apple-icon.tsx`
- `apple-icon-tile.tsx`
- update `components/ui/button.tsx` variants:
  - primary pill
  - secondary pill
  - glass/toolbar icon button
  - destructive soft pill

These should let settings, chat, sidebar, and dialogs share the same visual language without editing every call site differently.

### 2. Chat Surface

Refactor chat display in `message-list-view.tsx` and adjacent ai-elements wrappers:

- User messages: right-aligned Action Blue rounded bubble.
- Assistant messages: left-aligned neutral bubble or native text block depending content type.
- Tool calls/code blocks: keep readable framed panels, but soften borders and chrome.
- Preserve virtualized rendering, copy actions, stats, tool blocks, and plan overlays.
- Avoid a literal iMessage clone when content is code-heavy; code and tool output need desktop readability.

### 3. Message Input

Refactor `message-input.tsx` visually:

- Larger rounded composer surface.
- Toolbar icon buttons use Apple-style glyph buttons.
- Agent chips keep provider icons but adopt native capsule styling.
- Send/stop buttons use Action Blue and clear disabled states.

### 4. Settings Pages

Refactor `settings-shell.tsx` and common settings surfaces:

- Sidebar entries use colored `AppleIconTile` + label.
- Selected row uses soft blue fill and Action Blue glyph.
- Settings cards use plain white/light panels, 12-18px radius, hairline borders.
- Buttons and inputs use shared Apple-style primitives.

### 5. Sidebar / Conversation List

Refactor conversation rows:

- Reduce visual clutter.
- Group rows use native row selection style.
- Primary-agent indicator remains clear but not loud.
- Runtime state indicators use small colored status dots and subtle labels.

## Implementation Order

1. Add Apple-style primitives and tokens.
2. Apply primitives to settings shell and system settings page first.
3. Apply button styles globally via `components/ui/button.tsx`.
4. Refactor chat message bubbles and tool-call surfaces.
5. Refactor composer/input controls.
6. Refactor sidebar rows.
7. Build, package, launch, and screenshot-check settings + chat + sidebar.

## MVP Scope

MVP should cover:

- Main chat page
- Message bubbles
- Message input
- Settings shell and settings cards
- Conversation sidebar
- Non-agent UI icons

Out of MVP:

- Deep redesign of Monaco/code editor, diff viewer, terminal, merge pages
- New runtime features
- Replacing provider/agent logos
- True native SwiftUI rewrite of the web UI

## Validation

- `pnpm build` in `modules/collaboration-runtime`
- packaged launch via `apps/archipelago-macos/scripts/launch-packaged-app.sh`
- Manual check:
  - settings page
  - group chat conversation page
  - sidebar row selected/hover states
  - message send/stream/complete
  - light and dark mode

