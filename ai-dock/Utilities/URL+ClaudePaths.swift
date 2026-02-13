import Foundation

nonisolated extension URL {
    static var claudeHome: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    static var claudeProjects: URL {
        claudeHome.appendingPathComponent("projects")
    }

    static var claudeIDE: URL {
        claudeHome.appendingPathComponent("ide")
    }
}
