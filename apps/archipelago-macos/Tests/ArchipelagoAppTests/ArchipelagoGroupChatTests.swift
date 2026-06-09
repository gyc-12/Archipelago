import Darwin
import Foundation
import SQLite3
import Testing
@testable import ArchipelagoApp

struct ArchipelagoGroupChatTests {
    @Test
    func archipelagoWorkspaceURLUsesPrimaryConversation() throws {
        let group = GroupChat(
            id: "group-1",
            name: "Frontend",
            primaryAgentId: "codex-agent",
            agents: [
                GroupChat.GroupAgent(
                    id: "claude-agent",
                    agentType: .claudeCode,
                    role: "Coder",
                    conversationId: 41,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
                GroupChat.GroupAgent(
                    id: "codex-agent",
                    agentType: .codex,
                    role: "Reviewer",
                    conversationId: 42,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            folderId: 7,
            folderPath: "/tmp/project"
        )

        let url = try #require(group.archipelagoWorkspaceURL(baseURL: URL(string: "http://127.0.0.1:3079")!))
        #expect(url.absoluteString == "http://127.0.0.1:3079/workspace?folderId=7&conversationId=42&agent=codex")
    }

    @Test
    func archipelagoWorkspaceURLUsesRequestedAgentConversation() throws {
        let group = GroupChat(
            id: "group-1",
            name: "Frontend",
            primaryAgentId: "claude-agent",
            agents: [
                GroupChat.GroupAgent(
                    id: "claude-agent",
                    agentType: .claudeCode,
                    role: "主 Agent",
                    conversationId: 41,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
                GroupChat.GroupAgent(
                    id: "codex-agent",
                    agentType: .codex,
                    role: "Reviewer",
                    conversationId: 42,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            folderId: 7,
            folderPath: "/tmp/project"
        )

        let codexAgent = try #require(group.agents.first { $0.id == "codex-agent" })
        let url = try #require(group.archipelagoWorkspaceURL(
            baseURL: URL(string: "http://127.0.0.1:3079")!,
            agent: codexAgent
        ))

        #expect(url.absoluteString == "http://127.0.0.1:3079/workspace?folderId=7&conversationId=42&agent=codex")
    }

    @Test
    func archipelagoWorkspaceURLReturnsNilWithoutConversationBinding() {
        let group = GroupChat(
            id: "group-1",
            name: "Frontend",
            primaryAgentId: nil,
            agents: [
                GroupChat.GroupAgent(
                    id: "claude-agent",
                    agentType: .claudeCode,
                    role: "主 Agent",
                    conversationId: nil,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            folderId: 7,
            folderPath: "/tmp/project"
        )

        #expect(group.archipelagoWorkspaceURL(baseURL: URL(string: "http://127.0.0.1:3079")!) == nil)
    }

    @Test
    func archipelagoWebWindowRouterPreservesDefaultSettingsRoute() throws {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        let target = ArchipelagoWebWindowRouter.target(for: URL(string: "/settings"), baseURL: baseURL)

        guard case let .archipelagoSettings(url) = target else {
            Issue.record("Expected Archipelago settings target")
            return
        }
        #expect(url.absoluteString == "http://127.0.0.1:3079/settings")
    }

    @Test
    func archipelagoWebWindowRouterPreservesDefaultSettingsSubpage() throws {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        let target = ArchipelagoWebWindowRouter.target(for: URL(string: "/settings/appearance"), baseURL: baseURL)

        guard case let .archipelagoSettings(url) = target else {
            Issue.record("Expected Archipelago settings target")
            return
        }
        #expect(url.absoluteString == "http://127.0.0.1:3079/settings/appearance")
    }

    @Test
    func archipelagoWebWindowRouterPreservesAgentSettingsRouteAndQuery() throws {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        let target = ArchipelagoWebWindowRouter.target(
            for: URL(string: "http://127.0.0.1:3079/settings/agents?agent=codex"),
            baseURL: baseURL
        )

        guard case let .archipelagoSettings(url) = target else {
            Issue.record("Expected Archipelago settings target")
            return
        }
        #expect(url.absoluteString == "http://127.0.0.1:3079/settings/agents?agent=codex")
    }

    @Test
    func archipelagoWebWindowRouterRejectsCrossOriginSettingsRoutes() {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        let target = ArchipelagoWebWindowRouter.target(
            for: URL(string: "http://127.0.0.1:3080/settings/agents"),
            baseURL: baseURL
        )

        #expect(target == .external(URL(string: "http://127.0.0.1:3080/settings/agents")!))
    }

    @Test
    func archipelagoWebWindowRouterKeepsExternalLinksOutOfSettingsWindow() {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        let target = ArchipelagoWebWindowRouter.target(
            for: URL(string: "https://example.com/settings"),
            baseURL: baseURL
        )

        #expect(target == .external(URL(string: "https://example.com/settings")!))
    }

    @Test
    func archipelagoWebWindowRouterIgnoresUnsupportedSchemes() {
        let baseURL = URL(string: "http://127.0.0.1:3079")!

        #expect(ArchipelagoWebWindowRouter.target(for: URL(string: "about:blank"), baseURL: baseURL) == .ignore)
    }

    @Test
    func agentHubMVPTypesIncludeCurrentIslandCreateAgents() {
        #expect(ArchipelagoAgentType.agentHubMVPTypes == [.claudeCode, .codex, .gemini, .openCode])
        #expect(ArchipelagoAgentType.claudeCode.isAgentHubMVPType)
        #expect(ArchipelagoAgentType.codex.isAgentHubMVPType)
        #expect(ArchipelagoAgentType.gemini.isAgentHubMVPType)
        #expect(ArchipelagoAgentType.openCode.isAgentHubMVPType)
        #expect(!ArchipelagoAgentType.openClaw.isAgentHubMVPType)
        #expect(!ArchipelagoAgentType.cline.isAgentHubMVPType)
        #expect(!ArchipelagoAgentType.unknown.isAgentHubMVPType)
    }

    @Test
    func displayStatusMapsRuntimeStateForOverview() {
        let working = GroupChat.GroupAgent(
            id: "a",
            agentType: .codex,
            conversationId: 1,
            connectionId: nil,
            status: .prompting,
            workingDir: "/tmp/project"
        )
        let blocked = GroupChat.GroupAgent(
            id: "b",
            agentType: .codex,
            conversationId: 1,
            connectionId: nil,
            status: .connected,
            isBlocked: true,
            workingDir: "/tmp/project"
        )
        let offline = GroupChat.GroupAgent(
            id: "c",
            agentType: .codex,
            conversationId: 1,
            connectionId: nil,
            status: .error,
            workingDir: "/tmp/project"
        )

        #expect(working.displayStatus == .working)
        #expect(working.displayStatus.overviewLabel == "忙碌中")
        #expect(blocked.displayStatus == .idle)
        #expect(blocked.displayStatus.overviewLabel == "空闲中")
        #expect(offline.displayStatus == .idle)
        #expect(offline.displayStatus.overviewLabel == "空闲中")
    }

    @Test
    func archipelagoConnectionStatusDecodesRustTitleCaseValues() throws {
        struct Payload: Decodable { let status: ArchipelagoConnectionStatus }

        let payload = try JSONDecoder().decode(Payload.self, from: Data(#"{"status":"Prompting"}"#.utf8))

        #expect(payload.status == .prompting)
    }

    @Test
    func archipelagoGroupResponseDecodesNestedCamelCaseShape() throws {
        let json = """
        {
          "group": {
            "id": 301,
            "name": "Embedded Planning",
            "folderId": 101,
            "folderPath": "/tmp/project",
            "primaryAgentId": 402,
            "createdAt": "2026-06-03T00:00:00Z",
            "updatedAt": "2026-06-03T00:00:01Z"
          },
          "agents": [
            {
              "id": 401,
              "groupId": 301,
              "agentType": "claude_code",
              "role": "Lead",
              "conversationId": 201,
              "connectionId": "conn-claude",
              "workingDir": "/tmp/project",
              "createdAt": "2026-06-03T00:00:00Z",
              "updatedAt": "2026-06-03T00:00:01Z"
            },
            {
              "id": 402,
              "groupId": 301,
              "agentType": "codex",
              "role": "Reviewer",
              "conversationId": 202,
              "connectionId": null,
              "workingDir": "/tmp/project",
              "createdAt": "2026-06-03T00:00:00Z",
              "updatedAt": "2026-06-03T00:00:01Z"
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(ArchipelagoGroupChatResponse.self, from: Data(json.utf8))

        #expect(response.group.id == 301)
        #expect(response.group.primaryAgentId == 402)
        #expect(response.agents.map(\.agentType) == [.claudeCode, .codex])
        #expect(response.agents.map(\.conversationId) == [201, 202])
        #expect(response.agents.first?.connectionId == "conn-claude")
    }

    @Test
    func archipelagoWSClientDecodesGlobalIslandEventFrame() throws {
        let frameJSON: [String: Any] = [
            "channel": "island://group-deleted",
            "payload": [
                "groupId": 301,
                "folderId": 101,
            ],
        ]

        let frame = try #require(ArchipelagoWSClient.decodeGlobalEventFrame(frameJSON))
        let payload = try JSONDecoder().decode(ArchipelagoGroupDeletedPayload.self, from: frame.payload)

        #expect(frame.channel == "island://group-deleted")
        #expect(payload.groupId == 301)
        #expect(payload.folderId == 101)
    }

    @Test
    @MainActor
    func archipelagoGroupDetailHeightDoesNotUseEmptySessionFallback() {
        let group = GroupChat(
            id: "group-1",
            name: "Frontend",
            primaryAgentId: "agent-1",
            agents: [
                GroupChat.GroupAgent(
                    id: "agent-1",
                    agentType: .claudeCode,
                    role: "主 Agent",
                    conversationId: 11,
                    connectionId: nil,
                    status: .connected,
                    workingDir: "/tmp/project"
                ),
                GroupChat.GroupAgent(
                    id: "agent-2",
                    agentType: .codex,
                    role: "Reviewer",
                    conversationId: 12,
                    connectionId: nil,
                    status: .prompting,
                    workingDir: "/tmp/project"
                ),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            folderId: 7,
            folderPath: "/tmp/project"
        )

        let height = OverlayPanelController.estimatedArchipelagoContentHeight(
            contentState: .groupDetail(groupId: group.id),
            groupChats: [group]
        )

        #expect(height != nil)
        #expect(height! > 108)
    }

    @Test
    @MainActor
    func archipelagoGroupDetailHeightScalesWithLongAgentSummaries() {
        let agents = (0..<6).map { index in
            GroupChat.GroupAgent(
                id: "agent-\(index)",
                agentType: index.isMultiple(of: 2) ? .claudeCode : .codex,
                role: index == 0 ? "主 Agent" : "Reviewer",
                conversationId: 100 + index,
                connectionId: nil,
                status: index == 1 ? .prompting : .connected,
                workingDir: "/tmp/project",
                latestResponseSummary: "这是一段较长的最后回复摘要，用来验证详情页高度会跟随多个 Agent 内容增长，而不是被固定高度截断。",
                latestResponseAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        let group = GroupChat(
            id: "group-long",
            name: "Long Detail",
            primaryAgentId: "agent-0",
            agents: agents,
            createdAt: Date(timeIntervalSince1970: 0),
            folderId: 7,
            folderPath: "/tmp/project"
        )

        let height = OverlayPanelController.estimatedArchipelagoContentHeight(
            contentState: .groupDetail(groupId: group.id),
            groupChats: [group]
        )

        #expect(height != nil)
        #expect(height! > 430)
    }

    @Test
    func groupChatStoreRoundTripsMetadata() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-group-chat-\(UUID().uuidString).json")
        let store = ArchipelagoGroupChatStore(fileURL: fileURL)
        let groups = [
            GroupChat(
                id: "group-1",
                name: "Frontend",
                primaryAgentId: "agent-1",
                agents: [
                    GroupChat.GroupAgent(
                        id: "agent-1",
                        agentType: .claudeCode,
                        role: "主 Agent",
                        conversationId: 11,
                        connectionId: nil,
                        status: .connected,
                        workingDir: "/tmp/project"
                    ),
                ],
                createdAt: Date(timeIntervalSince1970: 123),
                folderId: 7,
                folderPath: "/tmp/project"
            ),
        ]

        store.save(groups)
        #expect(store.load() == groups)
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func webServiceConfigReaderLoadsTokenFromArchipelagoDatabase() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-config-\(UUID().uuidString).db")
        try createArchipelagoMetadataDatabase(at: fileURL, token: "local-token")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let reader = ArchipelagoWebServiceConfigReader(databasePaths: [fileURL.path])

        #expect(reader.loadToken() == "local-token")
    }

    @Test
    func webServiceConfigReaderIgnoresMissingDatabase() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-archipelago-config-\(UUID().uuidString).db")
        let reader = ArchipelagoWebServiceConfigReader(databasePaths: [fileURL.path])

        #expect(reader.loadToken() == nil)
    }

    @Test
    func embeddedRuntimeConfigBuildsArchipelagoServerEnvironment() throws {
        let serverURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-server-\(UUID().uuidString)")
        let staticURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-web-\(UUID().uuidString)", isDirectory: true)
        let dataURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-data-\(UUID().uuidString)", isDirectory: true)
        FileManager.default.createFile(atPath: serverURL.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: serverURL.path)
        try FileManager.default.createDirectory(at: staticURL, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: staticURL.appendingPathComponent("index.html").path, contents: Data())
        defer {
            try? FileManager.default.removeItem(at: serverURL)
            try? FileManager.default.removeItem(at: staticURL)
            try? FileManager.default.removeItem(at: dataURL)
        }

        let config = ArchipelagoEmbeddedRuntimeConfig(
            serverURL: serverURL,
            staticDirectoryURL: staticURL,
            dataDirectoryURL: dataURL,
            port: 3999,
            token: "embedded-token"
        )

        #expect(config.isAvailable)
        #expect(config.staticAssetsAvailable)
        #expect(config.bindHost == "0.0.0.0")
        #expect(config.environment["ARCHIPELAGO_HOST"] == "0.0.0.0")
        #expect(config.environment["ARCHIPELAGO_PORT"] == "3999")
        #expect(config.environment["ARCHIPELAGO_TOKEN"] == "embedded-token")
        #expect(config.environment["ARCHIPELAGO_DATA_DIR"] == dataURL.path)
        #expect(config.environment["ARCHIPELAGO_STATIC_DIR"] == staticURL.path)
    }

    @Test
    func embeddedRuntimeConfigFiltersInheritedProviderEnvironment() {
        let environment = ArchipelagoEmbeddedRuntimeConfig.sanitizedServerEnvironment(from: [
            "PATH": "/usr/bin",
            "HOME": "/Users/example",
            "OPENAI_API_KEY": "stale-disabled-key",
            "OPENAI_BASE_URL": "https://stale.example",
            "ANTHROPIC_AUTH_TOKEN": "stale-token",
            "ANTHROPIC_MODEL": "missing-model",
            "GEMINI_API_KEY": "stale-gemini-key",
            "GOOGLE_GEMINI_BASE_URL": "https://stale-gemini.example",
            "GOOGLE_API_KEY": "stale-google-key",
        ])

        #expect(environment["PATH"] == "/usr/bin")
        #expect(environment["HOME"] == "/Users/example")
        #expect(environment["OPENAI_API_KEY"] == nil)
        #expect(environment["OPENAI_BASE_URL"] == nil)
        #expect(environment["ANTHROPIC_AUTH_TOKEN"] == nil)
        #expect(environment["ANTHROPIC_MODEL"] == nil)
        #expect(environment["GEMINI_API_KEY"] == nil)
        #expect(environment["GOOGLE_GEMINI_BASE_URL"] == nil)
        #expect(environment["GOOGLE_API_KEY"] == nil)
    }

    @Test
    func embeddedRuntimeConfigResolvesOverridesFromEnvironment() {
        let env = [
            ArchipelagoEmbeddedRuntimeConfig.serverPathEnvKey: "/tmp/archipelago-server",
            ArchipelagoEmbeddedRuntimeConfig.staticDirEnvKey: "/tmp/archipelago-web",
            ArchipelagoEmbeddedRuntimeConfig.dataDirEnvKey: "/tmp/archipelago-data",
            ArchipelagoEmbeddedRuntimeConfig.hostEnvKey: "127.0.0.1",
            ArchipelagoEmbeddedRuntimeConfig.portEnvKey: "4123",
        ]

        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultServerURL(environment: env)?.path == "/tmp/archipelago-server")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultStaticDirectoryURL(environment: env)?.path == "/tmp/archipelago-web")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultDataDirectoryURL(environment: env).path == "/tmp/archipelago-data")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultBindHost(environment: env) == "127.0.0.1")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultBindHost(environment: [
            ArchipelagoEmbeddedRuntimeConfig.hostEnvKey: " ",
        ]) == "0.0.0.0")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultPort(environment: env) == 4123)
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultPort(environment: [
            ArchipelagoEmbeddedRuntimeConfig.portEnvKey: "not-a-port",
        ]) == 3079)
        #expect(ArchipelagoEmbeddedRuntimeConfig.hasExplicitPortOverride(environment: env))
        #expect(ArchipelagoEmbeddedRuntimeConfig.hasExplicitPortOverride(environment: [
            ArchipelagoEmbeddedRuntimeConfig.portEnvKey: "not-a-port",
        ]) == false)
    }

    func embeddedRuntimeConfigWithPortPreservesRuntimeSettings() {
        let serverURL = URL(fileURLWithPath: "/tmp/archipelago-server")
        let staticURL = URL(fileURLWithPath: "/tmp/archipelago-web")
        let dataURL = URL(fileURLWithPath: "/tmp/archipelago-data")
        let config = ArchipelagoEmbeddedRuntimeConfig(
            serverURL: serverURL,
            staticDirectoryURL: staticURL,
            dataDirectoryURL: dataURL,
            bindHost: "127.0.0.1",
            port: 3079,
            token: "embedded-token"
        )

        let fallback = config.withPort(3080)

        #expect(fallback.serverURL == serverURL)
        #expect(fallback.staticDirectoryURL == staticURL)
        #expect(fallback.dataDirectoryURL == dataURL)
        #expect(fallback.bindHost == "127.0.0.1")
        #expect(fallback.port == 3080)
        #expect(fallback.token == "embedded-token")
        #expect(fallback.environment["ARCHIPELAGO_HOST"] == "127.0.0.1")
        #expect(fallback.environment["ARCHIPELAGO_PORT"] == "3080")
    }

    @Test
    func embeddedRuntimeConfigUsesExplicitTokenEnvironmentOverride() throws {
        let defaults = try #require(UserDefaults(suiteName: "archipelago-embedded-token-\(UUID().uuidString)"))
        defer {
            defaults.removeObject(forKey: ArchipelagoEmbeddedRuntimeConfig.tokenDefaultsKey)
        }
        defaults.set("saved-token", forKey: ArchipelagoEmbeddedRuntimeConfig.tokenDefaultsKey)

        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultToken(environment: [
            ArchipelagoEmbeddedRuntimeConfig.tokenEnvKey: "env-token",
        ], defaults: defaults) == "env-token")
        #expect(ArchipelagoEmbeddedRuntimeConfig.defaultToken(environment: [
            ArchipelagoEmbeddedRuntimeConfig.tokenEnvKey: " ",
        ], defaults: defaults) == "saved-token")
    }

    @MainActor
    func externalArchipelagoWebFallbackIsOptInOnly() {
        #expect(ArchipelagoServerManager.defaultAllowsExternalFallback(environment: [:]) == false)
        #expect(ArchipelagoServerManager.defaultAllowsExternalFallback(environment: [
            ArchipelagoServerManager.externalFallbackEnvKey: "true",
        ]))
        #expect(ArchipelagoServerManager.defaultAllowsExternalFallback(environment: [
            ArchipelagoServerManager.externalFallbackEnvKey: "0",
        ]) == false)
    }

    @Test
    @MainActor
    func automaticPortFallbackIsDisabledOnlyForExplicitPortOverride() {
        #expect(ArchipelagoServerManager.defaultAllowsAutomaticPortFallback(environment: [:]))
        #expect(ArchipelagoServerManager.defaultAllowsAutomaticPortFallback(environment: [
            ArchipelagoEmbeddedRuntimeConfig.portEnvKey: " 3088 ",
        ]) == false)
        #expect(ArchipelagoServerManager.defaultAllowsAutomaticPortFallback(environment: [
            ArchipelagoEmbeddedRuntimeConfig.portEnvKey: "not-a-port",
        ]))
    }

    @Test
    @MainActor
    func fallbackPortCandidatesUseStableLoopbackRange() {
        #expect(ArchipelagoServerManager.fallbackPortCandidates(preferredPort: 3079) == Array(UInt16(3080)...UInt16(3099)))
        #expect(!ArchipelagoServerManager.fallbackPortCandidates(preferredPort: 3080).contains(3080))
        #expect(ArchipelagoServerManager.fallbackPortCandidates(preferredPort: 3080).first == 3081)
    }

    @Test
    @MainActor
    func serverManagerStartsEmbeddedHelperOnFallbackPortWhenPreferredPortIsOccupied() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-fallback-\(UUID().uuidString)", isDirectory: true)
        let helperURL = rootURL.appendingPathComponent("fake-archipelago-server.py")
        let occupierURL = rootURL.appendingPathComponent("port-occupier.py")
        let staticURL = rootURL.appendingPathComponent("ArchipelagoWeb", isDirectory: true)
        let dataURL = rootURL.appendingPathComponent("ArchipelagoData", isDirectory: true)
        let token = "fallback-token-\(UUID().uuidString)"
        let preferredPort = try availableTCPPort()

        try FileManager.default.createDirectory(at: staticURL, withIntermediateDirectories: true)
        try Data("<html>Archipelago</html>".utf8).write(to: staticURL.appendingPathComponent("index.html"))
        try writeExecutablePythonScript(fakeArchipelagoServerScript, to: helperURL)
        try writeExecutablePythonScript(portOccupierScript, to: occupierURL)

        let occupier = try launchScript(occupierURL, arguments: [String(preferredPort)])
        defer {
            terminate(occupier)
            try? FileManager.default.removeItem(at: rootURL)
        }
        try await waitForHealthStatus(port: preferredPort, token: token, statusCode: 404)

        let manager = ArchipelagoServerManager(
            embeddedConfig: ArchipelagoEmbeddedRuntimeConfig(
                serverURL: helperURL,
                staticDirectoryURL: staticURL,
                dataDirectoryURL: dataURL,
                port: preferredPort,
                token: token
            ),
            allowsExternalFallback: false,
            allowsAutomaticPortFallback: true
        )
        defer { manager.stop() }

        let started = await manager.start(token: token)

        #expect(started)
        #expect(manager.isRunning)
        #expect(manager.isUsingEmbeddedServer)
        #expect(manager.lastFailure == nil)
        #expect(manager.port != preferredPort)
        #expect(ArchipelagoServerManager.fallbackPortCandidates(preferredPort: preferredPort).contains(manager.port))
        #expect(manager.embeddedConfig.port == manager.port)
        #expect(manager.baseURL.port == Int(manager.port))
    }

    @Test
    @MainActor
    func coordinatorShutdownStopsEmbeddedServerManager() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-shutdown-\(UUID().uuidString)", isDirectory: true)
        let helperURL = rootURL.appendingPathComponent("fake-archipelago-server.py")
        let staticURL = rootURL.appendingPathComponent("ArchipelagoWeb", isDirectory: true)
        let dataURL = rootURL.appendingPathComponent("ArchipelagoData", isDirectory: true)
        let groupStoreURL = rootURL.appendingPathComponent("groups.json")
        let token = "shutdown-token-\(UUID().uuidString)"
        let port = try availableTCPPort()

        try FileManager.default.createDirectory(at: staticURL, withIntermediateDirectories: true)
        try Data("<html>Archipelago</html>".utf8).write(to: staticURL.appendingPathComponent("index.html"))
        try writeExecutablePythonScript(fakeArchipelagoServerScript, to: helperURL)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = ArchipelagoServerManager(
            embeddedConfig: ArchipelagoEmbeddedRuntimeConfig(
                serverURL: helperURL,
                staticDirectoryURL: staticURL,
                dataDirectoryURL: dataURL,
                port: port,
                token: token
            ),
            allowsExternalFallback: false,
            allowsAutomaticPortFallback: false
        )
        let coordinator = ArchipelagoCoordinator(
            serverManager: manager,
            groupStore: ArchipelagoGroupChatStore(fileURL: groupStoreURL)
        )

        let started = await manager.start(token: token)
        #expect(started)
        #expect(manager.isRunning)
        #expect(manager.isUsingEmbeddedServer)
        try await waitForHealthStatus(port: manager.port, token: token, statusCode: 200)

        coordinator.shutdown()

        #expect(manager.isRunning == false)
        #expect(manager.isUsingEmbeddedServer == false)
        #expect(coordinator.isArchipelagoConnected == false)
        try await waitForHealthUnavailable(port: port, token: token)
    }

    @Test
    @MainActor
    func coordinatorCreatesGroupChatThroughEmbeddedServer() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-create-group-\(UUID().uuidString)", isDirectory: true)
        let helperURL = rootURL.appendingPathComponent("fake-archipelago-server.py")
        let staticURL = rootURL.appendingPathComponent("ArchipelagoWeb", isDirectory: true)
        let dataURL = rootURL.appendingPathComponent("ArchipelagoData", isDirectory: true)
        let groupStoreURL = rootURL.appendingPathComponent("groups.json")
        let workspaceURL = rootURL.appendingPathComponent("trellis_try", isDirectory: true)
        let token = "create-group-token-\(UUID().uuidString)"
        let port = try availableTCPPort()

        try FileManager.default.createDirectory(at: staticURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try Data("<html>Archipelago</html>".utf8).write(to: staticURL.appendingPathComponent("index.html"))
        try writeExecutablePythonScript(fakeArchipelagoServerScript, to: helperURL)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = ArchipelagoServerManager(
            embeddedConfig: ArchipelagoEmbeddedRuntimeConfig(
                serverURL: helperURL,
                staticDirectoryURL: staticURL,
                dataDirectoryURL: dataURL,
                port: port,
                token: token
            ),
            allowsExternalFallback: false,
            allowsAutomaticPortFallback: false
        )
        let coordinator = ArchipelagoCoordinator(
            serverManager: manager,
            groupStore: ArchipelagoGroupChatStore(fileURL: groupStoreURL)
        )
        defer { coordinator.shutdown() }

        coordinator.boot()
        try await waitForArchipelagoConnected(coordinator)

        coordinator.createGroupChat(
            name: "11",
            folderPath: workspaceURL.path,
            members: [
                ArchipelagoGroupMemberDraft(agentType: .claudeCode, role: "Lead"),
                ArchipelagoGroupMemberDraft(agentType: .codex, role: "Reviewer"),
                ArchipelagoGroupMemberDraft(agentType: .gemini, role: "Planner"),
                ArchipelagoGroupMemberDraft(agentType: .openCode, role: "Implementer"),
            ],
            primaryAgentType: .codex
        )
        try await waitForGroupCount(coordinator, count: 1)

        let group = try #require(coordinator.groupChats.first)
        #expect(group.name == "11")
        #expect(group.folderId == 101)
        #expect(group.folderPath == workspaceURL.path)
        #expect(group.agents.map(\.agentType) == [.claudeCode, .codex, .gemini, .openCode])
        #expect(group.agents.compactMap(\.conversationId) == [201, 202, 203, 204])
        #expect(group.primaryAgent?.agentType == .codex)
        let archipelagoWorkspaceURL = try #require(group.archipelagoWorkspaceURL(baseURL: coordinator.archipelagoBaseURL))
        #expect(archipelagoWorkspaceURL.absoluteString.contains("conversationId=202"))
        let archipelagoClient = ArchipelagoClient(baseURL: coordinator.archipelagoBaseURL, token: coordinator.archipelagoToken)
        let conversations = try await archipelagoClient.listAllConversations(folderIds: [101])
        #expect(conversations.map(\.title) == [
            "trellis_try · Claude Code",
            "trellis_try · Codex",
            "trellis_try · Gemini",
            "trellis_try · OpenCode",
        ])
        #expect(!conversations.contains { ($0.title ?? "").hasPrefix("11 ·") })
        #expect(ArchipelagoGroupChatStore(fileURL: groupStoreURL).load() == [group])
    }

    @Test
    @MainActor
    func coordinatorDoesNotReplaceArchipelagoCreatedGroupAgentConversation() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archipelago-created-agent-\(UUID().uuidString)", isDirectory: true)
        let helperURL = rootURL.appendingPathComponent("fake-archipelago-server.py")
        let staticURL = rootURL.appendingPathComponent("ArchipelagoWeb", isDirectory: true)
        let dataURL = rootURL.appendingPathComponent("ArchipelagoData", isDirectory: true)
        let groupStoreURL = rootURL.appendingPathComponent("groups.json")
        let workspaceURL = rootURL.appendingPathComponent("trellis_try", isDirectory: true)
        let token = "archipelago-created-agent-token-\(UUID().uuidString)"
        let port = try availableTCPPort()

        try FileManager.default.createDirectory(at: staticURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try Data("<html>Archipelago</html>".utf8).write(to: staticURL.appendingPathComponent("index.html"))
        try writeExecutablePythonScript(fakeArchipelagoServerScript, to: helperURL)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = ArchipelagoServerManager(
            embeddedConfig: ArchipelagoEmbeddedRuntimeConfig(
                serverURL: helperURL,
                staticDirectoryURL: staticURL,
                dataDirectoryURL: dataURL,
                port: port,
                token: token
            ),
            allowsExternalFallback: false,
            allowsAutomaticPortFallback: false
        )
        let coordinator = ArchipelagoCoordinator(
            serverManager: manager,
            groupStore: ArchipelagoGroupChatStore(fileURL: groupStoreURL)
        )
        defer { coordinator.shutdown() }

        coordinator.boot()
        try await waitForArchipelagoConnected(coordinator)

        coordinator.createGroupChat(
            name: "12",
            folderPath: workspaceURL.path,
            members: [
                ArchipelagoGroupMemberDraft(agentType: .claudeCode, role: "Lead"),
                ArchipelagoGroupMemberDraft(agentType: .codex, role: "Reviewer"),
            ],
            primaryAgentType: .claudeCode
        )
        try await waitForGroupCount(coordinator, count: 1)

        let initialGroup = try #require(coordinator.groupChats.first)
        let groupId = try #require(Int(initialGroup.id))
        let archipelagoClient = ArchipelagoClient(baseURL: coordinator.archipelagoBaseURL, token: coordinator.archipelagoToken)
        let openCodeConversationId = try await archipelagoClient.createConversation(
            folderId: 101,
            agentType: .openCode,
            title: "你好"
        )
        _ = try await archipelagoClient.addGroupAgent(
            groupId: groupId,
            agentType: .openCode,
            role: "Implementer",
            conversationId: openCodeConversationId,
            connectionId: nil,
            workingDir: workspaceURL.path
        )

        await coordinator.loadGroupsFromServer()

        let group = try #require(coordinator.groupChats.first)
        let openCodeAgent = try #require(group.agents.first { $0.agentType == .openCode })
        #expect(openCodeAgent.conversationId == openCodeConversationId)

        let openCodeConversations = try await archipelagoClient
            .listAllConversations(folderIds: [101])
            .filter { $0.agentType == .openCode }
        #expect(openCodeConversations.map(\.id) == [openCodeConversationId])
        #expect(openCodeConversations.map(\.title) == ["你好"])
    }

    @Test
    @MainActor
    func existingServiceProbeMapsToRecoverableStartupFailures() {
        #expect(ArchipelagoServerManager.startupFailureForExistingService(
            .healthy,
            port: 3079,
            isTCPPortOpen: true
        ) == nil)
        #expect(ArchipelagoServerManager.startupFailureForExistingService(
            .unauthorized,
            port: 3079,
            isTCPPortOpen: true
        ) == .embeddedTokenMismatch(3079))
        #expect(ArchipelagoServerManager.startupFailureForExistingService(
            .httpStatus(404),
            port: 3079,
            isTCPPortOpen: true
        ) == .embeddedPortUnavailable(3079, 404))
        #expect(ArchipelagoServerManager.startupFailureForExistingService(
            .unreachable,
            port: 3079,
            isTCPPortOpen: true
        ) == .embeddedPortUnavailable(3079, nil))
        #expect(ArchipelagoServerManager.startupFailureForExistingService(
            .unreachable,
            port: 3079,
            isTCPPortOpen: false
        ) == nil)
    }

    @Test
    @MainActor
    func coordinatorUsesEmbeddedTokenByDefault() throws {
        let externalDB = FileManager.default.temporaryDirectory
            .appendingPathComponent("external-archipelago-token-\(UUID().uuidString).db")
        try createArchipelagoMetadataDatabase(at: externalDB, token: "external-token")
        defer { try? FileManager.default.removeItem(at: externalDB) }

        let coordinator = ArchipelagoCoordinator(
            groupStore: ArchipelagoGroupChatStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("groups-\(UUID().uuidString).json")
            ),
            webServiceConfigReader: ArchipelagoWebServiceConfigReader(databasePaths: [externalDB.path])
        )

        #expect(coordinator.archipelagoToken == coordinator.serverManager.embeddedConfig.token)
        #expect(coordinator.archipelagoToken != "external-token")
    }

    @Test
    func embeddedRuntimeConfigPersistsGeneratedToken() throws {
        let defaults = try #require(UserDefaults(suiteName: "archipelago-embedded-\(UUID().uuidString)"))
        defer {
            defaults.removeObject(forKey: ArchipelagoEmbeddedRuntimeConfig.tokenDefaultsKey)
        }

        let first = ArchipelagoEmbeddedRuntimeConfig.loadOrCreateToken(defaults: defaults)
        let second = ArchipelagoEmbeddedRuntimeConfig.loadOrCreateToken(defaults: defaults)

        #expect(!first.isEmpty)
        #expect(first == second)
    }

    private func createArchipelagoMetadataDatabase(at fileURL: URL, token: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw TestError.sqliteOpen
        }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE app_metadata (
            id INTEGER PRIMARY KEY,
            key TEXT NOT NULL UNIQUE,
            value TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        );
        """

        guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
            throw TestError.sqliteExec
        }

        let insertSQL = """
        INSERT INTO app_metadata (key, value, created_at, updated_at, deleted_at)
        VALUES (?, ?, '2026-01-01', '2026-01-01', NULL);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw TestError.sqliteExec
        }
        defer { sqlite3_finalize(stmt) }

        let key = strdup("web_service_token")
        let value = strdup(token)
        defer {
            free(key)
            free(value)
        }
        sqlite3_bind_text(stmt, 1, key, -1, nil)
        sqlite3_bind_text(stmt, 2, value, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw TestError.sqliteExec
        }
    }

    private func availableTCPPort() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw TestError.socketUnavailable
        }
        defer { close(descriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw TestError.socketUnavailable
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(descriptor, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else {
            throw TestError.socketUnavailable
        }
        return UInt16(bigEndian: boundAddress.sin_port)
    }

    private func writeExecutablePythonScript(_ contents: String, to fileURL: URL) throws {
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
    }

    private func launchScript(_ fileURL: URL, arguments: [String]) throws -> Process {
        let process = Process()
        process.executableURL = fileURL
        process.arguments = arguments
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        try process.run()
        return process
    }

    private func terminate(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()
    }

    private func waitForHealthStatus(
        port: UInt16,
        token: String,
        statusCode: Int,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastStatus: Int?
        while Date() < deadline {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/health")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8)
            request.timeoutInterval = 0.5
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    lastStatus = http.statusCode
                    if http.statusCode == statusCode {
                        return
                    }
                }
            } catch {
                lastStatus = nil
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw TestError.httpServerNotReady(lastStatus)
    }

    private func waitForHealthUnavailable(
        port: UInt16,
        token: String,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastStatus: Int?
        while Date() < deadline {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/health")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{}".data(using: .utf8)
            request.timeoutInterval = 0.5
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    lastStatus = http.statusCode
                }
            } catch {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw TestError.httpServerStillReachable(lastStatus)
    }

    @MainActor
    private func waitForArchipelagoConnected(
        _ coordinator: ArchipelagoCoordinator,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if coordinator.isArchipelagoConnected {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw TestError.coordinatorNotConnected(coordinator.connectionErrorMessage)
    }

    @MainActor
    private func waitForGroupCount(
        _ coordinator: ArchipelagoCoordinator,
        count: Int,
        timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if coordinator.groupChats.count == count {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw TestError.groupChatCountMismatch(coordinator.groupChats.count)
    }

    private var fakeArchipelagoServerScript: String {
        """
        #!/usr/bin/env python3
        import http.server
        import json
        import os

        port = int(os.environ["ARCHIPELAGO_PORT"])
        token = os.environ["ARCHIPELAGO_TOKEN"]
        next_conversation_id = 201
        next_group_id = 301
        next_group_agent_id = 401
        conversations = {}
        groups = {}
        group_agents = []

        def group_response(group_id):
            group = groups[group_id]
            return {
                "group": group,
                "agents": [agent for agent in group_agents if agent["group_id"] == group_id],
            }

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def read_json(self):
                size = int(self.headers.get("Content-Length", "0") or "0")
                if size == 0:
                    return {}
                return json.loads(self.rfile.read(size).decode("utf-8"))

            def write_json(self, value):
                payload = json.dumps(value).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

            def do_POST(self):
                global next_conversation_id

                if self.path == "/api/health":
                    if self.headers.get("Authorization") != f"Bearer {token}":
                        self.send_response(401)
                        self.end_headers()
                        return
                    self.write_json({"ok": True})
                    return

                if self.headers.get("Authorization") != f"Bearer {token}":
                    self.send_response(401)
                    self.end_headers()
                    return

                if self.path == "/api/acp_list_agents":
                    self.write_json([
                        {
                            "agent_type": "claude_code",
                            "name": "Claude Code",
                            "description": "Fake Claude agent",
                            "available": True,
                            "enabled": True,
                        },
                        {
                            "agent_type": "codex",
                            "name": "Codex",
                            "description": "Fake Codex agent",
                            "available": True,
                            "enabled": True,
                        },
                        {
                            "agent_type": "gemini",
                            "name": "Gemini",
                            "description": "Fake Gemini agent",
                            "available": True,
                            "enabled": True,
                        },
                        {
                            "agent_type": "open_code",
                            "name": "OpenCode",
                            "description": "Fake OpenCode agent",
                            "available": True,
                            "enabled": True,
                        },
                    ])
                    return

                if self.path == "/api/open_folder":
                    body = self.read_json()
                    path = body.get("path", "")
                    self.write_json({"id": 101, "name": os.path.basename(path), "path": path})
                    return

                if self.path == "/api/list_groups":
                    self.write_json([group_response(group_id) for group_id in groups.keys()])
                    return

                if self.path == "/api/list_all_conversations":
                    body = self.read_json()
                    folder_ids = body.get("folderIds")
                    agent_type = body.get("agentType")
                    rows = []
                    for conversation in conversations.values():
                        if conversation.get("deleted_at") is not None:
                            continue
                        if folder_ids is not None and conversation["folder_id"] not in folder_ids:
                            continue
                        if agent_type is not None and conversation["agent_type"] != agent_type:
                            continue
                        rows.append(conversation)
                    self.write_json(rows)
                    return

                if self.path == "/api/create_group":
                    global next_group_id
                    body = self.read_json()
                    group_id = next_group_id
                    next_group_id += 1
                    groups[group_id] = {
                        "id": group_id,
                        "name": body.get("name", ""),
                        "folder_id": body.get("folderId"),
                        "folder_path": body.get("folderPath"),
                        "primary_agent_id": None,
                        "created_at": "2026-06-03T00:00:00Z",
                        "updated_at": "2026-06-03T00:00:00Z",
                    }
                    self.write_json(group_response(group_id))
                    return

                if self.path == "/api/create_conversation":
                    body = self.read_json()
                    conversation_id = next_conversation_id
                    next_conversation_id += 1
                    conversations[conversation_id] = {
                        "id": conversation_id,
                        "folder_id": body.get("folderId"),
                        "title": body.get("title"),
                        "agent_type": body.get("agentType"),
                        "status": "in_progress",
                        "model": None,
                        "git_branch": None,
                        "external_id": None,
                        "message_count": 0,
                        "created_at": "2026-06-03T00:00:00Z",
                        "updated_at": "2026-06-03T00:00:00Z",
                        "deleted_at": None,
                    }
                    self.write_json(conversation_id)
                    return

                if self.path == "/api/update_conversation_title":
                    body = self.read_json()
                    conversation_id = body.get("conversationId")
                    if conversation_id in conversations:
                        conversations[conversation_id]["title"] = body.get("title")
                        conversations[conversation_id]["updated_at"] = "2026-06-03T00:00:01Z"
                        self.write_json({})
                        return
                    self.send_response(404)
                    self.end_headers()
                    return

                if self.path == "/api/delete_conversation":
                    body = self.read_json()
                    conversation_id = body.get("conversationId")
                    if conversation_id in conversations:
                        conversations[conversation_id]["deleted_at"] = "2026-06-03T00:00:01Z"
                        self.write_json({})
                        return
                    self.send_response(404)
                    self.end_headers()
                    return

                if self.path == "/api/add_group_agent":
                    global next_group_agent_id
                    body = self.read_json()
                    agent_id = next_group_agent_id
                    next_group_agent_id += 1
                    agent = {
                        "id": agent_id,
                        "group_id": body.get("groupId"),
                        "agent_type": body.get("agentType"),
                        "role": body.get("role"),
                        "conversation_id": body.get("conversationId"),
                        "connection_id": body.get("connectionId"),
                        "working_dir": body.get("workingDir"),
                        "created_at": "2026-06-03T00:00:00Z",
                        "updated_at": "2026-06-03T00:00:00Z",
                    }
                    group_agents.append(agent)
                    self.write_json(agent)
                    return

                if self.path == "/api/update_group":
                    body = self.read_json()
                    group_id = body.get("id")
                    if group_id in groups:
                        if "name" in body and body.get("name") is not None:
                            groups[group_id]["name"] = body.get("name")
                        if "primaryAgentId" in body:
                            groups[group_id]["primary_agent_id"] = body.get("primaryAgentId")
                        groups[group_id]["updated_at"] = "2026-06-03T00:00:01Z"
                        self.write_json(group_response(group_id))
                        return
                    self.send_response(404)
                    self.end_headers()
                    return

                if self.path == "/api/update_group_agent":
                    body = self.read_json()
                    agent_id = body.get("id")
                    for agent in group_agents:
                        if agent["id"] == agent_id:
                            if "role" in body and body.get("role") is not None:
                                agent["role"] = body.get("role")
                            if "connectionId" in body:
                                agent["connection_id"] = body.get("connectionId")
                            if "conversationId" in body:
                                agent["conversation_id"] = body.get("conversationId")
                            agent["updated_at"] = "2026-06-03T00:00:01Z"
                            self.write_json(agent)
                            return
                    self.send_response(404)
                    self.end_headers()
                    return

                if self.path == "/api/acp_list_connections":
                    self.write_json([])
                    return

                if self.path.startswith("/api/"):
                    self.send_response(404)
                    self.end_headers()
                    return

            def do_GET(self):
                self.send_response(404)
                self.end_headers()

        http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
        """
    }

    private var portOccupierScript: String {
        """
        #!/usr/bin/env python3
        import http.server
        import sys

        port = int(sys.argv[1])

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                self.send_response(404)
                self.end_headers()

            def do_GET(self):
                self.send_response(404)
                self.end_headers()

        http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
        """
    }
}

private enum TestError: Error {
    case sqliteOpen
    case sqliteExec
    case socketUnavailable
    case httpServerNotReady(Int?)
    case httpServerStillReachable(Int?)
    case coordinatorNotConnected(String?)
    case groupChatCountMismatch(Int)
}
