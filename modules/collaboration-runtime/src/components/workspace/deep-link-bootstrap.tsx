"use client"

import { useCallback, useEffect, useRef } from "react"
import { toast } from "sonner"
import { useAppWorkspace } from "@/contexts/app-workspace-context"
import { useTabContext } from "@/contexts/tab-context"
import type { AgentType } from "@/lib/types"

function isTauriDesktop(): boolean {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window
}

/**
 * Parses deep-link query parameters and navigates to the target conversation.
 * Shared between window.location.search (web) and archipelago:// URL scheme (Tauri).
 */
function parseDeepLinkParams(params: URLSearchParams) {
  const rawFolderId = params.get("folderId")
  const rawConversationId = params.get("conversationId")
  const rawAgent = params.get("agent") as AgentType | null
  return { rawFolderId, rawConversationId, rawAgent }
}

/**
 * Handles `/workspace?folderId=X&conversationId=Y&agent=Z` URLs (web mode)
 * and `archipelago://workspace?folderId=X&conversationId=Y&agent=Z` deep links (Tauri desktop).
 * The window.location.search handler runs once after hydration.
 * The Tauri deep-link listener stays active for the lifetime of the component.
 */
export function DeepLinkBootstrap() {
  const {
    foldersHydrated,
    folders,
    addFolderToWorkspaceById,
    conversations,
    setActiveFolderId,
  } = useAppWorkspace()
  const { tabsHydrated, openTab } = useTabContext()
  const ranRef = useRef(false)

  const handleDeepLinkParams = useCallback(
    async (params: URLSearchParams) => {
      const { rawFolderId, rawConversationId, rawAgent } =
        parseDeepLinkParams(params)

      if (!rawFolderId && !rawConversationId) return

      const folderId = rawFolderId ? Number(rawFolderId) : null

      if (folderId == null || !Number.isFinite(folderId)) return

      // Ensure folder is in the workspace
      let folder = folders.find((f) => f.id === folderId)
      if (!folder) {
        try {
          folder = await addFolderToWorkspaceById(folderId)
        } catch (err) {
          console.error("[DeepLinkBootstrap] open folder failed:", err)
          toast.error("Unable to open linked folder")
          return
        }
      }

      // If only folderId is provided (no conversationId/agent), navigate to
      // the folder without opening a specific conversation tab.
      const conversationId = rawConversationId
        ? Number(rawConversationId)
        : null
      if (
        conversationId == null ||
        !Number.isFinite(conversationId) ||
        !rawAgent
      ) {
        setActiveFolderId(folderId)
        return
      }

      const hasConv = conversations.some(
        (c) =>
          c.id === conversationId &&
          c.folder_id === folderId &&
          c.agent_type === rawAgent
      )
      if (!hasConv) {
        // Conversation not found — fall back to showing the folder
        setActiveFolderId(folderId)
        return
      }

      openTab(folderId, conversationId, rawAgent, true)
    },
    [
      folders,
      conversations,
      addFolderToWorkspaceById,
      openTab,
      setActiveFolderId,
    ]
  )

  // Handle initial window.location.search deep link (runs once after hydration)
  useEffect(() => {
    if (ranRef.current) return
    if (!foldersHydrated || !tabsHydrated) return
    ranRef.current = true

    if (typeof window === "undefined") return

    const params = new URLSearchParams(window.location.search)
    const { rawFolderId, rawConversationId } = parseDeepLinkParams(params)

    if (!rawFolderId && !rawConversationId) return

    const clearUrl = () => {
      try {
        window.history.replaceState({}, "", "/workspace")
      } catch {
        /* ignore */
      }
    }

    void (async () => {
      try {
        await handleDeepLinkParams(params)
      } finally {
        clearUrl()
      }
    })()
  }, [foldersHydrated, tabsHydrated, handleDeepLinkParams])

  // Listen for Tauri deep-link events (archipelago:// URL scheme)
  useEffect(() => {
    if (!isTauriDesktop()) return
    if (!foldersHydrated || !tabsHydrated) return

    let unlisten: (() => void) | undefined

    async function setupDeepLinkListener() {
      try {
        const { onOpenUrl, getCurrent } =
          await import("@tauri-apps/plugin-deep-link")

        // Check if app was launched via a deep link
        const startUrls = await getCurrent()
        if (startUrls && startUrls.length > 0) {
          for (const urlStr of startUrls) {
            try {
              const url = new URL(urlStr)
              await handleDeepLinkParams(url.searchParams)
            } catch (err) {
              console.error("[DeepLinkBootstrap] parse start URL failed:", err)
            }
          }
        }

        // Listen for deep-link URLs while running
        unlisten = await onOpenUrl((urls) => {
          for (const urlStr of urls) {
            try {
              const url = new URL(urlStr)
              console.log("[DeepLinkBootstrap] deep-link received:", urlStr)
              void handleDeepLinkParams(url.searchParams)
            } catch (err) {
              console.error("[DeepLinkBootstrap] parse deep-link failed:", err)
            }
          }
        })
      } catch (err) {
        console.error(
          "[DeepLinkBootstrap] deep-link listener setup failed:",
          err
        )
      }
    }

    void setupDeepLinkListener()

    return () => {
      if (unlisten) {
        unlisten()
      }
    }
  }, [foldersHydrated, tabsHydrated, handleDeepLinkParams])

  return null
}
