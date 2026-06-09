import type { AppleIconName } from "@/components/apple/apple-icon"
import type {
  AgentType,
  SessionConfigOptionInfo,
  SessionConfigSelectOptionInfo,
  SessionModeInfo,
} from "@/lib/types"

export type SelectorIconSpec =
  | { type: "apple"; name: AppleIconName }
  | { type: "agent"; agentType: AgentType }

function normalize(value: string | null | undefined): string {
  return value?.trim().toLowerCase() ?? ""
}

function includesAny(value: string, needles: string[]): boolean {
  return needles.some((needle) => value.includes(needle))
}

function textForMode(mode: SessionModeInfo): string {
  return [mode.id, mode.name, mode.description ?? ""].map(normalize).join(" ")
}

function textForConfig(
  option: SessionConfigOptionInfo,
  item?: SessionConfigSelectOptionInfo | null
): string {
  return [
    option.category ?? "",
    option.id,
    option.name,
    option.description ?? "",
    item?.value ?? "",
    item?.name ?? "",
    item?.description ?? "",
  ]
    .map(normalize)
    .join(" ")
}

function apple(name: AppleIconName): SelectorIconSpec {
  return { type: "apple", name }
}

function agent(agentType: AgentType): SelectorIconSpec {
  return { type: "agent", agentType }
}

function modelIconForText(text: string): SelectorIconSpec | null {
  if (includesAny(text, ["claude", "sonnet", "opus", "haiku"])) {
    return agent("claude_code")
  }
  if (includesAny(text, ["gpt", "openai", "chatgpt", "codex"])) {
    return agent("codex")
  }
  if (includesAny(text, ["gemini"])) return agent("gemini")

  return null
}

function reasoningIconForText(text: string): SelectorIconSpec {
  if (includesAny(text, ["xhigh", "x-high", "max", "maximum"])) {
    return apple("batteryFull")
  }
  if (includesAny(text, ["high"])) return apple("batteryHigh")
  if (includesAny(text, ["medium"])) return apple("batteryMedium")
  if (includesAny(text, ["low", "minimal", "fast", "light"])) {
    return apple("batteryLow")
  }

  return apple("thinking")
}

function permissionIconForText(text: string): SelectorIconSpec {
  if (includesAny(text, ["full access", "full-access"])) {
    return apple("unlock")
  }

  if (
    includesAny(text, [
      "bypass",
      "yolo",
      "unrestricted",
      "without asking",
      "without asking for approval",
    ])
  ) {
    return apple("lockKeyOpen")
  }

  if (
    includesAny(text, [
      "don't ask",
      "dont ask",
      "do not ask",
      "deny if not pre-approved",
      "deny if not preapproved",
    ])
  ) {
    return apple("shieldSlash")
  }

  if (includesAny(text, ["read only", "read-only", "readonly"])) {
    return apple("fileLock")
  }

  if (
    includesAny(text, [
      "accept edits",
      "auto-accept",
      "auto accept",
      "file edit",
      "edit operation",
      "write",
      "patch",
    ])
  ) {
    return apple("edit")
  }

  if (
    includesAny(text, [
      "plan mode",
      "planning",
      "no actual tool execution",
      "no tool execution",
    ])
  ) {
    return apple("todo")
  }

  if (
    includesAny(text, [
      "auto",
      "model classifier",
      "approve/deny",
      "approve deny",
    ])
  ) {
    return apple("shieldCheck")
  }

  if (includesAny(text, ["default", "dangerous", "prompts for"])) {
    return apple("shieldWarning")
  }

  if (includesAny(text, ["approval", "permission", "sandbox", "safe", "ask"])) {
    return apple("shield")
  }

  return apple("shield")
}

function iconForText(text: string): SelectorIconSpec | null {
  if (
    includesAny(text, [
      "thought",
      "thinking",
      "reasoning",
      "reasoning effort",
      "effort",
      "think",
    ])
  ) {
    return reasoningIconForText(text)
  }

  const modelIcon = modelIconForText(text)
  if (modelIcon) return modelIcon

  if (includesAny(text, ["plan", "todo", "task"])) return apple("todo")
  if (includesAny(text, ["chat", "conversation"])) return apple("chat")
  if (includesAny(text, ["agent", "delegate", "subagent"]))
    return apple("agents")
  if (includesAny(text, ["edit", "write", "patch"])) return apple("edit")
  if (includesAny(text, ["search", "web", "browse"])) return apple("search")
  if (includesAny(text, ["terminal", "command", "shell"])) {
    return apple("terminal")
  }
  if (includesAny(text, ["default", "auto", "normal"])) return apple("general")

  return null
}

export function getModeIconSpec(
  mode: SessionModeInfo | null
): SelectorIconSpec {
  if (!mode) return apple("general")
  return iconForText(textForMode(mode)) ?? apple("general")
}

export function getConfigOptionIconSpec(
  option: SessionConfigOptionInfo,
  item?: SessionConfigSelectOptionInfo | null
): SelectorIconSpec {
  const text = textForConfig(option, item)

  switch (normalize(option.category)) {
    case "model":
      return modelIconForText(text) ?? apple("model")
    case "thought_level":
      return reasoningIconForText(text)
    case "mode":
      return permissionIconForText(text)
    default:
      return iconForText(text) ?? apple("general")
  }
}
