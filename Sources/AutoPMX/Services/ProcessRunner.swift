import Foundation

@MainActor
final class ProcessRunner: ObservableObject {
    @Published var logText: String = "AutoPMX terminal ready.\n"
    @Published var isRunning = false
    private var currentTask: Process?

    func clear() {
        logText = ""
    }

    func append(_ line: String) {
        logText += line + "\n"
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
        env["PATH"] = [
            "/opt/nm760/run",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
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

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.logText += text
            }
        }

        task.terminationHandler = { [weak self] process in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self?.append("[exit \(process.terminationStatus)]")
                self?.isRunning = false
                self?.currentTask = nil
            }
        }

        do {
            try task.run()
        } catch {
            append("Failed to start command: \(error.localizedDescription)")
            isRunning = false
            currentTask = nil
        }
    }

    func stopCurrentProcess() {
        guard let task = currentTask, task.isRunning else {
            append("No external process is currently running.")
            return
        }
        append("Stop requested. Terminating current external process...")
        task.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak task] in
            guard let self, let task, task.isRunning else { return }
            self.append("Process did not exit after terminate; interrupting it.")
            task.interrupt()
        }
    }

    func runAndWait(command: String, in directory: URL) async -> Int32 {
        if isRunning {
            append("A task is already running.")
            return 2
        }

        isRunning = true
        append("$ \(command)")

        return await withCheckedContinuation { continuation in
            let task = configuredTask(command: command, directory: directory)
            currentTask = task
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.logText += text
                }
            }

            task.terminationHandler = { [weak self] process in
                pipe.fileHandleForReading.readabilityHandler = nil
                Task { @MainActor in
                    self?.append("[exit \(process.terminationStatus)]")
                    self?.isRunning = false
                    self?.currentTask = nil
                    continuation.resume(returning: process.terminationStatus)
                }
            }

            do {
                try task.run()
            } catch {
                append("Failed to start command: \(error.localizedDescription)")
                isRunning = false
                currentTask = nil
                continuation.resume(returning: 127)
            }
        }
    }

    private func configuredTask(command: String, directory: URL) -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", command]
        task.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = [
            "/opt/nm760/run",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
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
