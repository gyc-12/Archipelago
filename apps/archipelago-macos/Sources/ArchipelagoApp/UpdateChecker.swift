import Foundation

/// No-op stub — Sparkle removed for AgentHub 二开 (auto-update not needed).
@MainActor
@Observable
final class UpdateChecker: NSObject {
    private(set) var canCheckForUpdates = false
    private(set) var hasUpdate = false
    private(set) var latestVersion: String?

    func startIfNeeded() {}
    func checkForUpdates() {}
}
