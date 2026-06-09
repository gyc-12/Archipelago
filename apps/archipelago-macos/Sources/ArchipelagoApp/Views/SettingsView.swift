import SwiftUI
import AppKit
import ArchipelagoCore

// MARK: - Settings tabs

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case setup
    case display
    case sound
    case appearance
    case about

    var id: String { rawValue }

    func label(_ lang: LanguageManager) -> String {
        switch self {
        case .general:    lang.t("settings.tab.general")
        case .setup:      lang.t("settings.tab.setup")
        case .appearance: lang.t("settings.tab.appearance")
        case .display:    lang.t("settings.tab.display")
        case .sound:      lang.t("settings.tab.sound")
        case .about:      lang.t("settings.tab.about")
        }
    }

    var icon: String {
        switch self {
        case .general:    "gearshape.fill"
        case .setup:      "point.3.connected.trianglepath.dotted"
        case .appearance: "paintbrush.fill"
        case .display:    "textformat.size"
        case .sound:      "speaker.wave.2.fill"
        case .about:      "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general:    .gray
        case .setup:      .blue
        case .appearance: .purple
        case .display:    .blue
        case .sound:      .green
        case .about:      .blue
        }
    }

    var section: SettingsSection {
        switch self {
        case .general, .setup, .display, .sound, .appearance: .system
        case .about:                                          .app
        }
    }
}

enum SettingsSection: String, CaseIterable {
    case system
    case app

    func header(_ lang: LanguageManager) -> String {
        switch self {
        case .system:   lang.t("settings.section.system")
        case .app:      "Archipelago"
        }
    }

    var tabs: [SettingsTab] {
        SettingsTab.allCases.filter { $0.section == self }
    }
}

// MARK: - Root settings view

struct SettingsView: View {
    var model: AppModel
    @State private var selectedTab: SettingsTab = .general

    private var lang: LanguageManager { model.lang }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 480, idealHeight: 560)
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .openIslandSelectSetupTab)) { _ in
            selectedTab = .setup
        }
    }

    // MARK: Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsSection.allCases, id: \.self) { section in
                Section(section.header(lang)) {
                    ForEach(section.tabs) { tab in
                        Label {
                            Text(tab.label(lang))
                        } icon: {
                            Image(systemName: tab.icon)
                                .foregroundStyle(tab.iconColor)
                        }
                        .tag(tab)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailView: some View {
        ZStack(alignment: .topTrailing) {
            switch selectedTab {
            case .general:
                GeneralSettingsPane(model: model)
            case .setup:
                SetupSettingsPane(model: model)
            case .appearance:
                AppearanceSettingsPane(model: model)
            case .display:
                DisplaySettingsPane(model: model)
            case .sound:
                SoundSettingsPane(model: model)
            case .about:
                AboutSettingsPane(model: model)
            }

            if model.updateChecker.hasUpdate, let version = model.updateChecker.latestVersion {
                UpdateBanner(version: version, lang: lang) {
                    model.updateChecker.checkForUpdates()
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            Section(lang.t("settings.section.system")) {
                Toggle(lang.t("settings.general.launchAtLogin"), isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.launchAtLoginEnabled = $0 }
                ))

                Picker(lang.t("settings.general.monitor"), selection: Binding(
                    get: { model.overlayDisplaySelectionID },
                    set: { model.overlayDisplaySelectionID = $0 }
                )) {
                    Text(lang.t("settings.general.automatic")).tag(OverlayDisplayOption.automaticID)
                    ForEach(model.overlayDisplayOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
            }

            Section(lang.t("settings.general.language")) {
                Picker(lang.t("settings.general.language"), selection: Binding(
                    get: { lang.language },
                    set: { lang.language = $0 }
                )) {
                    Text(lang.t("settings.general.languageSystem")).tag(LanguageManager.AppLanguage.system)
                    Text(lang.t("settings.general.languageEnglish")).tag(LanguageManager.AppLanguage.en)
                    Text(lang.t("settings.general.languageChinese")).tag(LanguageManager.AppLanguage.zhHans)
                    Text(lang.t("settings.general.languageTraditionalChinese")).tag(LanguageManager.AppLanguage.zhHant)
                }
            }

            Section(lang.t("settings.general.behavior")) {
                Toggle(lang.t("settings.general.autoCollapse"), isOn: .constant(true))
                Toggle(lang.t("settings.general.showDockIcon"), isOn: Binding(
                    get: { model.showDockIcon },
                    set: { model.showDockIcon = $0 }
                ))
                Toggle(lang.t("settings.general.hapticFeedback"), isOn: Binding(
                    get: { model.hapticFeedbackEnabled },
                    set: { model.hapticFeedbackEnabled = $0 }
                ))
                Toggle(lang.t("settings.general.completionReply"), isOn: Binding(
                    get: { model.completionReplyEnabled },
                    set: { model.completionReplyEnabled = $0 }
                ))
                Toggle(lang.t("settings.general.suppressFrontmostNotifications"), isOn: Binding(
                    get: { model.suppressFrontmostNotifications },
                    set: { model.suppressFrontmostNotifications = $0 }
                ))
            }

        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.general"))
    }
}

// MARK: - Display

struct DisplaySettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            Section(lang.t("settings.display.monitor")) {
                Picker(lang.t("settings.display.position"), selection: Binding(
                    get: { model.overlayDisplaySelectionID },
                    set: { model.overlayDisplaySelectionID = $0 }
                )) {
                    Text(lang.t("settings.general.automatic")).tag(OverlayDisplayOption.automaticID)
                    ForEach(model.overlayDisplayOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                }
            }

            if let diag = model.overlayPlacementDiagnostics {
                Section(lang.t("settings.display.diagnostics")) {
                    LabeledContent(lang.t("settings.display.currentScreen"), value: diag.targetScreenName)
                    LabeledContent(lang.t("settings.display.layoutMode"), value: diag.modeDescription)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.display"))
    }
}

// MARK: - Sound

struct SoundSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    private var availableSounds: [String] {
        NotificationSoundService.availableSounds()
    }

    var body: some View {
        Form {
            Section(lang.t("settings.sound.notifications")) {
                Toggle(lang.t("settings.sound.mute"), isOn: Binding(
                    get: { model.isSoundMuted },
                    set: { _ in model.toggleSoundMuted() }
                ))
            }

            Section(lang.t("settings.sound.selectSound")) {
                List(availableSounds, id: \.self) { name in
                    Button {
                        model.selectedSoundName = name
                        NotificationSoundService.play(name)
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if name == model.selectedSoundName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.sound"))
    }
}

// MARK: - About

struct AboutSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }
    private let primaryInk = Color.white.opacity(0.94)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)

                Text(lang.t("app.name"))
                    .font(.title.bold())

                Text(lang.t("app.description"))
                    .foregroundStyle(.secondary)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text(lang.t("settings.about.version", version))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            Form {
                Section {
                    aboutActionRow(
                        title: lang.t("settings.about.checkForUpdates"),
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: primaryInk,
                        action: {
                            model.updateChecker.checkForUpdates()
                        }
                    )
                    .disabled(!model.updateChecker.canCheckForUpdates)
                    .opacity(model.updateChecker.canCheckForUpdates ? 1 : 0.55)
                    .accessibilityIdentifier("settings.about.checkForUpdates")
                }

                Section {
                    aboutActionRow(
                        title: lang.t("settings.about.quitApp"),
                        systemImage: "rectangle.portrait.and.arrow.right",
                        tint: Color(red: 1.0, green: 0.29, blue: 0.29),
                        action: {
                            model.quitApplication()
                        }
                    )
                    .accessibilityIdentifier("settings.about.quitApp")
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(lang.t("settings.tab.about"))
    }

    private func aboutActionRow(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18, alignment: .leading)

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setup

struct SetupSettingsPane: View {
    var model: AppModel

    private var lang: LanguageManager { model.lang }

    var body: some View {
        Form {
            archipelagoConnectionSection
            archipelagoScopeSection
            archipelagoEventsSection
        }
        .formStyle(.grouped)
        .navigationTitle(lang.t("settings.tab.setup"))
    }

    @ViewBuilder
    private var archipelagoConnectionSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: archipelagoStatusIcon)
                    .foregroundStyle(archipelagoStatusColor)
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(archipelagoStatusTitle)
                    Text(archipelagoStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.archipelago.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if !model.archipelago.isArchipelagoConnected {
                    Button(lang.t("setup.archipelago.retry")) {
                        model.archipelago.boot()
                    }
                }
            }
        } header: {
            Text(lang.t("setup.section.archipelagoRuntime"))
        } footer: {
            Text(lang.t("setup.archipelago.footer"))
        }
    }

    private var archipelagoScopeSection: some View {
        Section {
            LabeledContent(lang.t("setup.archipelago.groups"), value: String(model.archipelago.groupChats.count))
            LabeledContent(lang.t("setup.archipelago.agents"), value: String(archipelagoAgentCount))
            LabeledContent(lang.t("setup.archipelago.eventSource"), value: "Archipelago WebSocket / HTTP")
        } header: {
            Text(lang.t("setup.section.syncScope"))
        }
    }

    @ViewBuilder
    private var archipelagoEventsSection: some View {
        Section {
            archipelagoLifecycleRow(
                title: lang.t("setup.archipelago.busyRule.title"),
                message: lang.t("setup.archipelago.busyRule.message"),
                systemImage: "bolt.fill",
                tint: .green
            )
            archipelagoLifecycleRow(
                title: lang.t("setup.archipelago.doneRule.title"),
                message: lang.t("setup.archipelago.doneRule.message"),
                systemImage: "checkmark.circle.fill",
                tint: .blue
            )
        } header: {
            Text(lang.t("setup.section.lifecycle"))
        } footer: {
            Text(lang.t("setup.archipelago.lifecycleFooter"))
        }
    }

    private var archipelagoAgentCount: Int {
        model.archipelago.groupChats.reduce(0) { $0 + $1.agents.count }
    }

    private var archipelagoStatusTitle: String {
        if model.archipelago.isLoading {
            return lang.t("setup.archipelago.status.loading")
        }
        return model.archipelago.isArchipelagoConnected
            ? lang.t("setup.archipelago.status.connected")
            : lang.t("setup.archipelago.status.disconnected")
    }

    private var archipelagoStatusMessage: String {
        if model.archipelago.isLoading {
            return lang.t("setup.archipelago.status.loadingMessage")
        }
        return model.archipelago.isArchipelagoConnected
            ? lang.t("setup.archipelago.status.connectedMessage")
            : (model.archipelago.connectionErrorMessage ?? lang.t("setup.archipelago.status.disconnectedMessage"))
    }

    private var archipelagoStatusIcon: String {
        if model.archipelago.isLoading { return "arrow.triangle.2.circlepath" }
        return model.archipelago.isArchipelagoConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var archipelagoStatusColor: Color {
        if model.archipelago.isLoading { return .secondary }
        return model.archipelago.isArchipelagoConnected ? .green : .orange
    }

    private func archipelagoLifecycleRow(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Watch

struct WatchSettingsPane: View {
    var model: AppModel

    @State private var pairingCode: String = "----"

    var body: some View {
        Form {
            Section {
                Toggle("Watch Notifications", isOn: Binding(
                    get: { model.watchNotificationEnabled },
                    set: { model.watchNotificationEnabled = $0 }
                ))

                if model.watchNotificationEnabled {
                    Text("When enabled, the macOS app broadcasts a Bonjour service that your iPhone can discover on the same WiFi network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("General")
            }

            if model.watchNotificationEnabled {
                Section("Pairing") {
                    HStack {
                        Text("Pairing Code")
                        Spacer()
                        Text(pairingCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                    }

                    Text("Enter this code on your iPhone app to pair. Code expires after 2 minutes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Refresh Code") {
                        model.watchRelay?.endpoint.regeneratePairingCode()
                        pairingCode = model.watchPairingCode
                    }
                }

                Section("Paired Devices") {
                    if model.watchConnectedDevices > 0 {
                        HStack {
                            Label("iPhone", systemImage: "iphone")
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 7, height: 7)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Label("No devices paired", systemImage: "iphone.slash")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Revoke All Pairings", role: .destructive) {
                        model.watchRelay?.endpoint.revokeAllTokens()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Watch")
        .onAppear {
            pairingCode = model.watchPairingCode
        }
    }
}

// MARK: - Placeholder

struct PlaceholderSettingsPane: View {
    var model: AppModel
    let titleKey: String
    let subtitleKey: String

    private var lang: LanguageManager { model.lang }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(lang.t(subtitleKey))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(lang.t(titleKey))
    }
}

// MARK: - Update Banner

struct UpdateBanner: View {
    let version: String
    let lang: LanguageManager
    var onUpdate: () -> Void

    var body: some View {
        Button(action: onUpdate) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(lang.t("settings.update.available", version))
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
    }
}
