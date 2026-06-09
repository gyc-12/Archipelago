"use client"

import { useTranslations } from "next-intl"
import { AppleIconTile } from "@/components/apple/apple-icon-tile"

export function AuxPanelNoFolderEmpty() {
  const t = useTranslations("Folder.auxPanel")
  return (
    <div className="flex h-full flex-col items-center justify-center gap-1 p-6 text-center">
      <AppleIconTile
        name="folder"
        tone="slate"
        className="mb-1 size-8 rounded-[10px]"
        iconClassName="size-[1.125rem]"
      />
      <p className="text-sm font-medium">{t("noFolderTitle")}</p>
      <p className="text-xs text-muted-foreground">{t("noFolderHint")}</p>
    </div>
  )
}
