"use client"

import { AppleIcon } from "@/components/apple/apple-icon"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { DropdownRadioItemContent } from "@/components/chat/dropdown-radio-item-content"
import { SelectorIcon } from "@/components/chat/selector-icon"
import { getModeIconSpec } from "@/components/chat/selector-icons"
import type { SessionModeInfo } from "@/lib/types"

interface ModeSelectorProps {
  modes: SessionModeInfo[]
  selectedModeId: string | null
  onSelect: (modeId: string) => void
  label: string
}

export function ModeSelector({
  modes,
  selectedModeId,
  onSelect,
  label,
}: ModeSelectorProps) {
  const selected = modes.find((mode) => mode.id === selectedModeId)
  const currentLabel = selected?.name ?? selectedModeId ?? ""
  const selectedIcon = getModeIconSpec(selected ?? null)
  return (
    <DropdownMenuSub>
      <DropdownMenuSubTrigger
        title={selected?.description ?? selected?.name ?? label}
      >
        <SelectorIcon
          spec={selectedIcon}
          className="size-4 shrink-0 text-muted-foreground"
        />
        <span className="min-w-0 flex-1 truncate font-medium">{label}</span>
        <span className="max-w-[10rem] shrink-0 truncate text-xs text-muted-foreground">
          {currentLabel}
        </span>
      </DropdownMenuSubTrigger>
      <DropdownMenuSubContent className="max-h-[60vh] min-w-72 max-w-xs overflow-y-auto">
        <DropdownMenuRadioGroup
          value={selectedModeId ?? ""}
          onValueChange={onSelect}
        >
          {modes.map((mode) => (
            <DropdownMenuRadioItem key={mode.id} value={mode.id}>
              <DropdownRadioItemContent
                label={mode.name}
                description={mode.description}
                icon={
                  <SelectorIcon
                    spec={getModeIconSpec(mode)}
                    className="size-4"
                  />
                }
              />
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuSubContent>
    </DropdownMenuSub>
  )
}

export function InlineModeSelector({
  modes,
  selectedModeId,
  onSelect,
  label,
}: ModeSelectorProps) {
  const selected = modes.find((mode) => mode.id === selectedModeId)
  const currentLabel = selected?.name ?? selectedModeId ?? ""
  const selectedIcon = getModeIconSpec(selected ?? null)
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          title={selected?.description ?? selected?.name ?? label}
          className="min-w-0 text-muted-foreground"
        >
          <SelectorIcon spec={selectedIcon} className="size-4 shrink-0" />
          <span className="max-w-[10rem] truncate">{currentLabel}</span>
          <AppleIcon name="arrowDown" className="size-4 shrink-0" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        side="top"
        align="start"
        className="max-h-[60vh] min-w-72 overflow-y-auto"
        style={{
          maxWidth: "min(20rem, calc(100vw - 1rem))",
        }}
      >
        <DropdownMenuRadioGroup
          value={selectedModeId ?? ""}
          onValueChange={onSelect}
        >
          {modes.map((mode) => (
            <DropdownMenuRadioItem key={mode.id} value={mode.id}>
              <DropdownRadioItemContent
                label={mode.name}
                description={mode.description}
                icon={
                  <SelectorIcon
                    spec={getModeIconSpec(mode)}
                    className="size-4"
                  />
                }
              />
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
