"use client"

import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react"
import { Reorder } from "motion/react"
import { useTranslations } from "next-intl"
import { useWorkspaceContext } from "@/contexts/workspace-context"
import type { FileWorkspaceTab } from "@/contexts/workspace-context"
import { useIsCoarsePointer } from "@/hooks/use-is-coarse-pointer"
import { useIsMobile } from "@/hooks/use-mobile"
import { useLongPressDrag } from "@/hooks/use-long-press-drag"
import { useShortcutSettings } from "@/hooks/use-shortcut-settings"
import { matchShortcutEvent } from "@/lib/keyboard-shortcuts"
import { cn } from "@/lib/utils"
import { AppleIcon } from "@/components/apple/apple-icon"
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
} from "@/components/ui/context-menu"

export function FileWorkspaceTabBar() {
  const t = useTranslations("Folder.fileWorkspace")
  const {
    mode,
    activePane,
    fileTabs,
    activeFileTabId,
    switchFileTab,
    closeFileTab,
    closeOtherFileTabs,
    closeAllFileTabs,
    reorderFileTabs,
    previewFileTabIds,
    toggleFileTabPreview,
    filesMaximized,
    toggleFilesMaximized,
  } = useWorkspaceContext()
  const { shortcuts } = useShortcutSettings()
  const scrollRef = useRef<HTMLDivElement>(null)
  const isCoarsePointer = useIsCoarsePointer()
  const isMobile = useIsMobile()
  const [isHovered, setIsHovered] = useState(false)
  const [touchSortingTabId, setTouchSortingTabId] = useState<string | null>(
    null
  )

  const handleWheel = useCallback((e: React.WheelEvent<HTMLDivElement>) => {
    if (e.deltaY !== 0 && scrollRef.current) {
      e.preventDefault()
      scrollRef.current.scrollLeft += e.deltaY
    }
  }, [])

  useEffect(() => {
    if (!activeFileTabId || !scrollRef.current) return
    const el = scrollRef.current.querySelector(
      `[data-file-tab-id="${activeFileTabId}"]`
    )
    el?.scrollIntoView({ block: "nearest", inline: "nearest" })
  }, [activeFileTabId])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      // While maximized only the files pane is interactive, so route shortcuts
      // here regardless of the user's last-clicked pane.
      const shouldHandleShortcut =
        mode === "fusion" && (activePane === "files" || filesMaximized)
      if (!shouldHandleShortcut) return
      if (matchShortcutEvent(event, shortcuts.close_all_file_tabs)) {
        event.preventDefault()
        closeAllFileTabs()
        return
      }
      if (!matchShortcutEvent(event, shortcuts.close_current_tab)) return

      if (!activeFileTabId) return
      event.preventDefault()
      closeFileTab(activeFileTabId)
    }

    window.addEventListener("keydown", onKeyDown)
    return () => {
      window.removeEventListener("keydown", onKeyDown)
    }
  }, [
    activeFileTabId,
    closeAllFileTabs,
    closeFileTab,
    mode,
    activePane,
    filesMaximized,
    shortcuts.close_all_file_tabs,
    shortcuts.close_current_tab,
  ])

  const handleReorder = useCallback(
    (nextTabs: FileWorkspaceTab[]) => {
      if (isCoarsePointer && !touchSortingTabId) return
      reorderFileTabs(nextTabs)
    },
    [isCoarsePointer, reorderFileTabs, touchSortingTabId]
  )

  const handleTouchSortingEnd = useCallback(
    () => setTouchSortingTabId(null),
    []
  )

  const activeTab = fileTabs.find((tab) => tab.id === activeFileTabId)
  const canPreview =
    activeTab?.kind === "file" &&
    (activeTab.language === "markdown" || activeTab.language === "html")
  const isPreviewActive =
    canPreview && activeFileTabId
      ? previewFileTabIds.has(activeFileTabId)
      : false

  if (fileTabs.length === 0) {
    return (
      <div className="flex h-10 items-center border-b border-border/55 bg-background/75 px-3 text-xs text-muted-foreground backdrop-blur-2xl">
        {t("files")}
      </div>
    )
  }

  return (
    <div className="flex items-stretch bg-[rgb(255_255_255_/_76%)] backdrop-blur-2xl dark:bg-white/[0.04]">
      <Reorder.Group
        as="div"
        ref={scrollRef}
        role="tablist"
        axis="x"
        values={fileTabs}
        onReorder={handleReorder}
        onWheel={handleWheel}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        className={cn(
          "flex h-10 min-w-0 flex-1 items-stretch gap-1.5 border-b border-border/55 px-1.5 pt-1.5",
          "overflow-x-scroll",
          isHovered
            ? [
                "pb-0.5",
                "[&::-webkit-scrollbar]:h-1",
                "[&::-webkit-scrollbar-track]:bg-transparent",
                "[&::-webkit-scrollbar-thumb]:rounded-full",
                "[&::-webkit-scrollbar-thumb]:bg-border/80",
              ]
            : ["pb-1.5", "[&::-webkit-scrollbar]:h-0"]
        )}
      >
        {fileTabs.map((tab) => {
          return (
            <FileWorkspaceTabItem
              key={tab.id}
              tab={tab}
              active={tab.id === activeFileTabId}
              closeLabel={t("closeFileTab")}
              closeText={t("close")}
              closeOthersText={t("closeOthers")}
              closeAllText={t("closeAll")}
              isCoarsePointer={isCoarsePointer}
              isTouchSorting={touchSortingTabId === tab.id}
              onSwitch={switchFileTab}
              onClose={closeFileTab}
              onCloseOthers={closeOtherFileTabs}
              onCloseAll={closeAllFileTabs}
              onTouchSortingStart={setTouchSortingTabId}
              onTouchSortingEnd={handleTouchSortingEnd}
            />
          )
        })}
      </Reorder.Group>
      {canPreview && activeFileTabId && (
        <button
          type="button"
          onClick={() => toggleFileTabPreview(activeFileTabId)}
          className={cn(
            "flex w-10 shrink-0 items-center justify-center border-b border-border/55 transition-colors hover:bg-primary/8",
            isPreviewActive && "text-primary"
          )}
          aria-label={isPreviewActive ? t("editSource") : t("preview")}
          title={isPreviewActive ? t("editSource") : t("preview")}
        >
          <AppleIcon
            name={
              isPreviewActive
                ? "file"
                : activeTab?.language === "html"
                  ? "external"
                  : "eye"
            }
            className="size-4"
          />
        </button>
      )}
      {!isMobile && mode === "fusion" && (
        <button
          type="button"
          onClick={toggleFilesMaximized}
          className={cn(
            "flex w-10 shrink-0 items-center justify-center border-b border-border/55 transition-colors hover:bg-primary/8",
            filesMaximized && "text-primary"
          )}
          aria-label={filesMaximized ? t("restore") : t("maximize")}
          aria-pressed={filesMaximized}
          title={filesMaximized ? t("restore") : t("maximize")}
        >
          <AppleIcon
            name={filesMaximized ? "minimize" : "maximize"}
            className="size-4"
          />
        </button>
      )}
    </div>
  )
}

interface FileWorkspaceTabItemProps {
  tab: FileWorkspaceTab
  active: boolean
  closeLabel: string
  closeText: string
  closeOthersText: string
  closeAllText: string
  isCoarsePointer: boolean
  isTouchSorting: boolean
  onSwitch: (tabId: string) => void
  onClose: (tabId: string) => void
  onCloseOthers: (tabId: string) => void
  onCloseAll: () => void
  onTouchSortingStart: (tabId: string) => void
  onTouchSortingEnd: () => void
}

const FileWorkspaceTabItem = memo(function FileWorkspaceTabItem({
  tab,
  active,
  closeLabel,
  closeText,
  closeOthersText,
  closeAllText,
  isCoarsePointer,
  isTouchSorting,
  onSwitch,
  onClose,
  onCloseOthers,
  onCloseAll,
  onTouchSortingStart,
  onTouchSortingEnd,
}: FileWorkspaceTabItemProps) {
  const isDiff = tab.kind === "diff" || tab.kind === "rich-diff"
  const isDirty = tab.kind === "file" && Boolean(tab.isDirty)

  const handleLongPressStart = useCallback(
    () => onTouchSortingStart(tab.id),
    [onTouchSortingStart, tab.id]
  )

  const { dragControls, gestureHandlers } = useLongPressDrag({
    enabled: isCoarsePointer,
    onStart: handleLongPressStart,
    onEnd: onTouchSortingEnd,
  })

  const handleSwitch = useCallback(() => {
    onSwitch(tab.id)
  }, [onSwitch, tab.id])

  const whileDrag = useMemo(() => ({ scale: 1.03 }), [])

  return (
    <Reorder.Item
      as="div"
      value={tab}
      data-file-tab-id={tab.id}
      drag="x"
      dragControls={dragControls}
      dragListener={!isCoarsePointer}
      whileDrag={whileDrag}
      {...gestureHandlers}
      className={cn(
        "shrink-0 cursor-grab rounded-[11px] active:cursor-grabbing",
        isTouchSorting &&
          "z-50 bg-background/95 opacity-95 ring-1 ring-primary/25"
      )}
    >
      <ContextMenu>
        <ContextMenuTrigger asChild disabled={isTouchSorting}>
          <div
            role="tab"
            aria-selected={active}
            onClick={handleSwitch}
            className={cn(
              "group/filetab relative flex h-full shrink-0 items-center gap-1.5 rounded-[11px] border px-3 text-xs",
              "cursor-pointer select-none transition-colors hover:bg-primary/8",
              active
                ? "border-primary/20 bg-background/90 text-foreground ring-1 ring-primary/10"
                : "border-transparent text-muted-foreground"
            )}
            title={tab.description ?? tab.title}
          >
            <AppleIcon name={isDiff ? "diff" : "file"} className="size-3.5" />
            <span className="truncate max-w-[180px]">
              {tab.title}
              {isDirty ? " *" : ""}
            </span>
            <button
              type="button"
              className={cn(
                "rounded-full p-0.5 transition-colors hover:bg-primary/10",
                active
                  ? "opacity-100"
                  : "opacity-0 group-hover/filetab:opacity-100"
              )}
              onClick={(event) => {
                event.stopPropagation()
                onClose(tab.id)
              }}
              aria-label={closeLabel}
            >
              <AppleIcon name="close" className="size-3" />
            </button>
          </div>
        </ContextMenuTrigger>
        <ContextMenuContent>
          <ContextMenuItem onSelect={() => onClose(tab.id)}>
            {closeText}
          </ContextMenuItem>
          <ContextMenuItem onSelect={() => onCloseOthers(tab.id)}>
            {closeOthersText}
          </ContextMenuItem>
          <ContextMenuSeparator />
          <ContextMenuItem onSelect={onCloseAll}>
            {closeAllText}
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>
    </Reorder.Item>
  )
})
