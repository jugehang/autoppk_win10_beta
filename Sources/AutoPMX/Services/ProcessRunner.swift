import Foundation

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ chunk: String) {
        lock.lock()
        defer { lock.unlock() }
        text += chunk
    }

    func drain() -> String {
        lock.lock()
        defer { lock.unlock() }
        let value = text
        text = ""
        return value
    }

    func snapshot() -> String {
        lock.lock()
        defer { lock.unlock() }
        return text
    }
}

private final class FlushTimerBox: @unchecked Sendable {
    private weak var timer: Timer?

    func attach(_ timer: Timer) {
        self.timer = timer
    }

    func invalidate() {
        timer?.invalidate()
    }
}

@MainActor
final class ProcessRunner: ObservableObject {
    private static let maxLogCharacters = 200_000

    @Published var logText: String = "AutoPMX terminal ready.\n"
    @Published var isRunning = false
    /// Wall-clock accumulator for commands that finish while AutoPMx is recording
    /// an automated-modeling benchmark. Set by WorkbenchStore.
    var onExecutionDuration: ((TimeInterval) -> Void)?
    private var currentTask: Process?
    private var currentTaskStartTime: Date?
    /// Root PID of the task currently being run. Only used to walk the process tree on STOP;
    /// set after the task actually starts, and cleared after a stop finishes.
    private var managedRootPID: Int32? = nil

    func clear() {
        logText = ""
    }

    func append(_ line: String) {
        appendLog(line + "\n")
    }

    private func appendLog(_ text: String) {
        logText += text
        if logText.count > Self.maxLogCharacters {
            logText = String(logText.suffix(Self.maxLogCharacters))
        }
    }

    /// If `isRunning` is true but no external process actually exists, the flag is stale
    /// (e.g. after the app was killed mid-run, or a continuation never resumed). Clear it
    /// so the quick actions / STOP buttons don't stay frozen.
    func recoverIfStuck() {
        guard isRunning else { return }
        if let task = currentTask, task.isRunning { return }
        if let root = managedRootPID, !processTreeSnapshot(rootPID: root).isEmpty { return }
        isRunning = false
        currentTask = nil
        managedRootPID = nil
        append("ℹ️ Task state auto-recovered — no actual process is running.")
    }

    func run(command: String, in directory: URL) {
        guard !isRunning else {
            append("A task is already running.")
            return
        }

        isRunning = true
        append("$ \(command)")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", command]
        task.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = ([existingPath] + [
            "/opt/nm760/run",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]).filter { !$0.isEmpty }.joined(separator: ":")
        let sdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
        if FileManager.default.fileExists(atPath: sdk) {
            env["SDKROOT"] = sdk
            env["LIBRARY_PATH"] = "\(sdk)/usr/lib"
            env["CPATH"] = "\(sdk)/usr/include"
        }
        task.environment = env
        currentTask = task

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        // Batch output on a background buffer and flush to the main actor at most
        // every 200ms. This prevents thousands of per-line @MainActor updates from
        // thrashing SwiftUI's TerminalView re-render during high-volume output.
        let outputBuffer = OutputBuffer()
        let flushTimerBox = FlushTimerBox()
        let flushTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let pending = outputBuffer.drain()
                if !pending.isEmpty {
                    self.appendLog(pending)
                }
            }
        }
        flushTimerBox.attach(flushTimer)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            outputBuffer.append(text)
        }

        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            flushTimerBox.invalidate()
            let finalFlush = outputBuffer.snapshot()
            Task { @MainActor in
                if !finalFlush.isEmpty {
                    self?.appendLog(finalFlush)
                }
                self?.append("[exit \(process.terminationStatus)]")
                self?.isRunning = false
                self?.currentTask = nil
            }
        }

        do {
            try task.run()
            managedRootPID = task.processIdentifier
        } catch {
            append("Failed to start command: \(error.localizedDescription)")
            isRunning = false
            currentTask = nil
            managedRootPID = nil
        }
    }

    func stopCurrentProcess() {
        guard let root = managedRootPID else {
            append("No external process is currently running.")
            return
        }
        append("Stop requested. Terminating process tree...")
        let snapshot = processTreeSnapshot(rootPID: root)
        if snapshot.isEmpty && !(currentTask?.isRunning ?? false) {
            append("No external process is currently running.")
            managedRootPID = nil
            return
        }
        // Terminate deepest descendants first, then the shell itself. Never signal our own PID.
        for entry in snapshot.reversed() {
            let pid = entry.pid
            if pid > 1 && pid != getpid() { kill(pid, SIGTERM) }
        }
        if let task = currentTask, task.isRunning { task.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            // Identity check before SIGKILL: only kill PIDs whose start time still matches the
            // snapshot, so a recycled PID (now belonging to an unrelated process) is never hit.
            let currentStarts = self.liveProcessStartTimes()
            for entry in snapshot.reversed() {
                let pid = entry.pid
                guard pid > 1, pid != getpid(), currentStarts[pid] == entry.lstart else { continue }
                if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
            }
            if let task = self.currentTask, task.isRunning {
                self.append("Process did not exit after terminate; interrupting it.")
                task.interrupt()
            }
            self.managedRootPID = nil
        }
    }

    /// Snapshot (pid, lstart) for rootPID and all of its descendants (breadth-first).
    private func processTreeSnapshot(rootPID: Int32) -> [(pid: Int32, lstart: String)] {
        let (children, starts) = processTable()
        var result: [(pid: Int32, lstart: String)] = []
        var seen = Set<Int32>()
        var queue = [rootPID]
        while !queue.isEmpty {
            let pid = queue.removeFirst()
            guard seen.insert(pid).inserted else { continue }
            if let start = starts[pid] { result.append((pid, start)) }
            for child in children[pid] ?? [] where !seen.contains(child) {
                queue.append(child)
            }
        }
        return result
    }

    /// Current pid → start-time map (used to verify PID identity before the delayed SIGKILL).
    private func liveProcessStartTimes() -> [Int32: String] {
        processTable().starts
    }

    /// One `ps` pass: (pid → children, pid → start time). Called only on STOP.
    private func processTable() -> (children: [Int32: [Int32]], starts: [Int32: String]) {
        var children: [Int32: [Int32]] = [:]
        var starts: [Int32: String] = [:]
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,ppid=,lstart="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return (children, starts) }
            for line in text.components(separatedBy: "\n") {
                let parts = line.split(whereSeparator: { $0 == " " }).map(String.init)
                guard parts.count >= 3,
                      let pid = Int32(parts[0]),
                      let ppid = Int32(parts[1]) else { continue }
                children[ppid, default: []].append(pid)
                starts[pid] = parts[2...].joined(separator: " ")
            }
        } catch { }
        return (children, starts)
    }

    func runAndWait(command: String, in directory: URL) async -> Int32 {
        if isRunning {
            append("A task is already running.")
            return 2
        }

        isRunning = true
        currentTaskStartTime = Date()
        append("$ \(command)")

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let task = configuredTask(command: command, directory: directory)
                currentTask = task
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                var resumed = false

                // Batch output on a background buffer, flush to main actor every 200ms.
                let outputBuffer = OutputBuffer()
                let flushTimerBox = FlushTimerBox()
                let flushTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        let pending = outputBuffer.drain()
                        if !pending.isEmpty {
                            self.appendLog(pending)
                        }
                    }
                }
                flushTimerBox.attach(flushTimer)

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                    outputBuffer.append(text)
                }

                task.terminationHandler = { [weak self] process in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    flushTimerBox.invalidate()
                    let finalFlush = outputBuffer.snapshot()
                    Task { @MainActor in
                        guard !resumed else { return }
                        resumed = true
                        if !finalFlush.isEmpty {
                            self?.appendLog(finalFlush)
                        }
                        self?.append("[exit \(process.terminationStatus)]")
                        if let start = self?.currentTaskStartTime {
                            self?.onExecutionDuration?(Date().timeIntervalSince(start))
                        }
                        self?.currentTaskStartTime = nil
                        self?.isRunning = false
                        self?.currentTask = nil
                        continuation.resume(returning: process.terminationStatus)
                    }
                }

                do {
                    try task.run()
                    managedRootPID = task.processIdentifier
                } catch {
                    guard !resumed else { return }
                    resumed = true
                    append("Failed to start command: \(error.localizedDescription)")
                    currentTaskStartTime = nil
                    isRunning = false
                    currentTask = nil
                    managedRootPID = nil
                    continuation.resume(returning: 127)
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.stopCurrentProcess()
            }
        }
    }

    private func configuredTask(command: String, directory: URL) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", command]
        task.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        let existingPath = env["PATH"] ?? ""
        env["PATH"] = ([existingPath] + [
            "/opt/nm760/run",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]).filter { !$0.isEmpty }.joined(separator: ":")
        let sdk = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
        if FileManager.default.fileExists(atPath: sdk) {
            env["SDKROOT"] = sdk
            env["LIBRARY_PATH"] = "\(sdk)/usr/lib"
            env["CPATH"] = "\(sdk)/usr/include"
        }
        task.environment = env
        return task
    }
}
