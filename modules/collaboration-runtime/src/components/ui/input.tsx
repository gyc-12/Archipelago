import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "bg-card border-input focus-visible:border-ring focus-visible:ring-ring/35 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 h-10 rounded-full border px-4 py-1 text-base transition-colors file:h-7 file:text-sm file:font-medium focus-visible:ring-[2px] aria-invalid:ring-[2px] md:text-sm file:text-foreground placeholder:text-muted-foreground w-full min-w-0 outline-none file:inline-flex file:border-0 file:bg-transparent disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 read-only:bg-muted/50 read-only:text-muted-foreground read-only:cursor-default",
        className
      )}
      {...props}
    />
  )
}

export { Input }
