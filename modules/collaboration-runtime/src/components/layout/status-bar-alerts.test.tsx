import { fireEvent, render, screen } from "@testing-library/react"
import { NextIntlClientProvider } from "next-intl"
import { describe, expect, it } from "vitest"

import { AlertProvider, useAlertContext } from "@/contexts/alert-context"
import enMessages from "@/i18n/messages/en.json"
import { StatusBarAlerts } from "./status-bar-alerts"

function PushErrorAlertButton() {
  const { pushAlert } = useAlertContext()
  return (
    <button
      onClick={() => pushAlert("error", "Gemini CLI SDK is not installed")}
    >
      Push error
    </button>
  )
}

function renderAlerts() {
  return render(
    <NextIntlClientProvider locale="en" messages={enMessages}>
      <AlertProvider>
        <StatusBarAlerts />
        <PushErrorAlertButton />
      </AlertProvider>
    </NextIntlClientProvider>
  )
}

describe("StatusBarAlerts", () => {
  it("auto-opens the alert popover when a new error alert arrives", async () => {
    renderAlerts()

    expect(screen.queryByText("Gemini CLI SDK is not installed")).toBeNull()

    fireEvent.click(screen.getByRole("button", { name: "Push error" }))

    expect(
      await screen.findByText("Gemini CLI SDK is not installed")
    ).toBeInTheDocument()
  })
})
