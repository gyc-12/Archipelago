# Component Guidelines

> How components are built in this project.

---

## Overview

<!--
Document your project's component conventions here.

Questions to answer:
- What component patterns do you use?
- How are props defined?
- How do you handle composition?
- What accessibility standards apply?
-->

(To be filled by the team)

---

## Component Structure

<!-- Standard structure of a component file -->

(To be filled by the team)

---

## Props Conventions

<!-- How props should be defined and typed -->

(To be filled by the team)

---

## Styling Patterns

<!-- How styles are applied (CSS modules, styled-components, Tailwind, etc.) -->

### Convention: Island Archipelago Server Group-Chat Overview

**What**: The expanded Island group-chat home screen is an overview surface. Show group name, workspace, aggregate status, and agent chips only. Do not render the latest reply summary on the home list.

**Why**: Reply summaries make the home list visually heavy and compete with the detail surface. The latest reply belongs in the group detail view, where it has enough space and context.

**Example**:

```swift
// Home list row: overview only.
GroupChatRow(group: group)

// Detail row: agent status and latest answer summary can be shown.
ArchipelagoLatestResponseSummaryView(agentType: agent.agentType, summary: summary)
```

### Convention: Archipelago Server Agent Icons In Island

**What**: Island must mirror the embedded runtime's agent icon semantics. Use `ArchipelagoAgentIconView` for Island SwiftUI surfaces and keep its colors/shapes aligned with `modules/collaboration-runtime/src/components/agent-icon.tsx` and `AGENT_COLORS`.

**Why**: Agent identity needs to be visually consistent when the user moves between embedded Archipelago Server and Island. Do not invent unrelated symbols or colors for Claude Code, Codex, Gemini, OpenCode, OpenClaw, or Cline.

**Example**:

```swift
HStack(spacing: 5) {
    ArchipelagoAgentIconView(agentType: agent.agentType, size: 13)
    Text(agent.agentType.shortName)
}
```

**Wrong vs Correct**:

```swift
// Wrong: Codex is not the generic OpenAI swirl / six-petal approximation.
ForEach(0..<6) { petal in
    Capsule().rotationEffect(.degrees(Double(petal) * 60))
}

// Correct: Codex mirrors collaboration-runtime's CodexColorIcon path semantics.
CodexAgentShape()
    .fill(codexGradient, style: FillStyle(eoFill: true))
```

### Convention: Archipelago Server Apple-Style UI Icons

**What**: In `modules/collaboration-runtime`, use `AppleIcon` for toolbar/action glyphs and `AppleIconTile` for colorful settings-card, dialog, empty-state, and status-card icons. Keep `AgentIcon` for provider identity icons such as Claude Code, Codex, Gemini CLI, and OpenCode.

**Why**: The embedded Archipelago Server should visually match the native Island app without losing provider identity. Direct `lucide-react` imports in user-facing runtime UI tend to drift back toward generic web styling and make the integrated app feel inconsistent.

**Example**:

```tsx
import { AppleIcon } from "@/components/apple/apple-icon"
import { AgentIcon } from "@/components/agent-icon"

<Button size="icon">
  <AppleIcon name="search" className="size-4" />
</Button>

<AgentIcon agentType={conversation.agent_type} className="size-4" />
```

**Wrong vs Correct**:

```tsx
// Wrong: user-facing toolbar icons bypass the native-style abstraction.
import { Search } from "lucide-react"

<Search className="h-4 w-4" />

// Correct: semantic icon names stay centralized and styleable.
<AppleIcon name="search" className="size-4" />
```

### Convention: Compact Archipelago Server Agent Chips

**What**: Compact group-member chips in Archipelago Server chat input must keep icons fixed-size and labels truncating. Use `AgentIcon` with an explicit size class and cap the chip width.

**Why**: `AgentIcon` can render SVGs with different intrinsic geometry. Without fixed icon dimensions and a truncating text span, long roles or icon paths can stretch the chat input toolbar and cause layout overflow.

**Example**:

```tsx
<button className="inline-flex h-6 max-w-40 items-center gap-1.5 rounded-full px-2">
  <AgentIcon agentType={member.agent_type} className="size-3.5" />
  <span className="min-w-0 truncate">{member.role}</span>
</button>
```

**Wrong vs Correct**:

```tsx
// Wrong: the icon and label can decide the chip width.
<button className="inline-flex items-center">
  <AgentIcon agentType={member.agent_type} />
  <span>{member.role}</span>
</button>

// Correct: stable chip height, fixed icon size, bounded text.
<button className="inline-flex h-6 max-w-40 items-center gap-1.5">
  <AgentIcon agentType={member.agent_type} className="size-3.5" />
<span className="min-w-0 truncate">{member.role}</span>
</button>
```

### Convention: Conversation Artifact Preview Cards

**What**: Inline artifact previews in Archipelago Server messages should be thin launch surfaces. Detect/render cards in the message layer, but open files, diffs, and editors through `WorkspaceContext` APIs such as `openFilePreview`, `openSessionFileDiff`, `openWorkingTreeDiff`, and the existing file workspace panel.

**Why**: The file workspace already owns editor state, dirty tracking, image/document preview, diff rendering, reload behavior, and save conflict handling. A second artifact-specific editor state model would drift from the real workspace and lose existing safeguards.

**Example**:

```tsx
const { openFilePreview, openSessionFileDiff } = useWorkspaceContext()

<ArtifactPreviewCard
  artifact={artifact}
  onOpenFile={() => openFilePreview(artifact.path)}
  onOpenDiff={() =>
    openSessionFileDiff(artifact.path, artifact.diffText, "Artifact")
  }
/>
```

**Wrong vs Correct**:

```tsx
// Wrong: the message card owns a separate editable file buffer.
const [content, setContent] = useState(agentProducedFileContent)

// Correct: the card launches the shared file workspace/editor.
void openFilePreview(workspaceRelativePath)
```

---

## Accessibility

<!-- A11y requirements and patterns -->

(To be filled by the team)

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

(To be filled by the team)
