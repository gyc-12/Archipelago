"use client"

import { Dialog as DialogPrimitive } from "radix-ui"
import { AppleIcon } from "@/components/apple/apple-icon"
import { cn } from "@/lib/utils"

interface ImagePreviewDialogProps {
  src: string
  alt: string
  open: boolean
  onOpenChange: (open: boolean) => void
  /**
   * When provided, render a download icon button next to the close button.
   * The handler is invoked on click; the dialog stays open so the caller
   * can show its own progress/toast feedback.
   */
  onDownload?: () => void
  downloadLabel?: string
}

function ImagePreviewDialog({
  src,
  alt,
  open,
  onOpenChange,
  onDownload,
  downloadLabel,
}: ImagePreviewDialogProps) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay
          className={cn(
            "data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0",
            "fixed inset-0 z-50 bg-black/82 duration-100 supports-backdrop-filter:backdrop-blur-sm"
          )}
        />
        <DialogPrimitive.Content
          className="fixed inset-0 z-50 flex items-center justify-center outline-none"
          aria-describedby={undefined}
          onClick={() => onOpenChange(false)}
        >
          <DialogPrimitive.Title className="sr-only">
            {alt}
          </DialogPrimitive.Title>
          <div className="absolute right-4 top-4 z-10 flex items-center gap-2 rounded-full border border-white/15 bg-black/28 p-1 backdrop-blur-2xl">
            {onDownload && (
              <button
                type="button"
                onClick={(e) => {
                  e.stopPropagation()
                  onDownload()
                }}
                className="inline-flex size-8 items-center justify-center rounded-full text-white/85 transition-colors hover:bg-white/16 hover:text-white"
                aria-label={downloadLabel ?? "Download"}
                title={downloadLabel ?? "Download"}
              >
                <AppleIcon name="download" className="size-4" />
              </button>
            )}
            <button
              type="button"
              onClick={() => onOpenChange(false)}
              className="inline-flex size-8 items-center justify-center rounded-full text-white/85 transition-colors hover:bg-white/16 hover:text-white"
              aria-label="Close"
            >
              <AppleIcon name="close" className="size-4" />
            </button>
          </div>
          {src && (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img
              src={src}
              alt={alt}
              onClick={(e) => e.stopPropagation()}
              className="max-h-[90vh] max-w-[90vw] rounded-[18px] object-contain ring-1 ring-white/10"
            />
          )}
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  )
}

export { ImagePreviewDialog }
