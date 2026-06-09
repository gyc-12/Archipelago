"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { toast } from "sonner"
import { AppleIcon, type AppleIconName } from "@/components/apple/apple-icon"
import {
  AppleIconTile,
  type AppleIconTone,
} from "@/components/apple/apple-icon-tile"
import { UnifiedDiffPreview } from "@/components/diff/unified-diff-preview"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useActiveFolder } from "@/contexts/active-folder-context"
import { useTabContext } from "@/contexts/tab-context"
import { useWorkspaceContext } from "@/contexts/workspace-context"
import { readFileBase64, readFilePreview } from "@/lib/api"
import type { DetectedArtifact, ArtifactKind } from "@/lib/artifact-detection"
import { parsePptxPreview, type PptxPreview } from "@/lib/pptx-preview"
import { emitAppendTextToSession } from "@/lib/session-attachment-events"
import { cn } from "@/lib/utils"

type PreviewState =
  | { status: "idle"; content: string | null; imageSrc: string | null }
  | { status: "loading"; content: string | null; imageSrc: string | null }
  | {
      status: "error"
      message: string
      content: string | null
      imageSrc: string | null
    }

const KIND_META: Record<
  ArtifactKind,
  { label: string; icon: AppleIconName; tone: AppleIconTone }
> = {
  code: { label: "Code", icon: "file", tone: "indigo" },
  document: { label: "Document", icon: "fileSearch", tone: "blue" },
  image: { label: "Image", icon: "image", tone: "green" },
  web: { label: "Web", icon: "globe", tone: "purple" },
  presentation: { label: "PPT", icon: "play", tone: "orange" },
  diff: { label: "Diff", icon: "diff", tone: "slate" },
}

function normalizePath(path: string): string {
  return path.replace(/\\/g, "/").replace(/^\.\/+/, "")
}

function toWorkspaceRelativePath(
  path: string,
  workspacePath: string | null
): string {
  const normalized = normalizePath(path)
  if (!workspacePath) return normalized
  const workspace = normalizePath(workspacePath).replace(/\/+$/, "")
  if (normalized.startsWith(`${workspace}/`)) {
    return normalized.slice(workspace.length + 1)
  }
  return normalized
}

function absolutePath(path: string, workspacePath: string | null): string {
  const normalized = normalizePath(path)
  if (normalized.startsWith("/") || /^[a-zA-Z]:\//.test(normalized)) {
    return normalized
  }
  if (!workspacePath) return normalized
  return `${workspacePath.replace(/\/+$/, "")}/${normalized}`
}

function fileExtension(value: string): string {
  const clean = value.split(/[?#]/, 1)[0] ?? value
  return clean.split(".").pop()?.toLowerCase() ?? ""
}

function isImagePath(value: string): boolean {
  return ["png", "jpg", "jpeg", "gif", "webp", "svg"].includes(
    fileExtension(value)
  )
}

function buildLocalEditPrompt(
  artifact: DetectedArtifact,
  selected: string
): string {
  const target = artifact.path ?? artifact.url ?? artifact.title
  return [
    "请对下面选中的产物局部内容做修改：",
    "",
    `Artifact: ${target}`,
    "",
    "```",
    selected,
    "```",
    "",
    "修改要求：",
  ].join("\n")
}

export function ArtifactPreviewCard({
  artifact,
}: {
  artifact: DetectedArtifact
}) {
  const { activeFolder } = useActiveFolder()
  const workspacePath = activeFolder?.path ?? null
  const {
    activateConversationPane,
    openFilePreview,
    openSessionFileDiff,
    openWorkingTreeDiff,
    toggleFilesMaximized,
  } = useWorkspaceContext()
  const { activeTabId } = useTabContext()
  const [open, setOpen] = useState(false)
  const [tab, setTab] = useState("preview")
  const [preview, setPreview] = useState<PreviewState>({
    status: "idle",
    content: null,
    imageSrc: null,
  })
  const [pptxPreview, setPptxPreview] = useState<PptxPreview | null>(null)
  const [activeSlideIndex, setActiveSlideIndex] = useState(0)

  const meta = KIND_META[artifact.kind]
  const relativePath = artifact.path
    ? toWorkspaceRelativePath(artifact.path, workspacePath)
    : null
  const targetLabel = artifact.url ?? relativePath ?? "Inline artifact"
  const canOpenWorkspaceFile = Boolean(relativePath && artifact.kind !== "diff")
  const canOpenDiff = artifact.kind === "diff" || Boolean(relativePath)

  useEffect(() => {
    if (!open || !relativePath || artifact.url || artifact.diffText) return
    let cancelled = false

    const load = async () => {
      await Promise.resolve()
      if (cancelled) return
      setPreview({ status: "loading", content: null, imageSrc: null })
      setPptxPreview(null)
      try {
        if (artifact.kind === "image" || isImagePath(relativePath)) {
          const b64 = await readFileBase64(
            absolutePath(relativePath, workspacePath)
          )
          if (cancelled) return
          const ext = fileExtension(relativePath)
          const mime =
            ext === "svg"
              ? "image/svg+xml"
              : ext === "webp"
                ? "image/webp"
                : ext === "gif"
                  ? "image/gif"
                  : ext === "jpg" || ext === "jpeg"
                    ? "image/jpeg"
                    : "image/png"
          setPreview({
            status: "idle",
            content: null,
            imageSrc: `data:${mime};base64,${b64}`,
          })
          return
        }

        if (artifact.kind === "presentation") {
          const b64 = await readFileBase64(
            absolutePath(relativePath, workspacePath),
            50_000_000
          )
          if (cancelled) return
          const parsed = await parsePptxPreview(b64)
          if (cancelled) return
          setActiveSlideIndex(0)
          setPptxPreview(parsed)
          setPreview({ status: "idle", content: null, imageSrc: null })
          return
        }

        if (!workspacePath) {
          setPreview({
            status: "error",
            message: "No active workspace is available.",
            content: null,
            imageSrc: null,
          })
          return
        }

        const result = await readFilePreview(workspacePath, relativePath)
        if (cancelled) return
        setPreview({ status: "idle", content: result.content, imageSrc: null })
      } catch (error) {
        if (cancelled) return
        setPreview({
          status: "error",
          message: error instanceof Error ? error.message : String(error),
          content: null,
          imageSrc: null,
        })
      }
    }

    void load()
    return () => {
      cancelled = true
    }
  }, [
    artifact.diffText,
    artifact.kind,
    artifact.url,
    open,
    relativePath,
    workspacePath,
  ])

  const previewBody = useMemo(() => {
    if (artifact.url) {
      return (
        <iframe
          src={artifact.url}
          className="h-full min-h-[520px] w-full rounded-[10px] border border-border/60 bg-white"
          title={artifact.title}
        />
      )
    }

    if (artifact.diffText) {
      return (
        <div className="h-full overflow-hidden rounded-[10px] border border-border/60">
          <UnifiedDiffPreview diffText={artifact.diffText} clickableFilePath />
        </div>
      )
    }

    if (artifact.kind === "presentation") {
      if (preview.status === "loading") {
        return (
          <div className="flex h-full min-h-[420px] items-center justify-center text-sm text-muted-foreground">
            Loading presentation...
          </div>
        )
      }

      if (preview.status === "error") {
        return (
          <div className="flex h-full min-h-[420px] items-center justify-center p-6 text-sm text-muted-foreground">
            {preview.message}
          </div>
        )
      }

      if (!pptxPreview?.slides.length) {
        return (
          <div className="flex h-full min-h-[420px] items-center justify-center p-6 text-sm text-muted-foreground">
            No slides found in this presentation.
          </div>
        )
      }

      const safeSlideIndex = Math.min(
        activeSlideIndex,
        pptxPreview.slides.length - 1
      )
      const activeSlide = pptxPreview.slides[safeSlideIndex]

      return (
        <div className="flex h-full min-h-[420px] flex-col bg-muted/20">
          <div className="flex items-center gap-2 border-b border-border/50 px-4 py-2 text-xs text-muted-foreground">
            <AppleIcon name="play" className="size-4" />
            <span>
              Presentation browser · {pptxPreview.slides.length} slides
            </span>
          </div>
          <div className="grid flex-1 grid-cols-[160px_1fr] min-h-0">
            <div className="space-y-2 overflow-auto border-r border-border/50 p-3">
              {pptxPreview.slides.map((slide, index) => (
                <button
                  type="button"
                  key={slide.index}
                  onClick={() => setActiveSlideIndex(index)}
                  className={cn(
                    "aspect-video w-full rounded-[8px] border bg-background p-2 text-left text-[11px] transition-colors",
                    index === safeSlideIndex
                      ? "border-primary/45 text-foreground ring-2 ring-primary/15"
                      : "border-border/60 text-muted-foreground hover:bg-primary/8"
                  )}
                >
                  <div className="mb-1 font-medium">Slide {slide.index}</div>
                  <div className="line-clamp-3">{slide.title}</div>
                </button>
              ))}
            </div>
            <div className="flex min-w-0 items-center justify-center overflow-auto p-6">
              <div className="aspect-video w-full max-w-4xl overflow-hidden rounded-[10px] border border-border/70 bg-background shadow-sm">
                <div className="flex h-full">
                  <div className="min-w-0 flex-1 overflow-auto p-8">
                    <div className="mb-4 text-xs font-medium uppercase tracking-[0.12em] text-muted-foreground">
                      Slide {activeSlide.index}
                    </div>
                    <div className="space-y-3">
                      {activeSlide.text.length > 0 ? (
                        activeSlide.text.map((line, index) => (
                          <p
                            key={`${activeSlide.index}-${index}-${line}`}
                            className={cn(
                              "leading-snug",
                              index === 0
                                ? "text-2xl font-semibold text-foreground"
                                : "text-sm text-foreground/80"
                            )}
                          >
                            {line}
                          </p>
                        ))
                      ) : (
                        <p className="text-sm text-muted-foreground">
                          This slide has no extracted text.
                        </p>
                      )}
                    </div>
                  </div>
                  {activeSlide.images.length > 0 && (
                    <div className="flex w-[38%] min-w-48 flex-col gap-3 overflow-auto border-l border-border/55 bg-muted/15 p-4">
                      {activeSlide.images.map((src, index) => (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          key={`${activeSlide.index}-image-${index}`}
                          src={src}
                          alt={`Slide ${activeSlide.index} image ${index + 1}`}
                          className="max-h-40 w-full rounded-[8px] border border-border/55 bg-white object-contain"
                        />
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )
    }

    if (preview.status === "loading") {
      return (
        <div className="flex h-full min-h-[420px] items-center justify-center text-sm text-muted-foreground">
          Loading preview...
        </div>
      )
    }

    if (preview.status === "error") {
      return (
        <div className="flex h-full min-h-[420px] items-center justify-center p-6 text-sm text-muted-foreground">
          {preview.message}
        </div>
      )
    }

    if (preview.imageSrc) {
      return (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={preview.imageSrc}
          alt={artifact.title}
          className="h-full max-h-[70dvh] w-full rounded-[10px] object-contain"
        />
      )
    }

    if (artifact.kind === "web" && preview.content) {
      return (
        <iframe
          srcDoc={preview.content}
          className="h-full min-h-[520px] w-full rounded-[10px] border border-border/60 bg-white"
          title={artifact.title}
        />
      )
    }

    return (
      <pre className="h-full min-h-[420px] overflow-auto rounded-[10px] border border-border/60 bg-muted/20 p-4 text-xs">
        {preview.content ?? targetLabel}
      </pre>
    )
  }, [activeSlideIndex, artifact, pptxPreview, preview, targetLabel])

  const handleOpenWorkspace = useCallback(() => {
    if (!relativePath) return
    void openFilePreview(relativePath)
    setOpen(false)
  }, [openFilePreview, relativePath])

  const handleOpenFullscreen = useCallback(() => {
    if (relativePath && artifact.kind !== "diff") {
      void openFilePreview(relativePath)
      toggleFilesMaximized()
      setOpen(false)
      return
    }
    setOpen(true)
  }, [artifact.kind, openFilePreview, relativePath, toggleFilesMaximized])

  const handleOpenDiff = useCallback(() => {
    if (artifact.diffText) {
      openSessionFileDiff(
        relativePath ?? "artifact.diff",
        artifact.diffText,
        "Artifact"
      )
      setOpen(false)
      return
    }
    if (relativePath) {
      void openWorkingTreeDiff(relativePath, { mode: "auto" })
      setOpen(false)
    }
  }, [
    artifact.diffText,
    openSessionFileDiff,
    openWorkingTreeDiff,
    relativePath,
  ])

  const handleLocalEdit = useCallback(() => {
    const selected =
      typeof window !== "undefined"
        ? (window.getSelection()?.toString() ?? "")
        : ""
    const source =
      selected.trim() ||
      preview.content?.slice(0, 2400) ||
      artifact.diffText?.slice(0, 2400) ||
      targetLabel
    emitAppendTextToSession({
      tabId: activeTabId,
      text: buildLocalEditPrompt(artifact, source),
    })
    activateConversationPane()
    toast.success("Local edit context added to chat")
    setOpen(false)
  }, [
    activateConversationPane,
    activeTabId,
    artifact,
    preview.content,
    targetLabel,
  ])

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={cn(
          "group mt-2 flex w-full max-w-2xl items-center gap-3 rounded-[12px] border border-border/60 bg-background/75 p-3 text-left transition-colors",
          "hover:border-primary/35 hover:bg-primary/5"
        )}
      >
        <AppleIconTile name={meta.icon} tone={meta.tone} className="size-8" />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className="truncate text-sm font-medium">
              {artifact.title}
            </span>
            <span className="shrink-0 rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground">
              {meta.label}
            </span>
          </div>
          <div className="mt-0.5 truncate text-xs text-muted-foreground">
            {targetLabel}
          </div>
        </div>
        <AppleIcon
          name="maximize"
          className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-foreground"
        />
      </button>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="h-[calc(100dvh-2rem)] max-w-[calc(100vw-2rem)] gap-3 p-4">
          <DialogHeader className="pr-12">
            <div className="flex items-center gap-2">
              <AppleIconTile
                name={meta.icon}
                tone={meta.tone}
                className="size-8"
              />
              <div className="min-w-0">
                <DialogTitle className="truncate text-base">
                  {artifact.title}
                </DialogTitle>
                <DialogDescription className="truncate">
                  {targetLabel}
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="flex flex-wrap gap-2">
            {canOpenWorkspaceFile && (
              <Button
                size="sm"
                variant="secondary"
                onClick={handleOpenWorkspace}
              >
                <AppleIcon name="edit" className="size-4" />
                Editor
              </Button>
            )}
            <Button
              size="sm"
              variant="secondary"
              onClick={handleOpenFullscreen}
            >
              <AppleIcon name="maximize" className="size-4" />
              Fullscreen
            </Button>
            {canOpenDiff && (
              <Button size="sm" variant="secondary" onClick={handleOpenDiff}>
                <AppleIcon name="diff" className="size-4" />
                Diff
              </Button>
            )}
            <Button size="sm" variant="secondary" onClick={handleLocalEdit}>
              <AppleIcon name="chat" className="size-4" />
              Modify
            </Button>
          </div>

          <Tabs value={tab} onValueChange={setTab} className="min-h-0 flex-1">
            <TabsList>
              <TabsTrigger value="preview">Preview</TabsTrigger>
              <TabsTrigger value="history">History</TabsTrigger>
              <TabsTrigger value="diff">Diff</TabsTrigger>
            </TabsList>
            <TabsContent value="preview" className="min-h-0 overflow-hidden">
              {previewBody}
            </TabsContent>
            <TabsContent value="history" className="min-h-0 overflow-auto">
              <div className="space-y-2 rounded-[10px] border border-border/60 bg-muted/20 p-3 text-sm">
                <div className="font-medium">Version history</div>
                <div className="rounded-[8px] border border-border/50 bg-background p-3">
                  Current artifact reference from this reply
                </div>
                {relativePath && (
                  <button
                    type="button"
                    onClick={() => {
                      void openWorkingTreeDiff(relativePath, {
                        mode: "overview",
                      })
                    }}
                    className="flex w-full items-center justify-between rounded-[8px] border border-border/50 bg-background p-3 text-left hover:bg-primary/5"
                  >
                    <span>Workspace working-tree version</span>
                    <AppleIcon name="diff" className="size-4" />
                  </button>
                )}
                {artifact.diffText && (
                  <div className="rounded-[8px] border border-border/50 bg-background p-3">
                    Inline diff snapshot
                  </div>
                )}
              </div>
            </TabsContent>
            <TabsContent value="diff" className="min-h-0 overflow-hidden">
              {artifact.diffText ? (
                <UnifiedDiffPreview
                  diffText={artifact.diffText}
                  clickableFilePath
                />
              ) : relativePath ? (
                <div className="flex h-full min-h-[420px] items-center justify-center">
                  <Button onClick={handleOpenDiff}>
                    <AppleIcon name="diff" className="size-4" />
                    Open working diff
                  </Button>
                </div>
              ) : (
                <div className="flex h-full min-h-[420px] items-center justify-center text-sm text-muted-foreground">
                  No diff source is available.
                </div>
              )}
            </TabsContent>
          </Tabs>
        </DialogContent>
      </Dialog>
    </>
  )
}
