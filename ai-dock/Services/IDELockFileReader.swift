import Foundation

nonisolated struct IDELockFileReader: Sendable {
    func parseIDELockFiles() -> [IDELockFile] {
        let ideDir = URL.claudeIDE
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(
            at: ideDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return [] }

        return files.compactMap { file -> IDELockFile? in
            guard file.pathExtension == "lock" else { return nil }
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? JSONDecoder().decode(IDELockFile.self, from: data)
        }
    }
}
