import Foundation

struct ArchipelagoGroupChatStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() -> [GroupChat] {
        let data = try? Data(contentsOf: fileURL)
        guard let data else { return [] }
        do {
            return try decoder.decode([GroupChat].self, from: data)
        } catch {
            NSLog("[ArchipelagoGroupChatStore] failed to load group chats: \(error)")
            return []
        }
    }

    func save(_ groupChats: [GroupChat]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(groupChats)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[ArchipelagoGroupChatStore] failed to save group chats: \(error)")
        }
    }

    private static func defaultFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("Archipelago", isDirectory: true)
            .appendingPathComponent("archipelago-group-chats.json")
    }
}
