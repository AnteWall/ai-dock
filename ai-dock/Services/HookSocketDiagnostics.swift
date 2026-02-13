import Foundation
import Darwin

enum HookSocketDiagnostics {
    static func socketExists() -> Bool {
        FileManager.default.fileExists(atPath: HookSocketServer.socketPath)
    }

    static func sendTestEvent(source: SessionSource = .opencode) throws {
        let payload: [String: Any] = [
            "session_id": "manual-test-\(UUID().uuidString)",
            "cwd": FileManager.default.currentDirectoryPath,
            "event": "manual-test",
            "status": "processing",
            "source": source.rawValue,
            "pid": Int(getpid()),
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)

        for attempt in 0..<2 {
            do {
                try transmit(data: data)
                return
            } catch {
                let nsError = error as NSError
                if nsError.code == EPIPE || nsError.code == ECONNRESET {
                    if attempt == 0 {
                        continue
                    }
                }
                throw error
            }
        }
    }

    private static func transmit(data: Data) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NSError(domain: "HookSocketDiagnostics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        defer { close(fd) }

        var noSigPipe: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = HookSocketServer.socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                for (i, byte) in pathBytes.enumerated() where i < 104 {
                    dest[i] = byte
                }
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            let err = errno
            let message = String(cString: strerror(err))
            throw NSError(domain: "HookSocketDiagnostics", code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Could not connect to \(HookSocketServer.socketPath): \(message) (errno \(err))"])
        }

        let written = data.withUnsafeBytes { bytes in
            Darwin.send(fd, bytes.baseAddress, bytes.count, 0)
        }
        if written < 0 {
            let err = errno
            let message = String(cString: strerror(err))
            throw NSError(domain: "HookSocketDiagnostics", code: Int(err), userInfo: [NSLocalizedDescriptionKey: "Failed to write test event to socket: \(message) (errno \(err))"])
        }
    }
}
