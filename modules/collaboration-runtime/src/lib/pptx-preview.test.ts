import JSZip from "jszip"
import { describe, expect, it } from "vitest"
import { parsePptxPreview } from "./pptx-preview"

describe("parsePptxPreview", () => {
  it("extracts slide text and related images from pptx xml", async () => {
    const zip = new JSZip()
    zip.file(
      "ppt/slides/slide1.xml",
      `<?xml version="1.0" encoding="UTF-8"?>
      <p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
        xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <p:cSld>
          <p:spTree>
            <p:sp><p:txBody><a:p><a:r><a:t>Quarterly Plan</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:txBody><a:p><a:r><a:t>Ship artifact preview</a:t></a:r></a:p></p:txBody></p:sp>
            <p:pic><p:blipFill><a:blip r:embed="rId2" /></p:blipFill></p:pic>
          </p:spTree>
        </p:cSld>
      </p:sld>`
    )
    zip.file(
      "ppt/slides/_rels/slide1.xml.rels",
      `<?xml version="1.0" encoding="UTF-8"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId2" Target="../media/image1.png" />
      </Relationships>`
    )
    zip.file("ppt/media/image1.png", Buffer.from("iVBORw0KGgo=", "base64"))

    const base64 = await zip.generateAsync({ type: "base64" })

    await expect(parsePptxPreview(base64)).resolves.toEqual({
      slides: [
        {
          index: 1,
          title: "Quarterly Plan",
          text: ["Quarterly Plan", "Ship artifact preview"],
          images: ["data:image/png;base64,iVBORw0KGgo="],
        },
      ],
    })
  })
})
