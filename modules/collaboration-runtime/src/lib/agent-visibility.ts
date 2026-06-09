import type { AgentType } from "@/lib/types"

const HIDDEN_USER_FACING_AGENT_TYPES = new Set<AgentType>([
  "open_claw",
  "cline",
])

export function isUserFacingAgentType(agentType: AgentType): boolean {
  return !HIDDEN_USER_FACING_AGENT_TYPES.has(agentType)
}
