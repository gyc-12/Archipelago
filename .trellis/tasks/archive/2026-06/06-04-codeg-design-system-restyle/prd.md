# brainstorm: align codeg ui with design system

## Goal

Restyle the embedded Codeg pages so their page chrome, controls, and agent icon presentation align with `DESIGN.md` while leaving the Island SwiftUI surfaces unchanged.

## What I already know

* The user wants only the Codeg page side changed.
* `DESIGN.md` describes an Apple-like visual language: SF/system font stack, near-black/white/parchment surfaces, Action Blue `#0066cc` as the only interaction accent, low chrome, no decorative gradients, no card/button shadows, pill CTAs, and restrained iconography.
* Codeg is a Next/Tailwind app under `agentsIsland/codeg-main`.
* Main Codeg surfaces are `src/app/workspace/page.tsx`, `components/conversations/conversation-detail-panel.tsx`, `components/layout/sidebar.tsx`, `components/chat/*`, `components/message/*`, `components/settings/*`, `components/ui/*`, and `components/agent-icon.tsx`.
* Current Codeg globals use a large shadcn theme preset matrix, `JetBrains_Mono` as `--font-sans`, generic oklch primary variables, rounded-4xl buttons/badges, and existing colorful agent icons.

## Assumptions

* "Codeg page side" means the embedded Codeg web UI, including workspace/chat and Codeg settings pages.
* The first implementation should be a cohesive visual pass, not a full product-layout rebuild.
* Existing workflows, data contracts, and Island integration must remain unchanged.
* Agent icons should remain semantically recognizable but be presented in a cleaner, Apple-like frame/tone.

## Open Questions

* Should the first pass include all Codeg settings pages, or only the workspace/chat shell plus settings navigation shell?

## Requirements

* Apply Design tokens to Codeg global theme: typography, Action Blue, neutral surfaces, hairline borders, focus rings, and radius scale.
* Update reusable UI primitives where practical so buttons, badges, inputs, and cards read closer to `DESIGN.md`.
* Restyle Codeg workspace shell: title/sidebar/navigation chrome, conversation list rows, chat input container, and message surface.
* Restyle Codeg settings shell/navigation enough that `/settings` and `/settings/agents` no longer feel visually disconnected from the workspace.
* Update icon presentation style for Codeg UI controls and agent icons without changing Island SwiftUI icon implementation.

## Acceptance Criteria

* [ ] Codeg workspace and settings pages use Action Blue for primary interactive emphasis.
* [ ] Codeg surfaces use white/parchment/near-black neutral rhythm instead of arbitrary theme accents.
* [ ] Buttons and search/input controls use pill or compact utility shapes according to `DESIGN.md`.
* [ ] Cards/panels avoid decorative shadows and rely on hairlines/surface contrast.
* [ ] Agent icons in Codeg are visually consistent in size/framing and do not create noisy color clashes.
* [ ] Island UI files are not modified.
* [ ] `pnpm build` passes in `agentsIsland/codeg-main`.

## Definition of Done

* Focused code changes only in Codeg frontend files.
* Build/type-check passes.
* Packaged app can be launched for manual inspection.
* Trellis session is recorded and local commit created when implementation is complete.

## Out of Scope

* Island SwiftUI surface redesign.
* Backend/API/database changes.
* New product functionality.
* Rebuilding all Codeg pages as Apple-style marketing tiles.
* Replacing real agent/product logos with unrelated decorative illustrations.

## Technical Notes

* Design reference: `/Users/gyc/Code/new_small_step_codex/worktrees/new-small-step-agents-interop/DESIGN.md`.
* Current global CSS: `agentsIsland/codeg-main/src/app/globals.css`.
* Main workspace entry: `agentsIsland/codeg-main/src/app/workspace/page.tsx` -> `ConversationDetailPanel`.
* Settings shell entry: `agentsIsland/codeg-main/src/components/settings/settings-shell.tsx`.
* Agent icon source: `agentsIsland/codeg-main/src/components/agent-icon.tsx`.
