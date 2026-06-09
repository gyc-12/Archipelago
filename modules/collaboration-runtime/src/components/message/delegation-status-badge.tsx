"use client"

import { useTranslations } from "next-intl"

import { AppleIcon } from "@/components/apple/apple-icon"
import { Badge } from "@/components/ui/badge"

export function StatusBadge({
  status,
  errorCode,
}: {
  status: "starting" | "running" | "ok" | "err"
  errorCode?: string
}) {
  const t = useTranslations("Folder.chat.delegation.status")
  if (status === "starting") {
    return (
      <Badge className="gap-1.5 rounded-full text-xs" variant="secondary">
        <AppleIcon
          name="spinner"
          className="size-3 animate-spin text-muted-foreground"
        />
        {t("starting")}
      </Badge>
    )
  }
  if (status === "running") {
    return (
      <Badge className="gap-1.5 rounded-full text-xs" variant="secondary">
        <AppleIcon name="spinner" className="size-3 animate-spin" />
        {t("running")}
      </Badge>
    )
  }
  if (status === "ok") {
    return (
      <Badge className="gap-1.5 rounded-full text-xs" variant="secondary">
        <AppleIcon name="checkCircle" className="size-3 text-green-600" />
        {t("ok")}
      </Badge>
    )
  }
  return (
    <Badge
      className="gap-1.5 rounded-full text-xs"
      variant="secondary"
      title={errorCode ?? undefined}
    >
      <AppleIcon name="warning" className="size-3 text-red-600" />
      <ErrorLabel code={errorCode} />
    </Badge>
  )
}

function ErrorLabel({ code }: { code?: string }) {
  const t = useTranslations("Folder.chat.delegation.status.err")
  switch (code) {
    case "delegation_disabled":
      return <>{t("delegation_disabled")}</>
    case "depth_limit":
      return <>{t("depth_limit")}</>
    case "invalid_agent_type":
      return <>{t("invalid_agent_type")}</>
    case "spawn_failed":
      return <>{t("spawn_failed")}</>
    case "send_failed":
      return <>{t("send_failed")}</>
    case "timeout":
      return <>{t("timeout")}</>
    case "canceled":
      return <>{t("canceled")}</>
    case "child_refusal":
      return <>{t("child_refusal")}</>
    case "child_max_tokens":
      return <>{t("child_max_tokens")}</>
    case "child_max_turn_requests":
      return <>{t("child_max_turn_requests")}</>
    case "child_empty":
      return <>{t("child_empty")}</>
    case "child_unknown":
      return <>{t("child_unknown")}</>
    default:
      return <>{t("default")}</>
  }
}
