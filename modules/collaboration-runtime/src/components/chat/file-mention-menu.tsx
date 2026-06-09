"use client"

import { useEffect, useRef } from "react"
import { File, Folder } from "lucide-react"
import { cn } from "@/lib/utils"
import type { FlatFileEntry } from "@/hooks/use-file-tree"

interface FileMentionMenuProps {
  files: FlatFileEntry[]
  selectedIndex: number
  onSelect: (entry: FlatFileEntry) => void
}

export function FileMentionMenu({
  files,
  selectedIndex,
  onSelect,
}: FileMentionMenuProps) {
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = listRef.current?.children[selectedIndex] as
      | HTMLElement
      | undefined
    el?.scrollIntoView({ block: "nearest" })
  }, [selectedIndex])

  if (files.length === 0) return null

  return (
    <div
      ref={listRef}
      className="absolute bottom-full left-0 right-0 z-50 mb-1 max-h-48 overflow-y-auto rounded-[18px] border border-border/70 bg-popover/95 p-1 shadow-none ring-1 ring-border/60 backdrop-blur-xl"
    >
      {files.map((entry, i) => (
        <button
          key={entry.relativePath}
          type="button"
          className={cn(
            "flex w-full items-center gap-2 rounded-lg px-3 py-1.5 text-left text-sm",
            i === selectedIndex
              ? "bg-primary/8 text-foreground"
              : "hover:bg-primary/8"
          )}
          onMouseDown={(e) => {
            e.preventDefault()
            onSelect(entry)
          }}
        >
          {entry.kind === "dir" ? (
            <Folder className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
          ) : (
            <File className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
          )}
          <span className="truncate font-mono text-xs">
            {entry.relativePath}
          </span>
        </button>
      ))}
    </div>
  )
}
