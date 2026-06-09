import { afterEach, beforeEach, describe, expect, it } from "vitest"

import { detectEnvironment, isIslandEmbeddedWebView } from "./detect"

describe("detectEnvironment", () => {
  // jsdom-provided `window` is the only global we tinker with. Snapshot the
  // original `__TAURI_INTERNALS__` (likely undefined) and restore in afterEach.
  let hadInternals: boolean
  let originalInternals: unknown
  const windowRecord = () => window as unknown as Record<string, unknown>

  beforeEach(() => {
    hadInternals = "__TAURI_INTERNALS__" in window
    originalInternals = windowRecord().__TAURI_INTERNALS__
  })

  afterEach(() => {
    const w = windowRecord()
    if (hadInternals) {
      w.__TAURI_INTERNALS__ = originalInternals
    } else {
      delete w.__TAURI_INTERNALS__
    }
    localStorage.clear()
  })

  it("returns 'web' by default in jsdom", () => {
    const w = windowRecord()
    delete w.__TAURI_INTERNALS__
    expect(detectEnvironment()).toBe("web")
  })

  it("returns 'tauri' when __TAURI_INTERNALS__ is present", () => {
    windowRecord().__TAURI_INTERNALS__ = {
      invoke: () => {},
    }
    expect(detectEnvironment()).toBe("tauri")
  })

  it("detects the Island embedded webview marker", () => {
    expect(isIslandEmbeddedWebView()).toBe(false)
    localStorage.setItem("archipelago_island_embedded", "true")
    expect(isIslandEmbeddedWebView()).toBe(true)
  })
})
