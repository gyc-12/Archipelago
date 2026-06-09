"use client"

import {
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react"
import { Menu } from "lucide-react"
import { useTranslations } from "next-intl"
import { usePathname } from "next/navigation"
import { useRouter } from "next/navigation"
import {
  AppleIconTile,
  type AppleIconTone,
} from "@/components/apple/apple-icon-tile"
import type { AppleIconName } from "@/components/apple/apple-icon"
import { Button } from "@/components/ui/button"
import { AppToaster } from "@/components/ui/app-toaster"
import { cn } from "@/lib/utils"
import {
  detectEnvironment,
  isIslandEmbeddedWebView,
} from "@/lib/transport/detect"
import { AppTitleBar } from "@/components/layout/app-title-bar"
import { useIsMobile } from "@/hooks/use-mobile"
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet"

interface SettingsNavItem {
  href: string
  labelKey:
    | "general"
    | "appearance"
    | "agents"
    | "model_providers"
    | "mcp"
    | "skills"
    | "version_control"
    | "chat_channels"
    | "system"
    | "web_service"
  icon: AppleIconName
  tone: AppleIconTone
}

const SETTINGS_NAV_ITEMS: SettingsNavItem[] = [
  {
    href: "/settings/appearance",
    labelKey: "appearance",
    icon: "appearance",
    tone: "blue",
  },
  {
    href: "/settings/general",
    labelKey: "general",
    icon: "general",
    tone: "slate",
  },
  {
    href: "/settings/mcp",
    labelKey: "mcp",
    icon: "mcp",
    tone: "purple",
  },
  {
    href: "/settings/skills",
    labelKey: "skills",
    icon: "skills",
    tone: "orange",
  },
  {
    href: "/settings/agents",
    labelKey: "agents",
    icon: "agents",
    tone: "green",
  },
  {
    href: "/settings/model-providers",
    labelKey: "model_providers",
    icon: "modelProviders",
    tone: "indigo",
  },
  {
    href: "/settings/version-control",
    labelKey: "version_control",
    icon: "versionControl",
    tone: "pink",
  },
  {
    href: "/settings/chat-channels",
    labelKey: "chat_channels",
    icon: "chat",
    tone: "blue",
  },
  {
    href: "/settings/web-service",
    labelKey: "web_service",
    icon: "webService",
    tone: "green",
  },
  {
    href: "/settings/system",
    labelKey: "system",
    icon: "system",
    tone: "slate",
  },
]

interface SettingsShellProps {
  children: ReactNode
}

function normalizePath(path: string): string {
  const noSuffix = path.replace(/\/index\.html$/, "").replace(/\.html$/, "")
  const noTrailingSlash = noSuffix.replace(/\/+$/, "")
  return noTrailingSlash || "/"
}

function isWindowsRuntime(): boolean {
  if (typeof navigator === "undefined") return false
  const platform = navigator.platform.toLowerCase()
  const userAgent = navigator.userAgent.toLowerCase()
  return platform.includes("win") || userAgent.includes("windows")
}

export function SettingsShell({ children }: SettingsShellProps) {
  const t = useTranslations("SettingsShell")
  const pathname = usePathname()
  const router = useRouter()
  const normalizedPathname = normalizePath(pathname)
  const isMobile = useIsMobile()
  const [navOpen, setNavOpen] = useState(false)

  useEffect(() => {
    document.title = `${t("title")} - Archipelago`
  }, [t])

  const navigateTo = useCallback(
    (href: string) => {
      if (typeof window === "undefined") return

      const target = normalizePath(href)
      const current = normalizePath(window.location.pathname)
      if (current === target) {
        setNavOpen(false)
        return
      }

      // Preserve current query string so the active remote workspace context
      // (`?remoteConnectionId=N`) carries over to sub-pages — without this,
      // navigating from /settings/appearance to /settings/mcp drops the
      // remote id and the next page falls back to the local Tauri backend.
      const search = window.location.search
      const fullTarget = search ? `${target}${search}` : target

      if (isWindowsRuntime()) {
        window.location.assign(fullTarget)
        return
      }

      router.push(fullTarget)
      setNavOpen(false)
    },
    [router, setNavOpen]
  )

  const filteredNavItems = SETTINGS_NAV_ITEMS.filter(
    (item) =>
      !(
        item.labelKey === "web_service" &&
        detectEnvironment() === "web" &&
        !isIslandEmbeddedWebView()
      )
  )

  const navContent = (
    <>
      <div className="px-2 pb-2 text-[11px] font-medium text-muted-foreground">
        {t("preferences")}
      </div>
      <nav className="space-y-1">
        {filteredNavItems.map((item) => {
          const translationKey = `nav.${item.labelKey}` as const
          const active =
            normalizedPathname === item.href ||
            normalizedPathname.startsWith(`${item.href}/`)
          return (
            <Button
              key={item.href}
              variant={active ? "secondary" : "ghost"}
              size="sm"
              className={cn(
                "h-10 w-full justify-start gap-2 rounded-[12px] px-2 text-[13px]",
                active
                  ? "border border-primary/15 bg-primary/10 text-primary"
                  : "text-foreground/82 hover:bg-sidebar-accent"
              )}
              type="button"
              onClick={() => navigateTo(item.href)}
              aria-current={active ? "page" : undefined}
            >
              <span className="inline-flex min-w-0 items-center gap-2.5">
                <AppleIconTile
                  name={item.icon}
                  tone={item.tone}
                  className="size-6 rounded-[7px]"
                  iconClassName="size-3.5"
                />
                <span className="truncate">{t(translationKey)}</span>
              </span>
            </Button>
          )
        })}
      </nav>
    </>
  )

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-background text-foreground">
      <AppTitleBar
        left={
          isMobile ? (
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8"
              onClick={() => setNavOpen(true)}
            >
              <Menu className="h-4 w-4" />
            </Button>
          ) : undefined
        }
        center={<div className="text-sm font-semibold">{t("title")}</div>}
      />

      <div className="flex-1 min-h-0 flex bg-background">
        {/* Desktop sidebar */}
        {!isMobile && (
          <aside className="w-60 shrink-0 border-r border-border/70 bg-background/65 p-3 backdrop-blur-xl">
            {navContent}
          </aside>
        )}

        {/* Mobile navigation Sheet */}
        {isMobile && (
          <Sheet open={navOpen} onOpenChange={setNavOpen}>
            <SheetContent
              side="left"
              showCloseButton={false}
              className="w-[260px] border-r border-border/70 bg-background/90 p-3 backdrop-blur-xl"
            >
              <SheetTitle className="sr-only">{t("title")}</SheetTitle>
              {navContent}
            </SheetContent>
          </Sheet>
        )}

        <section className="archipelago-settings-page flex-1 min-w-0 min-h-0 overflow-hidden bg-background">
          {children}
        </section>
      </div>
      <AppToaster position="bottom-right" closeButton duration={4000} />
    </div>
  )
}
