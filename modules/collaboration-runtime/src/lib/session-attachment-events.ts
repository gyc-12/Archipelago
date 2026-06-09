export const ATTACH_FILE_TO_SESSION_EVENT = "archipelago:attach-file-to-session"

export interface AttachFileToSessionDetail {
  tabId: string
  path: string
}

export function emitAttachFileToSession(
  detail: AttachFileToSessionDetail
): void {
  if (typeof window === "undefined") return
  window.dispatchEvent(
    new CustomEvent<AttachFileToSessionDetail>(ATTACH_FILE_TO_SESSION_EVENT, {
      detail,
    })
  )
}

export const APPEND_TEXT_TO_SESSION_EVENT = "archipelago:append-text-to-session"

export interface AppendTextToSessionDetail {
  tabId?: string | null
  text: string
}

export function emitAppendTextToSession(
  detail: AppendTextToSessionDetail
): void {
  if (typeof window === "undefined") return
  window.dispatchEvent(
    new CustomEvent<AppendTextToSessionDetail>(APPEND_TEXT_TO_SESSION_EVENT, {
      detail,
    })
  )
}
