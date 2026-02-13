import Foundation

nonisolated protocol ProcessMonitorProtocol: Sendable {
    func runningClaudePIDs() -> Set<Int32>
    func isProcessRunning(pid: Int32) -> Bool
    func parentPID(of pid: Int32) -> Int32?
    func processCwd(of pid: Int32) -> String?
    func guiAncestor(of pid: Int32) -> Int32?
}
