import Foundation
import SQLite3

struct ArchipelagoWebServiceConfigReader {
    var databasePaths: [String]

    init(databasePaths: [String] = Self.defaultDatabasePaths()) {
        self.databasePaths = databasePaths
    }

    static func defaultDatabasePaths() -> [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Library/Application Support/app.archipelago.web/archipelago.db",
            home + "/Library/Application Support/Archipelago/Server/archipelago.db",
            home + "/.archipelago/archipelago.db",
        ]
    }

    func loadToken() -> String? {
        for path in databasePaths {
            if let token = loadToken(databasePath: path) {
                return token
            }
        }
        return nil
    }

    private func loadToken(databasePath: String) -> String? {
        guard FileManager.default.fileExists(atPath: databasePath) else { return nil }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databasePath, &db, flags, nil) == SQLITE_OK else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 100)

        let sql = """
        SELECT value
        FROM app_metadata
        WHERE key = ? AND deleted_at IS NULL
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        let keyCString = strdup("web_service_token")
        defer { free(keyCString) }
        sqlite3_bind_text(stmt, 1, keyCString, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0) else {
            return nil
        }

        let token = String(cString: cString).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
