import JSZip from "jszip"

export interface PptxSlidePreview {
  index: number
  title: string
  text: string[]
  images: string[]
}

export interface PptxPreview {
  slides: PptxSlidePreview[]
}

const IMAGE_MIME_BY_EXTENSION: Record<string, string> = {
  gif: "image/gif",
  jpeg: "image/jpeg",
  jpg: "image/jpeg",
  png: "image/png",
  svg: "image/svg+xml",
  webp: "image/webp",
}

function slideNumber(path: string): number {
  const match = /\/slide(\d+)\.xml$/i.exec(path)
  return match ? Number(match[1]) : Number.MAX_SAFE_INTEGER
}

function parseXml(xml: string): Document {
  return new DOMParser().parseFromString(xml, "application/xml")
}

function xmlElements(doc: Document, localName: string): Element[] {
  return Array.from(doc.getElementsByTagName("*")).filter(
    (element) => element.localName === localName
  )
}

function slideText(doc: Document): string[] {
  const seen = new Set<string>()
  const lines: string[] = []

  for (const textNode of xmlElements(doc, "t")) {
    const text = textNode.textContent?.replace(/\s+/g, " ").trim()
    if (!text || seen.has(text)) continue
    seen.add(text)
    lines.push(text)
  }

  return lines
}

function relationshipTargets(doc: Document): Map<string, string> {
  const targets = new Map<string, string>()
  for (const rel of xmlElements(doc, "Relationship")) {
    const id = rel.getAttribute("Id")
    const target = rel.getAttribute("Target")
    if (id && target) targets.set(id, target)
  }
  return targets
}

function mediaPathFromTarget(target: string): string {
  const clean = target.replace(/^\/+/, "")
  if (clean.startsWith("ppt/")) return clean
  return `ppt/${clean.replace(/^\.\.\//, "")}`
}

function dataUrlForMediaPath(path: string, base64: string): string | null {
  const ext = path.split(".").pop()?.toLowerCase() ?? ""
  const mime = IMAGE_MIME_BY_EXTENSION[ext]
  if (!mime) return null
  return `data:${mime};base64,${base64}`
}

async function slideImages(
  zip: JSZip,
  slideDoc: Document,
  relsPath: string
): Promise<string[]> {
  const relsFile = zip.file(relsPath)
  if (!relsFile) return []

  const relsDoc = parseXml(await relsFile.async("text"))
  const targets = relationshipTargets(relsDoc)
  const imageIds = new Set<string>()

  for (const blip of xmlElements(slideDoc, "blip")) {
    const id = blip.getAttribute("r:embed") ?? blip.getAttribute("embed")
    if (id) imageIds.add(id)
  }

  const images: string[] = []
  for (const id of imageIds) {
    const target = targets.get(id)
    if (!target) continue
    const mediaPath = mediaPathFromTarget(target)
    const mediaFile = zip.file(mediaPath)
    if (!mediaFile) continue
    const dataUrl = dataUrlForMediaPath(
      mediaPath,
      await mediaFile.async("base64")
    )
    if (dataUrl) images.push(dataUrl)
  }

  return images
}

export async function parsePptxPreview(base64: string): Promise<PptxPreview> {
  const zip = await JSZip.loadAsync(base64, { base64: true })
  const slideFiles = Object.values(zip.files)
    .filter(
      (file) => !file.dir && /^ppt\/slides\/slide\d+\.xml$/i.test(file.name)
    )
    .sort((a, b) => slideNumber(a.name) - slideNumber(b.name))

  const slides: PptxSlidePreview[] = []
  for (const [idx, file] of slideFiles.entries()) {
    const xml = await file.async("text")
    const doc = parseXml(xml)
    const text = slideText(doc)
    const number = slideNumber(file.name)
    const relsPath = `ppt/slides/_rels/slide${number}.xml.rels`
    slides.push({
      index: idx + 1,
      title: text[0] ?? `Slide ${idx + 1}`,
      text,
      images: await slideImages(zip, doc, relsPath),
    })
  }

  return { slides }
}
