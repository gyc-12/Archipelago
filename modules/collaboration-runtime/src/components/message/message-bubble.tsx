"use client"

import { memo } from "react"
import { formatDistanceToNow } from "date-fns"
import { AppleIcon } from "@/components/apple/apple-icon"
import { cn } from "@/lib/utils"
import { ContentPartsRenderer } from "./content-parts-renderer"
import type { AdaptedMessage } from "@/lib/adapters/ai-elements-adapter"

interface MessageBubbleProps {
  message: AdaptedMessage
}

function RoleIcon({ role }: { role: string }) {
  switch (role) {
    case "user":
      return <AppleIcon name="chat" className="size-4" />
    case "assistant":
      return <AppleIcon name="agents" className="size-4" />
    case "system":
      return <AppleIcon name="system" className="size-4" />
    case "tool":
      return <AppleIcon name="terminal" className="size-4" />
    default:
      return <AppleIcon name="agents" className="size-4" />
  }
}

export const MessageBubble = memo(function MessageBubble({
  message,
}: MessageBubbleProps) {
  const isUser = message.role === "user"
  const timeAgo = formatDistanceToNow(new Date(message.timestamp), {
    addSuffix: true,
  })

  return (
    <div className={cn("flex gap-3 px-4 py-3", isUser ? "bg-muted/30" : "")}>
      <div
        className={cn(
          "w-7 h-7 rounded-full flex items-center justify-center shrink-0 mt-0.5",
          isUser
            ? "bg-primary text-primary-foreground"
            : "bg-secondary text-secondary-foreground"
        )}
      >
        <RoleIcon role={message.role} />
      </div>

      <div className="flex-1 min-w-0 space-y-2">
        <div className="flex items-center gap-2">
          <span className="text-xs font-medium capitalize">{message.role}</span>
          <span className="text-xs text-muted-foreground">{timeAgo}</span>
        </div>

        <ContentPartsRenderer parts={message.content} role={message.role} />
      </div>
    </div>
  )
})
