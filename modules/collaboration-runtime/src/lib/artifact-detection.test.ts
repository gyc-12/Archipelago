import { describe, expect, it } from "vitest"
import { extractArtifactsFromText } from "./artifact-detection"

describe("extractArtifactsFromText", () => {
  it("detects markdown links, local paths, urls, and diff fences", () => {
    const artifacts = extractArtifactsFromText(`
See [app](src/app/page.tsx), ./docs/spec.md, and https://example.com/demo.

\`\`\`diff
diff --git a/a.ts b/a.ts
@@ -1 +1 @@
-old
+new
\`\`\`
`)

    expect(artifacts.map((artifact) => artifact.kind)).toEqual(
      expect.arrayContaining(["code", "diff", "document", "web"])
    )
    expect(
      artifacts.some((artifact) => artifact.path === "src/app/page.tsx")
    ).toBe(true)
    expect(
      artifacts.some((artifact) => artifact.path === "./docs/spec.md")
    ).toBe(true)
    expect(
      artifacts.some((artifact) => artifact.url === "https://example.com/demo")
    ).toBe(true)
  })

  it("dedupes repeated artifact references", () => {
    const artifacts = extractArtifactsFromText(
      "[one](src/app.ts) and src/app.ts and `src/app.ts`"
    )

    expect(artifacts).toHaveLength(1)
    expect(artifacts[0]?.path).toBe("src/app.ts")
  })

  it("classifies images, web files, presentations, and patches", () => {
    const artifacts = extractArtifactsFromText(
      "assets/hero.png public/index.html deck/demo.pptx changes.patch"
    )

    expect(artifacts.map((artifact) => artifact.kind)).toEqual([
      "image",
      "web",
      "presentation",
      "diff",
    ])
  })

  it("detects html paths in Chinese assistant prose with inline code", () => {
    const artifacts = extractArtifactsFromText(
      "已创建 `public/artifact-demo.html`，包含居中布局的标题、按钮和 CSS 样式。"
    )

    expect(artifacts).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: "web",
          path: "public/artifact-demo.html",
        }),
      ])
    )
  })
})
