import Foundation

nonisolated protocol HookSocketServerProtocol: Sendable {
    func start(onEvent: @escaping @Sendable (HookEvent) -> Void)
    func stop()
}
