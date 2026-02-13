import Foundation

nonisolated final class HookSocketServer: HookSocketServerProtocol, @unchecked Sendable {
    static let socketPath = "/tmp/claude-island.sock"

    private var serverFD: Int32 = -1
    private var running = false
    private let queue = DispatchQueue(label: "io.github.ai-dock.socket", qos: .userInitiated)
    private let acceptSource: UnsafeMutablePointer<DispatchSourceRead?> = .allocate(capacity: 1)

    init() {
        acceptSource.initialize(to: nil)
    }

    deinit {
        stop()
        acceptSource.deallocate()
    }

    func start(onEvent: @escaping @Sendable (HookEvent) -> Void) {
        queue.async { [weak self] in
            self?.startServer(onEvent: onEvent)
        }
    }

    func stop() {
        queue.sync { [weak self] in
            guard let self else { return }
            self.running = false
            self.acceptSource.pointee?.cancel()
            self.acceptSource.pointee = nil
            if self.serverFD >= 0 {
                close(self.serverFD)
                self.serverFD = -1
            }
            unlink(Self.socketPath)
        }
    }

    private func startServer(onEvent: @escaping @Sendable (HookEvent) -> Void) {
        // Clean up stale socket
        unlink(Self.socketPath)

        // Create Unix domain socket
        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            print("[ai-dock] socket() failed: \(errno)")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Self.socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                for (i, byte) in pathBytes.enumerated() where i < 104 {
                    dest[i] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFD, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            let err = errno
            print("[ai-dock] bind(\(Self.socketPath)) failed: \(err)")
            close(serverFD)
            serverFD = -1
            return
        }

        // Make socket world-writable so the hook script (running as the user) can connect
        chmod(Self.socketPath, 0o777)

        guard listen(serverFD, 16) == 0 else {
            let err = errno
            print("[ai-dock] listen() failed: \(err)")
            close(serverFD)
            serverFD = -1
            return
        }

        // Set non-blocking
        let flags = fcntl(serverFD, F_GETFL)
        _ = fcntl(serverFD, F_SETFL, flags | O_NONBLOCK)

        running = true
        print("[ai-dock] socket listening at \(Self.socketPath)")

        // Use GCD dispatch source for accept
        let source = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: queue)
        acceptSource.pointee = source

        source.setEventHandler { [weak self] in
            self?.acceptConnections(onEvent: onEvent)
        }

        source.setCancelHandler { [weak self] in
            guard let self, self.serverFD >= 0 else { return }
            close(self.serverFD)
            self.serverFD = -1
        }

        source.resume()
    }

    private func acceptConnections(onEvent: @escaping @Sendable (HookEvent) -> Void) {
        while running {
            var clientAddr = sockaddr_un()
            var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverFD, sockPtr, &addrLen)
                }
            }

            guard clientFD >= 0 else { break }

            // Handle client on a separate queue to not block accept loop
            DispatchQueue.global(qos: .userInitiated).async {
                self.handleClient(fd: clientFD, onEvent: onEvent)
            }
        }
    }

    private func handleClient(fd: Int32, onEvent: @escaping @Sendable (HookEvent) -> Void) {
        defer { close(fd) }

        // Set read timeout
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Read data (hook messages are small, 4KB is plenty)
        var buffer = [UInt8](repeating: 0, count: 4096)
        var data = Data()

        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            data.append(contentsOf: buffer[..<bytesRead])
            if bytesRead < buffer.count { break }
        }

        guard !data.isEmpty else { return }

        do {
            let event = try JSONDecoder().decode(HookEvent.self, from: data)
            onEvent(event)
        } catch {
            print("[ai-dock] malformed socket event: \(error.localizedDescription)")
        }
    }
}
