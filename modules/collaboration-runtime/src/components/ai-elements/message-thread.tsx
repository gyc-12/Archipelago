"use client"

import type { ComponentProps } from "react"

import { AppleIcon } from "@/components/apple/apple-icon"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { useTranslations } from "next-intl"
import { useCallback } from "react"
import { StickToBottom, useStickToBottomContext } from "use-stick-to-bottom"

export type MessageThreadProps = ComponentProps<typeof StickToBottom>

export const MessageThread = ({ className, ...props }: MessageThreadProps) => (
  <StickToBottom
    className={cn(
      "relative flex-1 overflow-y-hidden bg-[linear-gradient(180deg,rgb(255_255_255_/_35%),rgb(255_255_255_/_0%)_7rem)] dark:bg-[linear-gradient(180deg,rgb(255_255_255_/_4%),rgb(255_255_255_/_0%)_7rem)]",
      className
    )}
    initial="instant"
    resize="smooth"
    role="log"
    {...props}
  />
)

export type MessageThreadContentProps = ComponentProps<
  typeof StickToBottom.Content
>

export const MessageThreadContent = ({
  className,
  ...props
}: MessageThreadContentProps) => (
  <StickToBottom.Content
    className={cn("flex flex-col gap-8 p-4", className)}
    {...props}
  />
)

export type MessageThreadEmptyStateProps = ComponentProps<"div"> & {
  title?: string
  description?: string
  icon?: React.ReactNode
}

export const MessageThreadEmptyState = ({
  className,
  title,
  description,
  icon,
  children,
  ...props
}: MessageThreadEmptyStateProps) => {
  const t = useTranslations("Folder.chat.messageThread")
  return (
    <div
      className={cn(
        "flex size-full flex-col items-center justify-center gap-3 p-8 text-center",
        className
      )}
      {...props}
    >
      {children ?? (
        <>
          {icon && <div className="text-muted-foreground">{icon}</div>}
          <div className="space-y-1">
            <h3 className="font-medium text-sm">{title ?? t("emptyTitle")}</h3>
            {(description ?? t("emptyDescription")) && (
              <p className="text-muted-foreground text-sm">
                {description ?? t("emptyDescription")}
              </p>
            )}
          </div>
        </>
      )}
    </div>
  )
}

export type MessageThreadScrollButtonProps = ComponentProps<typeof Button>

export const MessageThreadScrollButton = ({
  className,
  ...props
}: MessageThreadScrollButtonProps) => {
  const { isAtBottom, scrollToBottom } = useStickToBottomContext()

  const handleScrollToBottom = useCallback(() => {
    scrollToBottom()
  }, [scrollToBottom])

  return (
    !isAtBottom && (
      <Button
        className={cn(
          "absolute bottom-4 left-[50%] translate-x-[-50%] rounded-full bg-card/85 shadow-[0_10px_26px_rgb(0_0_0_/_12%)] backdrop-blur-xl hover:bg-card",
          className
        )}
        onClick={handleScrollToBottom}
        size="icon"
        type="button"
        variant="outline"
        {...props}
      >
        <AppleIcon name="arrowDown" className="size-4" />
      </Button>
    )
  )
}

export interface ThreadMessage {
  role: "user" | "assistant" | "system" | "data" | "tool"
  content: string
}

export type MessageThreadDownloadProps = Omit<
  ComponentProps<typeof Button>,
  "onClick"
> & {
  messages: ThreadMessage[]
  filename?: string
  formatMessage?: (message: ThreadMessage, index: number) => string
}

const defaultFormatMessage = (message: ThreadMessage): string => {
  const roleLabel = message.role.charAt(0).toUpperCase() + message.role.slice(1)
  return `**${roleLabel}:** ${message.content}`
}

export const messagesToMarkdown = (
  messages: ThreadMessage[],
  formatMessage: (
    message: ThreadMessage,
    index: number
  ) => string = defaultFormatMessage
): string => messages.map((msg, i) => formatMessage(msg, i)).join("\n\n")

export const MessageThreadDownload = ({
  messages,
  filename = "conversation.md",
  formatMessage = defaultFormatMessage,
  className,
  children,
  ...props
}: MessageThreadDownloadProps) => {
  const handleDownload = useCallback(() => {
    const markdown = messagesToMarkdown(messages, formatMessage)
    const blob = new Blob([markdown], { type: "text/markdown" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = filename
    document.body.append(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
  }, [messages, filename, formatMessage])

  return (
    <Button
      className={cn(
        "absolute top-4 right-4 rounded-full bg-card/85 shadow-[0_10px_26px_rgb(0_0_0_/_12%)] backdrop-blur-xl hover:bg-card",
        className
      )}
      onClick={handleDownload}
      size="icon"
      type="button"
      variant="outline"
      {...props}
    >
      {children ?? <AppleIcon name="download" className="size-4" />}
    </Button>
  )
}
