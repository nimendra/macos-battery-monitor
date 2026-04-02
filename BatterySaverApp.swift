import SwiftUI
import AppKit

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
        let script = "do shell script \"kill -9 \(pid)\" with administrator privileges"
        runAppleScript(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refresh()
        }
    }
    
    func logoutOtherUsers() {
        // Need to escape quotes and backslashes properly for AppleScript
        let shellScript = "CURRENT_USER=$(stat -f '%Su' /dev/console); for u in $(users | tr ' ' '\\n' | sort -u); do if [ \"$u\" != \"$CURRENT_USER\" ] && [ \"$u\" != \"root\" ] && [ \"$u\" != \"daemon\" ]; then pkill -u \"$u\"; fi; done"
        // In AppleScript, we wrap the shell command in double quotes, so we must escape double quotes inside the shell command with \". We also must escape \n as \\n.
        // Swift string literal handling:
        let escapedShellScript = shellScript.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let scriptStr = "do shell script \"\(escapedShellScript)\" with administrator privileges"
        
        runAppleScript(scriptStr)
    }
    
    private func runAppleScript(_ source: String) {
        var error: NSDictionary? = nil
        if let scriptObject = NSAppleScript(source: source) {
            scriptObject.executeAndReturnError(&error)
            if let err = error {
                print("AppleScript Error: \(err)")
            }
        }
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
