"use client"

import { useState } from "react"
import { useTranslations } from "next-intl"
import { AppleIcon } from "@/components/apple/apple-icon"
import { AppleIconTile } from "@/components/apple/apple-icon-tile"
import { cn } from "@/lib/utils"

interface ToolCallBlockProps {
  type: "tool_use" | "tool_result"
  toolName?: string
  content: string | null
  isError?: boolean
}

export function ToolCallBlock({
  type,
  toolName,
  content,
  isError = false,
}: ToolCallBlockProps) {
  const t = useTranslations("Folder.chat.toolCallBlock")
  const [expanded, setExpanded] = useState(false)

  return (
    <div
      className={cn(
        "overflow-hidden rounded-[16px] border text-xs backdrop-blur-xl",
        isError
          ? "border-destructive/25 bg-destructive/5"
          : "border-border/50 bg-background/70 dark:bg-white/[0.04]"
      )}
    >
      <button
        onClick={() => setExpanded(!expanded)}
        className="flex w-full items-center gap-2 px-3 py-2 text-left transition-colors hover:bg-primary/8"
      >
        <AppleIcon
          name={expanded ? "arrowDown" : "arrowRight"}
          className="size-3 shrink-0"
        />
        {type === "tool_use" ? (
          <>
            <AppleIconTile
              name="wrench"
              tone="slate"
              className="size-6 rounded-[7px]"
              iconClassName="size-3.5"
            />
            <span className="font-medium">{toolName || t("tool")}</span>
          </>
        ) : (
          <>
            {isError ? (
              <AppleIconTile
                name="warning"
                tone="red"
                className="size-6 rounded-[7px]"
                iconClassName="size-3.5"
              />
            ) : (
              <AppleIconTile
                name="checkCircle"
                tone="green"
                className="size-6 rounded-[7px]"
                iconClassName="size-3.5"
              />
            )}
            <span className="font-medium">
              {isError ? t("error") : t("result")}
            </span>
          </>
        )}
      </button>
      {expanded && content && (
        <div className="border-t border-border/45 px-3 pb-2">
          <pre className="mt-2 max-h-64 overflow-auto whitespace-pre-wrap break-all rounded-[12px] bg-muted/25 p-2 text-xs text-muted-foreground">
            {content}
          </pre>
        </div>
      )}
    </div>
  )
}
