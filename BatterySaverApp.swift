import SwiftUI
import AppKit
import Security

struct ProcessInfo: Identifiable {
    let id = UUID()
    let pid: String
    let cpu: String
    let name: String
}

class ProcessMonitor: ObservableObject {
    @Published var topProcesses: [ProcessInfo] = []
    
    init() {
        refresh()
    }
    
    func refresh() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "ps -eo pid,pcpu,comm -r | sort -k 2 -n -r | head -n 11"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            let lines = output.components(separatedBy: .newlines).dropFirst()
            var procs: [ProcessInfo] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count >= 3 else { continue }
                let pid = String(parts[0])
                let cpu = String(parts[1])
                guard cpu != "0.0" else { continue }
                let comm = String(parts[2])
                let name = URL(fileURLWithPath: comm).lastPathComponent
                procs.append(ProcessInfo(pid: pid, cpu: cpu, name: name))
            }
            DispatchQueue.main.async {
                self.topProcesses = procs
            }
        }
    }
    
    func killProcess(pid: String, name: String) {
        executePrivileged(tool: "/bin/kill", arguments: ["-9", pid]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refresh()
            }
        }
    }

    func logoutOtherUsers() {
        let script = "CURRENT_USER=$(stat -f '%Su' /dev/console); for u in $(users | tr ' ' '\\n' | sort -u); do if [ \"$u\" != \"$CURRENT_USER\" ] && [ \"$u\" != \"root\" ] && [ \"$u\" != \"daemon\" ]; then pkill -u \"$u\"; fi; done"
        executePrivileged(tool: "/bin/bash", arguments: ["-c", script])
    }

    private var cachedAuth: AuthorizationRef?

    private func acquireAuthorization() -> AuthorizationRef? {
        if let existing = cachedAuth { return existing }

        var auth: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &auth) == errAuthorizationSuccess,
              let auth else { return nil }

        // Shows native macOS Touch ID or password dialog for admin rights
        let granted = kAuthorizationRightExecute.withCString { namePtr in
            var item = AuthorizationItem(name: namePtr, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { itemPtr in
                var rights = AuthorizationRights(count: 1, items: itemPtr)
                return AuthorizationCopyRights(
                    auth, &rights, nil,
                    [.interactionAllowed, .extendRights, .preAuthorize],
                    nil
                ) == errAuthorizationSuccess
            }
        }

        if granted {
            cachedAuth = auth
            return auth
        }
        AuthorizationFree(auth, .destroyRights)
        return nil
    }

    private func executePrivileged(tool: String, arguments: [String], completion: (() -> Void)? = nil) {
        guard let auth = acquireAuthorization() else { return }

        // AuthorizationExecuteWithPrivileges is deprecated and unavailable in Swift.
        // Call it via dlsym to bypass the availability check — the symbol is still present at runtime.
        typealias AuthExecFn = @convention(c) (
            AuthorizationRef,
            UnsafePointer<CChar>,
            UInt32,
            UnsafePointer<UnsafeMutablePointer<CChar>?>,
            UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
        ) -> Int32

        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "AuthorizationExecuteWithPrivileges") else { return }
        let execFn = unsafeBitCast(sym, to: AuthExecFn.self)

        let cArgs = arguments.map { strdup($0)! }
        defer { cArgs.forEach { free($0) } }

        var argv: [UnsafeMutablePointer<CChar>?] = cArgs.map { Optional($0) }
        argv.append(nil)

        let status: Int32 = argv.withUnsafeBufferPointer { buf in
            execFn(auth, tool, 0, buf.baseAddress!, nil)
        }

        if status != 0 {
            if let a = cachedAuth { AuthorizationFree(a, .destroyRights) }
            cachedAuth = nil
        }

        completion?()
    }
}

@main
struct BatterySaverApp: App {
    @StateObject private var monitor = ProcessMonitor()

    var body: some Scene {
        MenuBarExtra("BatterySaver", systemImage: "bolt.fill") {
            Button("Logout Other Users") {
                monitor.logoutOtherUsers()
            }

            Divider()
            
            Text("Top Draining Processes")
            
            ForEach(monitor.topProcesses, id: \.pid) { proc in
                Button("\(proc.name)   [\(proc.cpu)%]") {
                    monitor.killProcess(pid: proc.pid, name: proc.name)
                }
            }

            Divider()
            
            Button("Refresh list") {
                monitor.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
