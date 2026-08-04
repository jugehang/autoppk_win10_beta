import Foundation
import Darwin
import Metal

/// Snapshot of system memory usage.
struct SystemMemorySnapshot {
    var totalBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var inactiveBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var appFootprintBytes: UInt64 = 0

    /// Memory that is actually in use (total − free − inactive).
    var usedBytes: UInt64 {
        totalBytes > freeBytes + inactiveBytes ? totalBytes - freeBytes - inactiveBytes : 0
    }
    /// 0...1 ratio of used memory.
    var usageRatio: Double {
        totalBytes > 0 ? min(1.0, Double(usedBytes) / Double(totalBytes)) : 0
    }
    /// Available bytes = free + inactive (what the OS can reclaim).
    var availableBytes: UInt64 {
        totalBytes > usedBytes ? totalBytes - usedBytes : 0
    }
}

/// Monitors system memory and the local LLM service process (ollama / oMLX / llama-server).
@MainActor
final class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()

    @Published var snapshot = SystemMemorySnapshot()
    @Published var llmProcessName = ""
    @Published var llmProcessBytes: UInt64 = 0
    @Published var cpuUsageRatio: Double = 0   // 0...1
    @Published var gpuDeviceName: String = ""
    @Published var gpuVramBytes: UInt64 = 0
    @Published var gpuUsageRatio: Double = 0

    private var timer: Timer?
    private var prevCPUTicks: host_cpu_load_info? = nil
    private var lastRefreshAt = Date.distantPast

    private init() {}

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard Date().timeIntervalSince(lastRefreshAt) >= 1.0 else { return }
        lastRefreshAt = Date()
        snapshot = Self.systemMemory()
        (llmProcessName, llmProcessBytes) = Self.localLLMProcessMemory()
        cpuUsageRatio = Self.cpuUsage(prev: &prevCPUTicks)
        if gpuDeviceName.isEmpty {
            (gpuDeviceName, gpuVramBytes) = Self.gpuInfo()
        }
        gpuUsageRatio = Self.gpuUsage()
    }

    // MARK: - System memory via host_statistics64

    private static func systemMemory() -> SystemMemorySnapshot {
        var snap = SystemMemorySnapshot()

        var memSize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &memSize, &size, nil, 0) == 0 {
            snap.totalBytes = memSize
        }

        let host = mach_host_self()
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStat) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(host, HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return snap }

        let pageSize = UInt64(vm_kernel_page_size)
        snap.freeBytes = UInt64(vmStat.free_count) * pageSize
        snap.inactiveBytes = UInt64(vmStat.inactive_count) * pageSize
        snap.wiredBytes = UInt64(vmStat.wire_count) * pageSize
        snap.compressedBytes = UInt64(vmStat.compressor_page_count) * pageSize
        // App's own resident footprint via task_vm_info (phys_footprint).
        var taskInfo = task_vm_info_data_t()
        var taskCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let taskResult = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(taskCount)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &taskCount)
            }
        }
        if taskResult == KERN_SUCCESS {
            snap.appFootprintBytes = taskInfo.phys_footprint
        }
        return snap
    }

    // MARK: - Local LLM service process memory

    /// Find the running local LLM server process (ollama / oMLX / llama-server / mlx)
    /// and return (name, resident memory bytes).
    private static func localLLMProcessMemory() -> (name: String, bytes: UInt64) {
        let needles = ["ollama", "omlx", "mlx_server", "llama-server", "llama_server", "llamacpp", "lmstudio", "LM Studio"]
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "comm=,rss="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return ("", 0) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return ("", 0) }

        var bestName = ""
        var bestBytes: UInt64 = 0
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ")
            guard parts.count >= 2, let rss = UInt64(parts.last ?? "") else { continue }
            let comm = parts.dropLast().joined(separator: " ")
            let lower = comm.lowercased()
            guard needles.contains(where: { lower.contains($0.lowercased()) }) else { continue }
            if rss > bestBytes {
                bestBytes = rss * 1024  // ps rss is in KB
                bestName = (comm as NSString).lastPathComponent
            }
        }
        return (bestName, bestBytes)
    }

    // MARK: - CPU usage via host_processor_info

    /// 0...1 ratio of overall CPU usage (user + system + nice), excluding idle.
    private static func cpuUsage(prev: inout host_cpu_load_info?) -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let nice = Double(cpuInfo.cpu_ticks.2)
        let idle = Double(cpuInfo.cpu_ticks.3)
        let total = user + system + nice + idle
        guard let p = prev, total > 0 else { prev = cpuInfo; return 0 }
        let prevTotal = Double(p.cpu_ticks.0 + p.cpu_ticks.1 + p.cpu_ticks.2 + p.cpu_ticks.3)
        let prevIdle = Double(p.cpu_ticks.3)
        let deltaTotal = total - prevTotal
        let deltaIdle = idle - prevIdle
        let used = max(0, deltaTotal - deltaIdle)
        prev = cpuInfo
        guard deltaTotal > 0 else { return 0 }
        return min(1.0, used / deltaTotal)
    }

    // MARK: - GPU info via Metal

    private static func gpuInfo() -> (name: String, vramBytes: UInt64) {
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            let name = device.name
            let vram = device.recommendedMaxWorkingSetSize
            return (name, UInt64(vram))
        }
        #endif
        return ("", 0)
    }

    /// Approximate GPU usage via per-process metal stats from `ps`.
    /// macOS does not expose aggregate GPU usage without sudo, so this returns 0.
    private static func gpuUsage() -> Double { 0 }

    // MARK: - Formatting helpers

    func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}
