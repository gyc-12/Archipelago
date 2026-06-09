"use client"

import { useState, useRef, useEffect, useCallback } from "react"
import { useTranslations } from "next-intl"
import { Button } from "@/components/ui/button"
import { AppleIcon } from "@/components/apple/apple-icon"
import { AppleIconTile } from "@/components/apple/apple-icon-tile"
import { matchShortcutEvent } from "@/lib/keyboard-shortcuts"
import { useShortcutSettings } from "@/hooks/use-shortcut-settings"
import type { PendingQuestion } from "@/contexts/acp-connections-context"

interface QuestionDialogProps {
  question: PendingQuestion | null
  onAnswer: (answer: string) => void
}

export function QuestionDialog({ question, onAnswer }: QuestionDialogProps) {
  const t = useTranslations("Folder.chat.questionDialog")
  const { shortcuts } = useShortcutSettings()
  const [answer, setAnswer] = useState("")
  const textareaRef = useRef<HTMLTextAreaElement>(null)
  const prevQuestionIdRef = useRef<string | null>(null)

  const questionId = question?.tool_call_id ?? null
  if (questionId !== prevQuestionIdRef.current) {
    prevQuestionIdRef.current = questionId
    if (questionId && answer !== "") {
      setAnswer("")
    }
  }

  useEffect(() => {
    if (question) {
      textareaRef.current?.focus()
    }
  }, [question])

  const handleSubmit = useCallback(() => {
    const trimmed = answer.trim()
    if (!trimmed) return
    onAnswer(trimmed)
    setAnswer("")
  }, [answer, onAnswer])

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if (matchShortcutEvent(e, shortcuts.send_message)) {
        e.preventDefault()
        handleSubmit()
      }
    },
    [handleSubmit, shortcuts]
  )

  if (!question) return null

  return (
    <div className="mx-4 mb-3 rounded-[20px] border border-primary/20 bg-[rgb(255_255_255_/_84%)] p-3.5 shadow-none ring-1 ring-black/5 backdrop-blur-2xl dark:border-primary/25 dark:bg-[rgb(36_36_38_/_86%)] dark:ring-white/10">
      <div className="flex items-center gap-2 text-sm font-semibold tracking-[-0.224px]">
        <AppleIconTile
          name="chat"
          tone="blue"
          className="size-7 rounded-[9px]"
          iconClassName="size-4"
        />
        <span>{t("title")}</span>
      </div>

      <p className="mt-3 rounded-[16px] bg-background/70 px-3 py-2 text-sm text-foreground/90 whitespace-pre-wrap dark:bg-white/[0.04]">
        {question.question}
      </p>

      <div className="mt-3 flex gap-2">
        <textarea
          ref={textareaRef}
          value={answer}
          onChange={(e) => setAnswer(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={t("placeholder")}
          rows={2}
          className="flex-1 resize-none rounded-[18px] border border-border/60 bg-background/80 px-3.5 py-2.5 text-sm shadow-none placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/20 dark:bg-white/[0.04]"
        />
        <Button
          size="sm"
          disabled={!answer.trim()}
          onClick={handleSubmit}
          className="self-end rounded-full px-4"
        >
          <AppleIcon name="send" className="mr-1.5 size-3.5" />
          {t("send")}
        </Button>
      </div>
    </div>
  )
}
