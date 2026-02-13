import Foundation
import Darwin

nonisolated struct ProcessMonitor: ProcessMonitorProtocol {
    func runningClaudePIDs() -> Set<Int32> {
        var pids = Set<Int32>()

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0 else { return pids }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procList = [kinfo_proc](repeating: kinfo_proc(), count: count)

        guard sysctl(&mib, UInt32(mib.count), &procList, &size, nil, 0) == 0 else { return pids }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride

        for i in 0..<actualCount {
            let proc = procList[i]
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cStr in
                    String(cString: cStr)
                }
            }
            if name == "claude" {
                pids.insert(proc.kp_proc.p_pid)
            }
        }

        return pids
    }

    func isProcessRunning(pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    func parentPID(of pid: Int32) -> Int32? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride

        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 0 ? ppid : nil
    }

    func processCwd(of pid: Int32) -> String? {
        var vpi = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, Int32(size))
        guard result == size else { return nil }

        return withUnsafePointer(to: &vpi.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { cStr in
                String(cString: cStr)
            }
        }
    }

    func guiAncestor(of pid: Int32) -> Int32? {
        var currentPID = pid
        // Walk up to 15 levels to find a GUI app (terminal/IDE)
        for _ in 0..<15 {
            guard let parent = parentPID(of: currentPID), parent != currentPID, parent > 1 else {
                return nil
            }
            currentPID = parent

            // Check if this process is a GUI app by looking at its bundle
            let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXPATHLEN))
            defer { pathBuffer.deallocate() }
            let pathLen = proc_pidpath(currentPID, pathBuffer, UInt32(MAXPATHLEN))
            if pathLen > 0 {
                let path = String(cString: pathBuffer)
                // GUI apps live inside .app bundles
                if path.contains(".app/") {
                    return currentPID
                }
            }
        }
        return nil
    }
}
