export const ARCHIPELAGO_WS_PROTOCOL = "archipelago-events"
const ARCHIPELAGO_WS_TOKEN_PROTOCOL_PREFIX = "archipelago-token."

function base64UrlEncode(value: string): string {
  const bytes = new TextEncoder().encode(value)
  let binary = ""
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "")
}

export function buildArchipelagoWebSocketProtocols(token: string): string[] {
  const trimmed = token.trim()
  if (!trimmed) return [ARCHIPELAGO_WS_PROTOCOL]
  return [
    ARCHIPELAGO_WS_PROTOCOL,
    `${ARCHIPELAGO_WS_TOKEN_PROTOCOL_PREFIX}${base64UrlEncode(trimmed)}`,
  ]
}
