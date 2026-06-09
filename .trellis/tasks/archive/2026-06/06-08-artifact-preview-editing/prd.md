# Artifact Preview And Editing

## Goal

Add inline artifact preview cards to Archipelago Server agent replies so users can inspect files, rendered web/doc outputs, and later PPT/diff/history artifacts from the conversation without losing context. Clicking a card should open a larger preview or editor surface using the app's existing file workspace where possible.

## What I already know

* User-requested capabilities:
  * Inline artifact preview cards in agent replies.
  * Artifact types: web iframe, document rendering, P2 PPT browsing.
  * Clicking a card expands to full-screen preview or code editor.
  * P2 capabilities: Diff view, version history, conversational local edits from selected code.
* Current app structure:
  * `modules/collaboration-runtime/` is the Next/React chat runtime.
  * `apps/archipelago-macos/` is the Swift macOS shell / Island app.
* Current runtime already has useful building blocks:
  * Message rendering lives around `src/components/message/content-parts-renderer.tsx` and `message-bubble.tsx`.
  * File workspace state lives in `src/contexts/workspace-context.tsx`.
  * Existing file workspace supports `openFilePreview`, `openWorkingTreeDiff`, `openSessionFileDiff`, `toggleFilesMaximized`, editable Monaco tabs, image previews, Markdown rendering, and rich/unified diff tabs.
  * `src/components/files/file-workspace-panel.tsx` already supports Monaco, image preview, Markdown rendering, and diff rendering.
  * `@monaco-editor/react`, `monaco-editor`, `streamdown`, and diff components are already dependencies.
  * Markdown file links already route through `FilePathLink` / link safety into workspace file previews.

## Assumptions (temporary)

* User confirmed on 2026-06-08: land all listed capabilities quickly, and do not implement a full security strategy first.
* The implementation should favor pragmatic UI plumbing over a hardened artifact sandbox.
* P1 should ship the high-value foundation first: inline artifact cards for files generated or referenced by agent replies, with click-through to the existing file workspace preview/editor.
* P1 should reuse the existing workspace file pane and maximize behavior as the "full-screen preview / code editor" surface instead of introducing a separate modal editor.
* Artifact cards should be inferred from structured references already present in messages and tool calls where possible, then from explicit markdown/file references as fallback.
* Web iframe preview should be implemented quickly for URLs / local HTML references without a complete policy engine.
* P2 features (PPT browsing, diff view, version history, selected-code conversational editing) should be included in the same rapid pass with lightweight behavior where the deeper backing store is not yet present.

## Open Questions

* None blocking after user confirmed rapid all-feature implementation.

## Requirements (evolving)

### Rapid Implementation Scope

* Render inline artifact cards inside assistant messages when an agent produces or references a previewable artifact.
* Supported artifact categories:
  * Code/text files: open in the existing Monaco-backed workspace editor.
  * Markdown/doc-like files: render through the existing file preview pipeline.
  * Images: show thumbnail and open through the existing image preview/file workspace.
  * HTML/web artifacts: show a web-style card and open an iframe/web preview when possible.
  * PPT/presentation artifacts: show a presentation card and browsable PPTX preview with extracted slide text and embedded images where available.
  * Diff artifacts: show a diff card and open diff view.
  * Version history: expose a lightweight history panel from available artifact/card metadata or git-backed file state where possible.
  * Conversational local edits: allow selected editor/code text to be sent into chat as local modification context.
* Card click behavior:
  * Open the artifact in the file workspace.
  * Activate the files pane.
  * Allow maximize/full-screen using existing workspace maximize controls, or trigger maximized mode directly if the UX calls for it.
* Preserve existing file-link behavior and avoid duplicate noisy cards for the same artifact in one message.
* Keep cards compact in the chat timeline and visually consistent with existing Apple-style runtime UI.
* Handle missing/inaccessible files with a clear error state without breaking message rendering.

## Acceptance Criteria (evolving)

* [x] Assistant message with a referenced local code file renders an inline artifact card.
* [x] Clicking the code artifact opens the file in the existing workspace editor.
* [x] Assistant message with a referenced Markdown/doc file renders an inline card and opens a rendered preview/editor path consistent with current file workspace behavior.
* [x] Assistant message with a referenced image renders an inline thumbnail-style artifact card and opens the image preview/file tab.
* [x] HTML/web artifact card opens a preview path or falls back to source/content preview without a full safety strategy.
* [x] PPT/presentation artifact renders as a first-class card and opens a browsable preview surface with real PPTX slide text and embedded image extraction.
* [x] Diff artifact card opens an existing diff view where enough data is available.
* [x] Artifact full-screen preview exposes version history UI.
* [x] Selecting code/content in an artifact/editor can populate the chat with local edit context.
* [x] Repeated references to the same artifact in one message do not create duplicate cards.
* [x] Missing file references produce a non-fatal error state.
* [x] Existing tool call, markdown, diff, image-generation, and file-link rendering continues to work.
* [x] Relevant unit/component tests are added or updated.
* [x] `pnpm test`, TypeScript, and targeted lint pass for `modules/collaboration-runtime`.

## Definition of Done (team quality bar)

* Tests added/updated for new parsing/rendering behavior where practical.
* Lint / typecheck / targeted tests pass.
* Existing message rendering regressions checked.
* Docs/notes updated if a durable artifact metadata contract is introduced.
* P2 scope is explicitly deferred or separately taskable if not implemented.

## Out of Scope (explicit)

* Full arbitrary remote website embedding without a security model.
* Full presentation editor.
* Full version-control history browser if not needed for P1.
* Multi-user concurrent editing semantics.
* Replacing the existing file workspace/editor infrastructure.

## Technical Notes

* Likely frontend files:
  * `modules/collaboration-runtime/src/components/message/content-parts-renderer.tsx`
  * `modules/collaboration-runtime/src/components/message/message-bubble.tsx`
  * `modules/collaboration-runtime/src/contexts/workspace-context.tsx`
  * `modules/collaboration-runtime/src/components/files/file-workspace-panel.tsx`
  * `modules/collaboration-runtime/src/components/ai-elements/link-safety.tsx`
  * `modules/collaboration-runtime/src/lib/types.ts`
* Current reusable APIs:
  * `openFilePreview(path, options?)`
  * `openWorkingTreeDiff(path?, options?)`
  * `openSessionFileDiff(filePath, diffContent, groupLabel)`
  * `toggleFilesMaximized()`
  * `readFilePreview(rootPath, path)`
  * `readFileForEdit(rootPath, path)`
  * `saveFileContent(rootPath, path, content, expectedEtag?)`
* Relevant specs read:
  * `.trellis/spec/guides/index.md`
  * `.trellis/spec/frontend/index.md`
  * `.trellis/spec/frontend/component-guidelines.md`
  * `.trellis/spec/frontend/state-management.md`
  * `.trellis/spec/backend/index.md`
* Existing conventions:
  * Use `AppleIcon` / `AppleIconTile` in user-facing runtime UI instead of direct `lucide-react` imports.
  * Keep file/editor state centralized in `WorkspaceContext`; do not create a second competing file workspace state model.
