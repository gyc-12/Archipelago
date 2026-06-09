"use client"

import { useEffect, useRef } from "react"
import { cn } from "@/lib/utils"
import type { AvailableCommandInfo } from "@/lib/types"

interface SlashCommandMenuProps {
  commands: AvailableCommandInfo[]
  selectedIndex: number
  onSelect: (command: AvailableCommandInfo) => void
}

export function SlashCommandMenu({
  commands,
  selectedIndex,
  onSelect,
}: SlashCommandMenuProps) {
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = listRef.current?.children[selectedIndex] as
      | HTMLElement
      | undefined
    el?.scrollIntoView({ block: "nearest" })
  }, [selectedIndex])

  if (commands.length === 0) return null

  return (
    <div
      ref={listRef}
      className="absolute bottom-full left-0 right-0 z-50 mb-1 max-h-48 overflow-y-auto rounded-[18px] border border-border/70 bg-popover/95 p-1 shadow-none ring-1 ring-border/60 backdrop-blur-xl"
    >
      {commands.map((cmd, i) => (
        <button
          key={cmd.name}
          type="button"
          className={cn(
            "flex w-full items-start gap-2 rounded-lg px-3 py-2 text-left text-sm",
            i === selectedIndex
              ? "bg-primary/8 text-foreground"
              : "hover:bg-primary/8"
          )}
          onMouseDown={(e) => {
            e.preventDefault()
            onSelect(cmd)
          }}
        >
          <span className="shrink-0 font-mono text-primary">/{cmd.name}</span>
          <span className="truncate text-xs text-muted-foreground">
            {cmd.description}
          </span>
        </button>
      ))}
    </div>
  )
}
