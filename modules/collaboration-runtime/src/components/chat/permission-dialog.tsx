"use client"

import { useMemo } from "react"
import { useTranslations } from "next-intl"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { CodeBlock } from "@/components/ai-elements/code-block"
import { UnifiedDiffPreview } from "@/components/diff/unified-diff-preview"
import { MessageResponse } from "@/components/ai-elements/message"
import { AppleIcon } from "@/components/apple/apple-icon"
import { AppleIconTile } from "@/components/apple/apple-icon-tile"
import type { PendingPermission } from "@/contexts/acp-connections-context"
import { parsePermissionToolCall } from "@/lib/permission-request"

interface PermissionDialogProps {
  permission: PendingPermission | null
  onRespond: (requestId: string, optionId: string) => void
}

function formatKindLabel(kind: string, fallbackLabel: string): string {
  const normalized = kind.replace(/_/g, " ").trim()
  return normalized.length > 0 ? normalized : fallbackLabel
}

export function PermissionDialog({
  permission,
  onRespond,
}: PermissionDialogProps) {
  const t = useTranslations("Folder.chat.permissionDialog")
  const parsed = useMemo(
    () => parsePermissionToolCall(permission?.tool_call),
    [permission?.tool_call]
  )
  if (!permission) return null

  const hasFileChanges = parsed.fileChanges.length > 0
  const hasPlan =
    parsed.planEntries.length > 0 || Boolean(parsed.planExplanation)
  const hasPlanMarkdown = Boolean(parsed.planMarkdown)
  const hasAllowedPrompts = parsed.allowedPrompts.length > 0
  const hasWeb = Boolean(parsed.url) || Boolean(parsed.query)
  const hasStructured =
    Boolean(parsed.command) ||
    hasFileChanges ||
    hasPlan ||
    hasPlanMarkdown ||
    hasAllowedPrompts ||
    Boolean(parsed.modeTarget) ||
    hasWeb

  return (
    <div className="mx-4 mb-3 rounded-[20px] border border-white/60 bg-[rgb(255_255_255_/_82%)] p-3.5 shadow-none ring-1 ring-black/5 backdrop-blur-2xl dark:border-white/10 dark:bg-[rgb(36_36_38_/_86%)] dark:ring-white/10">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <div className="flex items-center gap-2 text-sm font-semibold tracking-[-0.224px]">
            <AppleIconTile
              name="warning"
              tone="orange"
              className="size-7 rounded-[9px]"
              iconClassName="size-4"
            />
            <span className="truncate">{parsed.title}</span>
          </div>
          <p className="pl-9 text-xs text-muted-foreground">{t("subtitle")}</p>
        </div>
        <Badge
          variant="outline"
          className="shrink-0 rounded-full bg-background/60 px-2.5 text-[10px]"
        >
          {formatKindLabel(parsed.normalizedKind, t("kindFallbackTool"))}
        </Badge>
      </div>

      <div className="mt-3 max-h-[min(36vh,18rem)] space-y-2 overflow-y-auto pr-1">
        {parsed.command && (
          <div className="space-y-1.5 rounded-[14px] border border-border/50 bg-background/70 p-2.5 dark:bg-white/[0.04]">
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <AppleIcon name="terminal" className="size-3.5" />
              <span>{t("command")}</span>
            </div>
            <CodeBlock code={parsed.command} language="bash" />
            {parsed.cwd && (
              <div className="break-all text-xs text-muted-foreground">
                {t("cwd", { cwd: parsed.cwd })}
              </div>
            )}
          </div>
        )}

        {hasFileChanges && parsed.diffPreview && (
          <UnifiedDiffPreview diffText={parsed.diffPreview} />
        )}

        {hasPlan && (
          <div className="space-y-1.5 rounded-[14px] border border-border/50 bg-background/70 p-2.5 dark:bg-white/[0.04]">
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <AppleIcon name="todo" className="size-3.5" />
              <span>{t("plan")}</span>
            </div>
            {parsed.planExplanation && (
              <p className="text-xs text-foreground/90">
                {parsed.planExplanation}
              </p>
            )}
            {parsed.planEntries.length > 0 && (
              <div className="space-y-1 rounded-[11px] bg-muted/35 p-2">
                {parsed.planEntries.map((entry, index) => (
                  <div key={`${entry.text}-${index}`} className="text-xs">
                    <span className="text-foreground/90">{entry.text}</span>
                    {entry.status && (
                      <span className="ml-2 text-muted-foreground">
                        ({entry.status})
                      </span>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {hasPlanMarkdown && (
          <div className="space-y-1.5 rounded-[14px] border border-border/50 bg-background/70 p-2.5 dark:bg-white/[0.04]">
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <AppleIcon name="file" className="size-3.5" />
              <span>{t("plan")}</span>
            </div>
            <div className="text-sm prose prose-sm dark:prose-invert max-w-none [&_ul]:list-inside [&_ol]:list-inside">
              <MessageResponse>{parsed.planMarkdown!}</MessageResponse>
            </div>
          </div>
        )}

        {hasAllowedPrompts && (
          <div className="space-y-1.5 rounded-[14px] border border-border/50 bg-background/70 p-2.5 dark:bg-white/[0.04]">
            <div className="flex items-center gap-1 text-xs text-muted-foreground">
              <AppleIcon name="terminal" className="size-3.5" />
              <span>{t("allowedActions")}</span>
            </div>
            <div className="space-y-1 rounded-[11px] bg-muted/35 p-2">
              {parsed.allowedPrompts.map((item, index) => (
                <div
                  key={`${item.prompt}-${index}`}
                  className="flex items-center gap-2 text-xs"
                >
                  {item.tool && (
                    <Badge variant="outline" className="shrink-0 text-[10px]">
                      {item.tool}
                    </Badge>
                  )}
                  <span className="text-foreground/90">{item.prompt}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {parsed.modeTarget && (
          <div className="rounded-[14px] border border-border/50 bg-background/70 p-2.5 text-xs dark:bg-white/[0.04]">
            <div className="flex items-center gap-1 text-muted-foreground">
              <AppleIcon name="general" className="size-3.5" />
              <span>{t("targetMode", { mode: parsed.modeTarget })}</span>
            </div>
          </div>
        )}

        {hasWeb && (
          <div className="space-y-1.5 rounded-[14px] border border-border/50 bg-background/70 p-2.5 dark:bg-white/[0.04]">
            {parsed.url && (
              <div className="flex items-center gap-2 text-xs">
                <AppleIcon
                  name="globe"
                  className="size-3.5 shrink-0 text-muted-foreground"
                />
                <span className="break-all font-mono text-foreground/90">
                  {parsed.url}
                </span>
              </div>
            )}
            {parsed.query && (
              <div className="flex items-center gap-2 text-xs">
                <AppleIcon
                  name="search"
                  className="size-3.5 shrink-0 text-muted-foreground"
                />
                <span className="break-all text-foreground/90">
                  {parsed.query}
                </span>
              </div>
            )}
            {parsed.prompt && (
              <div className="mt-1 text-xs text-muted-foreground">
                <MessageResponse>{parsed.prompt}</MessageResponse>
              </div>
            )}
          </div>
        )}

        {!hasStructured && (
          <pre className="rounded-[14px] border border-border/50 bg-background/70 p-2.5 text-xs whitespace-pre-wrap break-all text-foreground/90 dark:bg-white/[0.04]">
            {parsed.jsonPreview}
          </pre>
        )}
      </div>

      <div className="mt-3 flex flex-wrap gap-2 border-t border-border/40 pt-3">
        {permission.options.map((opt) => {
          const isReject = opt.kind.startsWith("reject")
          return (
            <Button
              key={opt.option_id}
              variant={isReject ? "outline" : "default"}
              className="h-auto min-h-9 rounded-full whitespace-normal break-words px-4 text-left"
              onClick={() => onRespond(permission.request_id, opt.option_id)}
            >
              {opt.name}
            </Button>
          )
        })}
      </div>
    </div>
  )
}
