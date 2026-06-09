export type ArtifactKind =
  | "code"
  | "document"
  | "image"
  | "web"
  | "presentation"
  | "diff"

export interface DetectedArtifact {
  id: string
  kind: ArtifactKind
  title: string
  path: string | null
  url: string | null
  diffText: string | null
  source: "link" | "path" | "diff"
}

const IMAGE_EXTENSIONS = new Set(["png", "jpg", "jpeg", "gif", "webp", "svg"])
const WEB_EXTENSIONS = new Set(["html", "htm"])
const PRESENTATION_EXTENSIONS = new Set(["ppt", "pptx", "key"])
const DOCUMENT_EXTENSIONS = new Set([
  "md",
  "mdx",
  "txt",
  "pdf",
  "doc",
  "docx",
  "rtf",
])
const DIFF_EXTENSIONS = new Set(["diff", "patch"])
const CODE_EXTENSIONS = new Set([
  "c",
  "cc",
  "cpp",
  "cs",
  "css",
  "go",
  "java",
  "js",
  "jsx",
  "json",
  "kt",
  "mjs",
  "py",
  "rb",
  "rs",
  "scss",
  "sh",
  "swift",
  "toml",
  "ts",
  "tsx",
  "vue",
  "xml",
  "yaml",
  "yml",
])

const ARTIFACT_EXTENSIONS = new Set([
  ...IMAGE_EXTENSIONS,
  ...WEB_EXTENSIONS,
  ...PRESENTATION_EXTENSIONS,
  ...DOCUMENT_EXTENSIONS,
  ...DIFF_EXTENSIONS,
  ...CODE_EXTENSIONS,
])

function stableHash(input: string): string {
  let hash = 5381
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 33) ^ input.charCodeAt(i)
  }
  return (hash >>> 0).toString(36)
}

function extensionFor(value: string): string {
  const withoutQuery = value.split(/[?#]/, 1)[0] ?? value
  const match = withoutQuery.match(/\.([a-zA-Z0-9]+)$/)
  return match?.[1]?.toLowerCase() ?? ""
}

function fileName(value: string): string {
  const withoutQuery = value.split(/[?#]/, 1)[0] ?? value
  return withoutQuery.split(/[\\/]/).pop() || value
}

function stripTrailingLineSuffix(value: string): string {
  if (/^https?:\/\//i.test(value)) return value
  return value.replace(/:(\d+)(?::\d+)?$/, "")
}

function artifactKindFor(value: string, isUrl: boolean): ArtifactKind | null {
  if (isUrl) return "web"
  const ext = extensionFor(value)
  if (!ext || !ARTIFACT_EXTENSIONS.has(ext)) return null
  if (IMAGE_EXTENSIONS.has(ext)) return "image"
  if (WEB_EXTENSIONS.has(ext)) return "web"
  if (PRESENTATION_EXTENSIONS.has(ext)) return "presentation"
  if (DIFF_EXTENSIONS.has(ext)) return "diff"
  if (DOCUMENT_EXTENSIONS.has(ext)) return "document"
  return "code"
}

function pushArtifact(
  artifacts: DetectedArtifact[],
  seen: Set<string>,
  candidate: {
    kind: ArtifactKind
    title: string
    path?: string | null
    url?: string | null
    diffText?: string | null
    source: DetectedArtifact["source"]
  }
) {
  const identity =
    candidate.url ??
    candidate.path ??
    (candidate.diffText ? stableHash(candidate.diffText) : candidate.title)
  const key = `${candidate.kind}:${identity}`
  if (seen.has(key)) return
  seen.add(key)
  artifacts.push({
    id: `${candidate.kind}-${stableHash(identity)}`,
    kind: candidate.kind,
    title: candidate.title,
    path: candidate.path ?? null,
    url: candidate.url ?? null,
    diffText: candidate.diffText ?? null,
    source: candidate.source,
  })
}

function isHttpUrl(value: string): boolean {
  return /^https?:\/\//i.test(value)
}

function shouldIgnorePath(value: string): boolean {
  if (!value || value.length > 260) return true
  if (value.startsWith("data:") || value.startsWith("blob:")) return true
  return false
}

export function extractArtifactsFromText(text: string): DetectedArtifact[] {
  const artifacts: DetectedArtifact[] = []
  const seen = new Set<string>()
  const textWithoutDiffFences = text.replace(
    /```(?:diff|patch)\s*\n[\s\S]*?```/gi,
    " "
  )

  const diffFenceRegex = /```(?:diff|patch)\s*\n([\s\S]*?)```/gi
  for (const match of text.matchAll(diffFenceRegex)) {
    const diffText = match[1]?.trim()
    if (!diffText) continue
    pushArtifact(artifacts, seen, {
      kind: "diff",
      title: "Diff",
      diffText,
      source: "diff",
    })
  }

  if (
    artifacts.length === 0 &&
    (/^diff --git /m.test(text) || text.includes("*** Begin Patch"))
  ) {
    pushArtifact(artifacts, seen, {
      kind: "diff",
      title: "Diff",
      diffText: text.trim(),
      source: "diff",
    })
  }

  const markdownLinkRegex =
    /!?\[([^\]\n]{0,120})\]\(([^)\s]+)(?:\s+["'][^"']*["'])?\)/g
  for (const match of textWithoutDiffFences.matchAll(markdownLinkRegex)) {
    const label = match[1]?.trim()
    const rawTarget = match[2]?.trim()
    if (!rawTarget || shouldIgnorePath(rawTarget)) continue
    const isUrl = isHttpUrl(rawTarget)
    const target = stripTrailingLineSuffix(rawTarget)
    const kind = artifactKindFor(target, isUrl)
    if (!kind) continue
    pushArtifact(artifacts, seen, {
      kind,
      title: label || fileName(target),
      path: isUrl ? null : target.replace(/^file:\/\//i, ""),
      url: isUrl ? target : null,
      source: "link",
    })
  }

  const bareUrlRegex = /https?:\/\/[^\s"'`<>)]+/gi
  for (const match of textWithoutDiffFences.matchAll(bareUrlRegex)) {
    const rawUrl = match[0]?.replace(/[.,;:!?]+$/, "")
    if (!rawUrl) continue
    pushArtifact(artifacts, seen, {
      kind: "web",
      title: fileName(rawUrl) || rawUrl,
      url: rawUrl,
      source: "link",
    })
  }

  const pathRegex =
    /(?:^|[\s"'`(])((?:(?:\.{1,2}\/|\/|[A-Za-z0-9_.@+-]+\/)?[A-Za-z0-9_.@+~-]+(?:\/[A-Za-z0-9_.@+~-]+)*\.[A-Za-z0-9]+)(?::\d+(?::\d+)?)?)(?=$|[\s"'`),\]])/g
  for (const match of textWithoutDiffFences.matchAll(pathRegex)) {
    const rawPath = match[1]?.trim()
    if (!rawPath || shouldIgnorePath(rawPath)) continue
    const path = stripTrailingLineSuffix(rawPath)
    const kind = artifactKindFor(path, false)
    if (!kind) continue
    pushArtifact(artifacts, seen, {
      kind,
      title: fileName(path),
      path,
      source: "path",
    })
  }

  return artifacts.slice(0, 8)
}
