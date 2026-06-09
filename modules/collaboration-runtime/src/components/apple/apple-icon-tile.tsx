"use client"

import { AppleIcon, type AppleIconName } from "@/components/apple/apple-icon"
import { cn } from "@/lib/utils"

export type AppleIconTone =
  | "blue"
  | "green"
  | "indigo"
  | "orange"
  | "pink"
  | "purple"
  | "red"
  | "slate"

const TONE_CLASSES: Record<AppleIconTone, string> = {
  blue: "bg-[#007aff] text-white",
  green: "bg-[#34c759] text-white",
  indigo: "bg-[#5856d6] text-white",
  orange: "bg-[#ff9500] text-white",
  pink: "bg-[#ff2d55] text-white",
  purple: "bg-[#af52de] text-white",
  red: "bg-[#ff3b30] text-white",
  slate:
    "bg-[rgb(120_120_128_/_18%)] text-foreground dark:bg-[rgb(255_255_255_/_16%)] dark:text-white",
}

interface AppleIconTileProps {
  name: AppleIconName
  tone?: AppleIconTone
  className?: string
  iconClassName?: string
}

export function AppleIconTile({
  name,
  tone = "blue",
  className,
  iconClassName,
}: AppleIconTileProps) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "inline-flex size-7 shrink-0 items-center justify-center rounded-[8px]",
        "shadow-[inset_0_1px_0_rgb(255_255_255_/_28%)]",
        TONE_CLASSES[tone],
        className
      )}
    >
      <AppleIcon
        name={name}
        className={cn("size-4", iconClassName)}
        weight="duotone"
      />
    </span>
  )
}
