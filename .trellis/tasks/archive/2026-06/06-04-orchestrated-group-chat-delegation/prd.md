# Orchestrated Group Chat Delegation

## Goal

Let users launch a group-chat task from Island and have the Codeg primary agent act as an Orchestrator: understand the request, decompose it by group member role, delegate work to sub agents through the existing `delegate_to_agent` runtime, then aggregate the result in the primary agent chat stream. Island should show live busy/idle state and the final summary through the existing Codeg event sync path.

## What I Already Know

- Island-created group chats are Codeg-backed `group_chat` workspaces with `group_agent` members.
- Each group has a configurable `primary_agent_id`.
- Codeg already has `delegate_to_agent` MCP support and delegated sub-thread rendering.
- Codeg already enriches primary-agent prompts when the user mentions `@agent` or `@all`.
- Island already consumes `group_collaboration_plan`, status, content delta, and turn completion events.
- The correct integrated app launch command is `cd agentsIsland/open-vibe-island && zsh scripts/launch-packaged-app.sh`.

## Requirements

- Island group detail page provides a compact task composer for sending a user requirement to the selected group.
- Sending from Island targets the group's primary agent conversation.
- If the primary agent has no active Codeg connection, Island connects it, binds the connection to the existing primary conversation, and subscribes to runtime events.
- Island sends the prompt with an explicit automatic collaboration mode; users do not need to type `@all`.
- Codeg auto-collaboration mode resolves the prompt's conversation to the active group primary agent and injects Orchestrator instructions.
- The Orchestrator instructions tell the primary agent to decompose the request, delegate focused subtasks to group members through `delegate_to_agent`, wait for results, and produce one integrated final answer.
- Codeg still supports the existing mention-based collaboration behavior for normal Codeg chat input.
- Island marks the primary agent and planned delegated members busy while work is in progress and records the final summary after the primary agent completes.
- Codeg primary-agent conversation remains the visible source of the full workflow and delegated sub-thread details.

## Acceptance Criteria

- [ ] From Island group detail, entering a requirement and pressing send starts the primary agent turn.
- [ ] The Codeg primary conversation receives the user requirement and shows Orchestrator/delegation flow through existing Codeg chat rendering.
- [ ] The group's non-primary agents are included in the collaboration plan without requiring manual `@agent` text.
- [ ] Island busy/idle status updates for the primary agent and delegated members.
- [ ] Island displays the final response summary after the primary agent completes.
- [ ] Existing Codeg `@agent` / `@all` prompt enrichment still works unchanged.

## Definition Of Done

- Rust backend builds and group collaboration tests pass.
- Swift app builds.
- TypeScript build passes if frontend API types are touched.
- Trellis specs are updated if a new cross-layer contract is introduced.
- Packaged app is relaunched for manual verification if implementation changes runtime behavior.

## Out Of Scope

- A separate orchestration scheduler or database table.
- Persisting explicit task decomposition records outside the normal Codeg conversation.
- Sophisticated agent selection heuristics beyond the primary agent's LLM-driven role-based delegation.
- Parallel execution controls, retries, or per-subtask cancellation UI.
- Importing or orchestrating non-Island historical Codeg conversations.

## Technical Notes

- Reuse `agentsIsland/codeg-main/src-tauri/src/acp/group_collaboration.rs`.
- Extend `acp_prompt` with an optional collaboration mode so Codeg chat input can keep mention-only behavior while Island can request automatic collaboration.
- Island entry points are `CodegClient`, `CodegCoordinator`, and `GroupDetailView`.
- The stable group-agent id remains the key for Island collaboration member state.
