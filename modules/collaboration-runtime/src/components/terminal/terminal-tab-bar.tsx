"use client"

import { useMemo, useRef, useState } from "react"
import { Minus, Plus, X } from "lucide-react"
import { useTranslations } from "next-intl"
import { useActiveFolder } from "@/contexts/active-folder-context"
import { useAppWorkspace } from "@/contexts/app-workspace-context"
import { useTerminalContext } from "@/contexts/terminal-context"
import { useShortcutSettings } from "@/hooks/use-shortcut-settings"
import { useIsMac } from "@/hooks/use-is-mac"
import { formatShortcutLabel } from "@/lib/keyboard-shortcuts"
import { Button } from "@/components/ui/button"
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"

export function TerminalTabBar() {
  const t = useTranslations("Folder.terminal")
  const { shortcuts } = useShortcutSettings()
  const isMac = useIsMac()
  const {
    tabs,
    activeTabId,
    switchTerminal,
    closeTerminal,
    closeOtherTerminals,
    closeAllTerminals,
    renameTerminal,
    createTerminal,
    toggle,
  } = useTerminalContext()
  const { activeFolderId } = useActiveFolder()
  const { folders } = useAppWorkspace()

  const folderIndex = useMemo(() => {
    const map = new Map<number, string>()
    for (const f of folders) map.set(f.id, f.name)
    return map
  }, [folders])

  const canCreateTerminal = activeFolderId != null

  const [editingId, setEditingId] = useState<string | null>(null)
  const [editValue, setEditValue] = useState("")
  const inputRef = useRef<HTMLInputElement>(null)

  const startRename = (id: string, title: string) => {
    setEditingId(id)
    setEditValue(title)
    setTimeout(() => inputRef.current?.select(), 0)
  }

  const commitRename = () => {
    if (editingId && editValue.trim()) {
      renameTerminal(editingId, editValue.trim())
    }
    setEditingId(null)
  }

  return (
    <div className="flex h-9 shrink-0 items-center gap-1 border-b border-border/70 bg-background/80 px-1.5 backdrop-blur-xl">
      {tabs.map((tab) => (
        <ContextMenu key={tab.id}>
          <ContextMenuTrigger asChild>
            <div
              className={`flex h-6 cursor-pointer select-none items-center gap-1 rounded-full border px-2 text-xs transition-colors ${
                tab.id === activeTabId
                  ? "border-primary/20 bg-primary/10 text-foreground"
                  : "border-transparent text-muted-foreground hover:bg-primary/8 hover:text-foreground"
              }`}
              onClick={() => switchTerminal(tab.id)}
              title={`${folderIndex.get(tab.folderId) ?? String(tab.folderId)}  —  ${tab.title}`}
            >
              {editingId === tab.id ? (
                <input
                  ref={inputRef}
                  className="w-20 rounded-full border border-primary/40 bg-transparent px-1.5 text-xs outline-none"
                  value={editValue}
                  onChange={(e) => setEditValue(e.target.value)}
                  onBlur={commitRename}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") commitRename()
                    if (e.key === "Escape") setEditingId(null)
                  }}
                />
              ) : (
                <span className="truncate max-w-[120px]">{tab.title}</span>
              )}
              <button
                className="ml-1 rounded-full p-0.5 transition-colors hover:bg-primary/10"
                onClick={(e) => {
                  e.stopPropagation()
                  closeTerminal(tab.id)
                }}
              >
                <X className="h-3 w-3" />
              </button>
            </div>
          </ContextMenuTrigger>
          <ContextMenuContent>
            <ContextMenuItem onSelect={() => startRename(tab.id, tab.title)}>
              {t("rename")}
            </ContextMenuItem>
            <ContextMenuSeparator />
            <ContextMenuItem onSelect={() => closeTerminal(tab.id)}>
              {t("close")}
            </ContextMenuItem>
            <ContextMenuItem
              onSelect={() => closeOtherTerminals(tab.id)}
              disabled={tabs.length <= 1}
            >
              {t("closeOthers")}
            </ContextMenuItem>
            <ContextMenuItem onSelect={() => closeAllTerminals()}>
              {t("closeAll")}
            </ContextMenuItem>
          </ContextMenuContent>
        </ContextMenu>
      ))}
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <span>
              <Button
                variant="ghost"
                size="icon"
                className="h-7 w-7 shrink-0"
                onClick={() => void createTerminal()}
                disabled={!canCreateTerminal}
              >
                <Plus className="h-3 w-3" />
              </Button>
            </span>
          </TooltipTrigger>
          {!canCreateTerminal && (
            <TooltipContent side="top">{t("openFolderFirst")}</TooltipContent>
          )}
        </Tooltip>
      </TooltipProvider>
      <Button
        variant="ghost"
        size="icon"
        className="ml-auto h-7 w-7 shrink-0"
        onClick={toggle}
        title={t("hideTerminal", {
          shortcut: formatShortcutLabel(shortcuts.toggle_terminal, isMac),
        })}
      >
        <Minus className="h-3 w-3" />
      </Button>
    </div>
  )
}
