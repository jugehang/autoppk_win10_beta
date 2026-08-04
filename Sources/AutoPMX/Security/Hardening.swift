import Foundation

// MARK: - Runtime Hardening (anti-debug + integrity check)
// These checks run early in app startup to detect reverse-engineering attempts.

enum AppHardening {

    /// Call at the very beginning of app launch (before UI init).
    /// Warns (but does NOT exit) if a debugger is attached — legitimate debugging is a
    /// supported use case and we don't want to block developers.
    /// NOTE: Code-signature validation is intentionally NOT enforced here. Ad-hoc signed
    /// builds fail `SecStaticCodeCheckValidity` intermittently on relaunch, causing
    /// legitimate users to see exit(55). Real protection requires Apple Developer ID.
    static func guardStartup() {
        if isDebuggerAttached() {
            NSLog("⚠️ AutoPMX: debugger detected — anti-tamper checks are disabled.")
        }
    }

    // MARK: - Anti-Debug

    /// Check if the current process is being traced/debugged.
    /// Uses `sysctl` with `KERN_PROC` to read the `P_TRACED` flag.
    /// Returns `true` if a debugger (e.g., lldb, Xcode debugger) is attached.
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = mib.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctl(ptr.baseAddress, u_int(ptr.count), &info, &size, nil, 0)
        }
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // MARK: - Code Integrity

    // Code-signature validation removed — see comment in guardStartup() above.
    // Ad-hoc signed builds fail `SecStaticCodeCheckValidity` on relaunch, causing
    // exit(55) for legitimate users. Real protection requires Apple Developer ID.
}
