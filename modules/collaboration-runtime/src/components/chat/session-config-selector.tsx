"use client"

import { Fragment } from "react"
import { AppleIcon } from "@/components/apple/apple-icon"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { DropdownRadioItemContent } from "@/components/chat/dropdown-radio-item-content"
import { SelectorIcon } from "@/components/chat/selector-icon"
import { getConfigOptionIconSpec } from "@/components/chat/selector-icons"
import type { SessionConfigOptionInfo } from "@/lib/types"

interface SessionConfigSelectorProps {
  option: SessionConfigOptionInfo
  onSelect: (configId: string, valueId: string) => void
}

export function SessionConfigSelector({
  option,
  onSelect,
}: SessionConfigSelectorProps) {
  if (option.kind.type !== "select") return null

  const allOptions =
    option.kind.groups.length > 0
      ? option.kind.groups.flatMap((group) => group.options)
      : option.kind.options
  const selected = allOptions.find(
    (item) => item.value === option.kind.current_value
  )
  const currentLabel = selected?.name ?? option.kind.current_value
  const selectedIcon = getConfigOptionIconSpec(option, selected)

  return (
    <DropdownMenuSub>
      <DropdownMenuSubTrigger title={option.description ?? option.name}>
        <SelectorIcon
          spec={selectedIcon}
          className="size-4 shrink-0 text-muted-foreground"
        />
        <span className="min-w-0 flex-1 truncate font-medium">
          {option.name}
        </span>
        <span className="max-w-[10rem] shrink-0 truncate text-xs text-muted-foreground">
          {currentLabel}
        </span>
      </DropdownMenuSubTrigger>
      <DropdownMenuSubContent
        className="min-w-72 max-w-xs overflow-y-auto"
        style={{
          maxHeight:
            "min(60vh, var(--radix-dropdown-menu-content-available-height))",
        }}
      >
        <DropdownMenuRadioGroup
          value={option.kind.current_value}
          onValueChange={(value) => onSelect(option.id, value)}
        >
          {option.kind.groups.length > 0
            ? option.kind.groups.map((group, index) => (
                <Fragment key={group.group}>
                  {index > 0 && <DropdownMenuSeparator />}
                  <DropdownMenuLabel>{group.name}</DropdownMenuLabel>
                  {group.options.map((item) => (
                    <DropdownMenuRadioItem
                      key={`${group.group}-${item.value}`}
                      value={item.value}
                    >
                      <DropdownRadioItemContent
                        label={item.name}
                        description={item.description}
                        icon={
                          <SelectorIcon
                            spec={getConfigOptionIconSpec(option, item)}
                            className="size-4"
                          />
                        }
                      />
                    </DropdownMenuRadioItem>
                  ))}
                </Fragment>
              ))
            : option.kind.options.map((item) => (
                <DropdownMenuRadioItem key={item.value} value={item.value}>
                  <DropdownRadioItemContent
                    label={item.name}
                    description={item.description}
                    icon={
                      <SelectorIcon
                        spec={getConfigOptionIconSpec(option, item)}
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

export function InlineSessionConfigSelector({
  option,
  onSelect,
}: SessionConfigSelectorProps) {
  if (option.kind.type !== "select") return null

  const allOptions =
    option.kind.groups.length > 0
      ? option.kind.groups.flatMap((group) => group.options)
      : option.kind.options
  const selected = allOptions.find(
    (item) => item.value === option.kind.current_value
  )
  const currentLabel = selected?.name ?? option.kind.current_value
  const selectedIcon = getConfigOptionIconSpec(option, selected)

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          title={option.description ?? option.name}
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
        className="min-w-72 overflow-y-auto"
        style={{
          maxWidth: "min(20rem, calc(100vw - 1rem))",
          maxHeight:
            "min(60vh, var(--radix-dropdown-menu-content-available-height))",
        }}
      >
        <DropdownMenuRadioGroup
          value={option.kind.current_value}
          onValueChange={(value) => onSelect(option.id, value)}
        >
          {option.kind.groups.length > 0
            ? option.kind.groups.map((group, index) => (
                <Fragment key={group.group}>
                  {index > 0 && <DropdownMenuSeparator />}
                  <DropdownMenuLabel>{group.name}</DropdownMenuLabel>
                  {group.options.map((item) => (
                    <DropdownMenuRadioItem
                      key={`${group.group}-${item.value}`}
                      value={item.value}
                    >
                      <DropdownRadioItemContent
                        label={item.name}
                        description={item.description}
                        icon={
                          <SelectorIcon
                            spec={getConfigOptionIconSpec(option, item)}
                            className="size-4"
                          />
                        }
                      />
                    </DropdownMenuRadioItem>
                  ))}
                </Fragment>
              ))
            : option.kind.options.map((item) => (
                <DropdownMenuRadioItem key={item.value} value={item.value}>
                  <DropdownRadioItemContent
                    label={item.name}
                    description={item.description}
                    icon={
                      <SelectorIcon
                        spec={getConfigOptionIconSpec(option, item)}
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
