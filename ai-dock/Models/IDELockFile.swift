import Foundation

nonisolated struct IDELockFile: Decodable, Sendable {
    let pid: Int32
    let workspaceFolders: [String]?
    let ideName: String?
    let transport: String?
}
