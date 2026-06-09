"use client"

import { AppleIcon } from "@/components/apple/apple-icon"

export function AppBootLoading() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background text-foreground">
      <div className="flex items-center gap-3 px-2 py-1">
        <AppleIcon name="spinner" className="size-4 animate-spin text-primary" />
        <span className="text-sm font-medium">Archipelago</span>
      </div>
    </div>
  )
}
