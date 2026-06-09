export type TransportEnvironment = "tauri" | "web"

const ISLAND_EMBEDDED_WEBVIEW_KEY = "archipelago_island_embedded"

export function detectEnvironment(): TransportEnvironment {
  if (typeof window !== "undefined" && "__TAURI_INTERNALS__" in window) {
    return "tauri"
  }
  return "web"
}

export function isIslandEmbeddedWebView(): boolean {
  if (typeof window === "undefined") return false
  try {
    return localStorage.getItem(ISLAND_EMBEDDED_WEBVIEW_KEY) === "true"
  } catch {
    return false
  }
}
