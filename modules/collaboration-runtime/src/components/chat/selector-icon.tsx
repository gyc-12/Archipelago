"use client"

import { AgentIcon } from "@/components/agent-icon"
import { AppleIcon } from "@/components/apple/apple-icon"
import type { SelectorIconSpec } from "@/components/chat/selector-icons"

interface SelectorIconProps {
  spec: SelectorIconSpec
  className?: string
}

export function SelectorIcon({ spec, className }: SelectorIconProps) {
  if (spec.type === "agent") {
    return <AgentIcon agentType={spec.agentType} className={className} />
  }

  return <AppleIcon name={spec.name} className={className} />
}
