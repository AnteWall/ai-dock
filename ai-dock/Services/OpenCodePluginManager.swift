import Foundation

enum OpenCodePluginStatus: Sendable {
    case installed
    case notInstalled
    case notDetected
    case outdated
    case error(String)
}

enum OpenCodePluginError: LocalizedError {
    case configNotFound
    case pluginWriteFailed(String)
    case pluginRemoveFailed(String)

    var errorDescription: String? {
        switch self {
        case .configNotFound:
            return "OpenCode config directory not found"
        case .pluginWriteFailed(let message):
            return "Failed to write OpenCode plugin: \(message)"
        case .pluginRemoveFailed(let message):
            return "Failed to remove OpenCode plugin: \(message)"
        }
    }
}

nonisolated struct OpenCodePluginManager: Sendable {
    static let configDirPath = "~/.config/opencode"
    static let pluginsDirPath = "~/.config/opencode/plugins"
    static let pluginFileName = "ai-dock-opencode.js"

    var pluginPath: String {
        resolvedURL(Self.pluginsDirPath).appendingPathComponent(Self.pluginFileName).path
    }

    var pluginStatusPath: String {
        resolvedURL(Self.pluginsDirPath).appendingPathComponent("ai-dock-opencode.status.json").path
    }

    func readPluginRuntimeStatus() -> String? {
        let url = URL(fileURLWithPath: pluginStatusPath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func checkStatus() -> OpenCodePluginStatus {
        let configDir = resolvedURL(Self.configDirPath)
        guard FileManager.default.fileExists(atPath: configDir.path) else {
            return .notDetected
        }

        let pluginURL = resolvedURL(Self.pluginsDirPath).appendingPathComponent(Self.pluginFileName)
        guard FileManager.default.fileExists(atPath: pluginURL.path) else {
            return .notInstalled
        }

        guard let existing = try? String(contentsOf: pluginURL, encoding: .utf8) else {
            return .error("Unable to read plugin file")
        }

        if existing == pluginContent {
            return .installed
        }
        return .outdated
    }

    func install() throws {
        let configDir = resolvedURL(Self.configDirPath)
        guard FileManager.default.fileExists(atPath: configDir.path) else {
            throw OpenCodePluginError.configNotFound
        }

        let pluginsDir = resolvedURL(Self.pluginsDirPath)
        try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

        let pluginURL = pluginsDir.appendingPathComponent(Self.pluginFileName)
        do {
            try pluginContent.write(to: pluginURL, atomically: true, encoding: .utf8)
        } catch {
            throw OpenCodePluginError.pluginWriteFailed(error.localizedDescription)
        }
    }

    func uninstall() throws {
        let pluginURL = resolvedURL(Self.pluginsDirPath).appendingPathComponent(Self.pluginFileName)
        guard FileManager.default.fileExists(atPath: pluginURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: pluginURL)
        } catch {
            throw OpenCodePluginError.pluginRemoveFailed(error.localizedDescription)
        }
    }

    private func resolvedURL(_ tilded: String) -> URL {
        let expanded = NSString(string: tilded).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
    }

    private var pluginContent: String {
        """
        export const AIDockOpenCodePlugin = async ({ client }) => {
          const net = await import("net")
          const fs = await import("node:fs/promises")
          const socketPath = "/tmp/claude-island.sock"
          const source = "opencode"
          const sessionDirectory = new Map()
          let lastSessionId = null
          const home = process.env.HOME || ""
          const statusPath = home ? `${home}/.config/opencode/plugins/ai-dock-opencode.status.json` : "/tmp/ai-dock-opencode.status.json"
          const eventsPath = home ? `${home}/.config/opencode/plugins/ai-dock-opencode.events.log` : "/tmp/ai-dock-opencode.events.log"

          const writeStatus = async (patch) => {
            const state = {
              plugin: "ai-dock-opencode",
              updatedAt: new Date().toISOString(),
              ...patch,
            }
            try {
              await fs.writeFile(statusPath, JSON.stringify(state), "utf8")
            } catch {}
          }

          const log = async (message, extra = {}) => {
            try {
              await client.app.log({
                body: {
                  service: "ai-dock-opencode",
                  level: "debug",
                  message,
                  extra,
                },
              })
            } catch {}
          }

          const appendEvent = async (line) => {
            try {
              await fs.appendFile(eventsPath, `${new Date().toISOString()} ${line}\n`, "utf8")
            } catch {}
          }

          const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

          const sendEvent = async (state) => {
            for (let attempt = 0; attempt < 3; attempt++) {
              const delivered = await new Promise((resolve) => {
                const client = net.createConnection(socketPath, () => {
                  try {
                    client.end(JSON.stringify(state))
                    resolve(true)
                  } catch {
                    client.end()
                    resolve(false)
                  }
                })
                client.on("error", () => resolve(false))
              })
              if (delivered) return true
              if (attempt < 2) {
                await delay(30)
              }
            }
            return false
          }

          const updateSessionInfo = (info) => {
            if (info && info.id && info.directory) {
              sessionDirectory.set(info.id, info.directory)
            }
          }

          const getCwd = (sessionId, fallback) => {
            if (fallback) return fallback
            if (sessionId && sessionDirectory.has(sessionId)) {
              return sessionDirectory.get(sessionId)
            }
            return ""
          }

          const emitStatus = async ({ sessionId, cwd, status, event }) => {
            if (!sessionId || !status) return
            const delivered = await sendEvent({
              session_id: sessionId,
              cwd: cwd || "",
              event: event || "opencode",
              status,
              pid: process.pid,
              source
            })
            if (delivered) {
              await writeStatus({
                state: "event-forwarded",
                event,
                sessionId,
                status,
                cwd: cwd || "",
              })
              await appendEvent(`forwarded ${event} session=${sessionId} status=${status}`)
            } else {
              await writeStatus({
                state: "socket-write-failed",
                event,
                sessionId,
                status,
                cwd: cwd || "",
              })
              await appendEvent(`dropped ${event} session=${sessionId} status=${status}`)
            }
          }

          const eventPayload = (event) => event?.payload || event
          const deepSessionId = (value, depth = 0) => {
            if (!value || depth > 5) return null
            if (typeof value === "string") {
              return value.startsWith("ses_") ? value : null
            }
            if (Array.isArray(value)) {
              for (const item of value) {
                const found = deepSessionId(item, depth + 1)
                if (found) return found
              }
              return null
            }
            if (typeof value === "object") {
              const direct = value.sessionID || value.sessionId || value.id
              if (typeof direct === "string" && direct.startsWith("ses_")) {
                return direct
              }
              for (const key of Object.keys(value)) {
                const found = deepSessionId(value[key], depth + 1)
                if (found) return found
              }
            }
            return null
          }

          const sessionIdFrom = (properties, payload) =>
            properties?.sessionID ||
            properties?.sessionId ||
            properties?.info?.sessionID ||
            properties?.info?.sessionId ||
            properties?.permission?.sessionID ||
            properties?.permission?.sessionId ||
            deepSessionId(properties) ||
            deepSessionId(payload)

          const rememberSessionId = (sessionId) => {
            if (sessionId) {
              lastSessionId = sessionId
            }
          }

          await writeStatus({ state: "initialized" })
          await log("plugin initialized", { socketPath, statusPath })

          return {
            event: async ({ event }) => {
              const payload = eventPayload(event)
              const type = payload?.type
              const properties = payload?.properties || {}
              if (!type) return

              await writeStatus({ state: "event-seen", event: type })
              await appendEvent(`seen ${type}`)

              if (type === "server.instance.disposed") {
                if (lastSessionId) {
                  await emitStatus({
                    sessionId: lastSessionId,
                    cwd: getCwd(lastSessionId),
                    status: "waiting_for_input",
                    event: type,
                  })
                }
                return
              }

              if (type === "session.created" || type === "session.updated") {
                updateSessionInfo(properties?.info)
                rememberSessionId(properties?.info?.id)
                const infoStatus = properties?.info?.status?.type || properties?.info?.status
                if (type === "session.updated" && infoStatus) {
                  const status = (infoStatus === "busy" || infoStatus === "retry")
                    ? "processing"
                    : "waiting_for_input"
                  await emitStatus({
                    sessionId: properties?.info?.id || sessionIdFrom(properties, payload) || lastSessionId,
                    cwd: properties?.info?.directory || getCwd(lastSessionId),
                    status,
                    event: type,
                  })
                }
                if (type === "session.created") {
                  const info = properties?.info
                  await emitStatus({
                    sessionId: info?.id,
                    cwd: info?.directory,
                    status: "waiting_for_input",
                    event: type
                  })
                }
                return
              }

              if (type === "session.status") {
                const sessionId = sessionIdFrom(properties, payload)
                rememberSessionId(sessionId)
                const statusType = properties?.status?.type || properties?.status
                let status = null
                if (statusType === "busy" || statusType === "retry") status = "processing"
                if (statusType === "idle") status = "waiting_for_input"
                if (!status && statusType) status = "waiting_for_input"
                await emitStatus({
                  sessionId,
                  cwd: getCwd(sessionId),
                  status,
                  event: type
                })
                return
              }

              if (type === "session.idle") {
                const sessionId = sessionIdFrom(properties, payload) || lastSessionId
                await emitStatus({
                  sessionId,
                  cwd: getCwd(sessionId),
                  status: "waiting_for_input",
                  event: type
                })
                return
              }

              if (type === "session.error") {
                const sessionId = sessionIdFrom(properties, payload) || lastSessionId
                await emitStatus({
                  sessionId,
                  cwd: getCwd(sessionId),
                  status: "waiting_for_approval",
                  event: type
                })
                return
              }

              if (type === "permission.updated" || type === "permission.asked") {
                const sessionId = sessionIdFrom(properties, payload)
                rememberSessionId(sessionId)
                await emitStatus({
                  sessionId,
                  cwd: getCwd(sessionId),
                  status: "waiting_for_approval",
                  event: type
                })
                return
              }

              if (type === "message.updated") {
                const info = properties?.info
                if (info?.role === "assistant") {
                  const completed = info?.time?.completed
                  const status = completed ? "waiting_for_input" : "processing"
                  const sessionId = info?.sessionID || info?.sessionId || sessionIdFrom(properties, payload)
                  rememberSessionId(sessionId)
                  await emitStatus({
                    sessionId,
                    cwd: getCwd(sessionId, info?.path?.cwd),
                    status,
                    event: type,
                  })
                }
              }
            }
          }
        }
        """
    }
}
