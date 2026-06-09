"use client"

import type { ReactNode } from "react"

interface DropdownRadioItemContentProps {
  label: string
  description?: string | null
  icon?: ReactNode
}

export function DropdownRadioItemContent({
  label,
  description,
  icon,
}: DropdownRadioItemContentProps) {
  const normalizedDescription = description?.trim()

  return (
    <div className="flex w-full min-w-0 items-start gap-2 pr-2">
      {icon ? (
        <span className="mt-0.5 flex size-4 shrink-0 items-center justify-center text-muted-foreground">
          {icon}
        </span>
      ) : null}
      <div className="min-w-0 flex-1">
        <p className="truncate">{label}</p>
        {normalizedDescription ? (
          <p className="text-muted-foreground mt-0.5 text-xs leading-snug whitespace-pre-wrap wrap-break-word">
            {normalizedDescription}
          </p>
        ) : null}
      </div>
    </div>
  )
}
