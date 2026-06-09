"use client"

import type { ComponentType } from "react"
import {
  ArrowCircleUpIcon,
  ArrowLineUpIcon,
  ArrowSquareOutIcon,
  ArrowsInSimpleIcon,
  ArrowsOutSimpleIcon,
  ArrowsClockwiseIcon,
  BookOpenTextIcon,
  BrainIcon,
  BatteryFullIcon,
  BatteryHighIcon,
  BatteryLowIcon,
  BatteryMediumIcon,
  CaretLeftIcon,
  CaretDownIcon,
  CaretRightIcon,
  ChartBarIcon,
  ChatCircleTextIcon,
  CheckCircleIcon,
  CommandIcon,
  CoinsIcon,
  CopyIcon,
  CrosshairIcon,
  CpuIcon,
  DatabaseIcon,
  DotsThreeVerticalIcon,
  DownloadSimpleIcon,
  EyeIcon,
  EyeSlashIcon,
  FileTextIcon,
  FileLockIcon,
  FileMagnifyingGlassIcon,
  FolderPlusIcon,
  FunnelIcon,
  FolderOpenIcon,
  GearSixIcon,
  GitDiffIcon,
  GitBranchIcon,
  GlobeIcon,
  GlobeHemisphereWestIcon,
  ImageSquareIcon,
  LockIcon,
  LockKeyOpenIcon,
  ListIcon,
  ListChecksIcon,
  MagnifyingGlassIcon,
  MinusIcon,
  PackageIcon,
  PaintBrushIcon,
  PaperPlaneTiltIcon,
  PaperclipIcon,
  PencilSimpleLineIcon,
  PlugsConnectedIcon,
  PlusCircleIcon,
  PlayIcon,
  RobotIcon,
  SidebarIcon,
  SidebarSimpleIcon,
  ShieldIcon,
  ShieldCheckIcon,
  ShieldSlashIcon,
  ShieldWarningIcon,
  SlidersHorizontalIcon,
  SparkleIcon,
  SpinnerIcon,
  SquareIcon,
  StarIcon,
  StopIcon,
  TerminalWindowIcon,
  TimerIcon,
  TranslateIcon,
  TrashIcon,
  LockOpenIcon,
  UploadSimpleIcon,
  WarningIcon,
  WifiHighIcon,
  WrenchIcon,
  XIcon,
} from "@phosphor-icons/react"

import { cn } from "@/lib/utils"

type AppleIconWeight =
  | "thin"
  | "light"
  | "regular"
  | "bold"
  | "fill"
  | "duotone"

type AppleIconComponent = ComponentType<{
  className?: string
  size?: number | string
  weight?: AppleIconWeight
}>

export type AppleIconName =
  | "agents"
  | "appearance"
  | "arrowDown"
  | "arrowLeft"
  | "arrowRight"
  | "attach"
  | "batteryFull"
  | "batteryHigh"
  | "batteryLow"
  | "batteryMedium"
  | "chat"
  | "checkCircle"
  | "close"
  | "command"
  | "copy"
  | "crosshair"
  | "edit"
  | "diff"
  | "download"
  | "external"
  | "eye"
  | "eyeOff"
  | "file"
  | "fileLock"
  | "fileSearch"
  | "filter"
  | "folder"
  | "folderPlus"
  | "general"
  | "globe"
  | "image"
  | "jumpUp"
  | "language"
  | "lock"
  | "lockKeyOpen"
  | "maximize"
  | "mcp"
  | "menu"
  | "minimize"
  | "minus"
  | "modelProviders"
  | "model"
  | "more"
  | "network"
  | "panelLeft"
  | "panelRight"
  | "package"
  | "play"
  | "plus"
  | "refresh"
  | "search"
  | "send"
  | "shield"
  | "shieldCheck"
  | "shieldSlash"
  | "shieldWarning"
  | "skills"
  | "sparkle"
  | "spinner"
  | "square"
  | "star"
  | "stats"
  | "stop"
  | "system"
  | "terminal"
  | "thinking"
  | "timer"
  | "todo"
  | "tokens"
  | "trash"
  | "update"
  | "upload"
  | "unlock"
  | "versionControl"
  | "warning"
  | "webService"
  | "wrench"

const ICONS: Record<AppleIconName, AppleIconComponent> = {
  agents: RobotIcon,
  appearance: PaintBrushIcon,
  arrowDown: CaretDownIcon,
  arrowLeft: CaretLeftIcon,
  arrowRight: CaretRightIcon,
  attach: PaperclipIcon,
  batteryFull: BatteryFullIcon,
  batteryHigh: BatteryHighIcon,
  batteryLow: BatteryLowIcon,
  batteryMedium: BatteryMediumIcon,
  chat: ChatCircleTextIcon,
  checkCircle: CheckCircleIcon,
  close: XIcon,
  command: CommandIcon,
  copy: CopyIcon,
  crosshair: CrosshairIcon,
  edit: PencilSimpleLineIcon,
  diff: GitDiffIcon,
  download: DownloadSimpleIcon,
  external: ArrowSquareOutIcon,
  eye: EyeIcon,
  eyeOff: EyeSlashIcon,
  file: FileTextIcon,
  fileLock: FileLockIcon,
  fileSearch: FileMagnifyingGlassIcon,
  filter: FunnelIcon,
  folder: FolderOpenIcon,
  folderPlus: FolderPlusIcon,
  general: SlidersHorizontalIcon,
  globe: GlobeIcon,
  image: ImageSquareIcon,
  jumpUp: ArrowLineUpIcon,
  language: TranslateIcon,
  lock: LockIcon,
  lockKeyOpen: LockKeyOpenIcon,
  maximize: ArrowsOutSimpleIcon,
  mcp: PlugsConnectedIcon,
  menu: ListIcon,
  minimize: ArrowsInSimpleIcon,
  minus: MinusIcon,
  modelProviders: DatabaseIcon,
  model: CpuIcon,
  more: DotsThreeVerticalIcon,
  network: WifiHighIcon,
  panelLeft: SidebarIcon,
  panelRight: SidebarSimpleIcon,
  package: PackageIcon,
  play: PlayIcon,
  plus: PlusCircleIcon,
  refresh: ArrowsClockwiseIcon,
  search: MagnifyingGlassIcon,
  send: PaperPlaneTiltIcon,
  shield: ShieldIcon,
  shieldCheck: ShieldCheckIcon,
  shieldSlash: ShieldSlashIcon,
  shieldWarning: ShieldWarningIcon,
  skills: BookOpenTextIcon,
  sparkle: SparkleIcon,
  spinner: SpinnerIcon,
  square: SquareIcon,
  star: StarIcon,
  stats: ChartBarIcon,
  stop: StopIcon,
  system: GearSixIcon,
  terminal: TerminalWindowIcon,
  thinking: BrainIcon,
  timer: TimerIcon,
  todo: ListChecksIcon,
  tokens: CoinsIcon,
  trash: TrashIcon,
  update: ArrowCircleUpIcon,
  upload: UploadSimpleIcon,
  unlock: LockOpenIcon,
  versionControl: GitBranchIcon,
  warning: WarningIcon,
  webService: GlobeHemisphereWestIcon,
  wrench: WrenchIcon,
}

interface AppleIconProps {
  name: AppleIconName
  className?: string
  weight?: AppleIconWeight
  size?: number | string
}

export function AppleIcon({
  name,
  className,
  weight = "regular",
  size,
}: AppleIconProps) {
  const Icon = ICONS[name]

  return (
    <Icon
      aria-hidden="true"
      className={cn("size-4", className)}
      size={size}
      weight={weight}
    />
  )
}
