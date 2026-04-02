# macOS Battery Monitor & Saver

A lightweight, native macOS utility to help you track down and eliminate battery-draining background processes and rogue user sessions. It comes in two flavors: a command-line script (`battery_saver.sh`) and a headless Menu Bar application (`BatterySaverUI.app`).

## Features

- **Logout Other Users:** Instantly kill all background apps and sessions belonging to other user accounts on your Mac without rebooting.
- **Identify Battery Drainers:** Actively scans for the highest CPU/Power consuming processes (since macOS limits per-app 4-hour historical battery data via standard terminal APIs). 
- **1-Click Kill Switch:** Effortlessly send `SIGTERM` or `SIGKILL` to misbehaving apps directly from the menu bar or terminal.
- **Native Authentication:** Uses secure, native macOS privilege escalation (AppleScript `with administrator privileges`). It securely prompts for your Touch ID or Mac password without storing or handling sensitive information in the code.

## Components

### 1. The Menu Bar App (SwiftUI)
A native macOS application that runs completely in the background with a small footprint (`LSUIElement` enabled).
*   **Source:** `BatterySaverApp.swift`
*   **Compilation:** It is compiled into a standalone `.app` bundle natively using the Swift compiler.

**How to build from source:**
```bash
# Create the bundle structure
mkdir -p BatterySaverUI.app/Contents/MacOS BatterySaverUI.app/Contents/Resources

# Compile the swift code natively
swiftc -parse-as-library BatterySaverApp.swift -o BatterySaverUI.app/Contents/MacOS/BatterySaverUI

# Copy Info.plist to hide the dock icon
cp Info.plist BatterySaverUI.app/Contents/Info.plist
```
Simply double-click `BatterySaverUI.app` to launch, and it will appear at the top right of your screen.

### 2. The Command Line Script (Bash)
A simple, interactive terminal script for those who prefer the CLI or want to use SSH.
*   **File:** `battery_saver.sh`

**Usage:**
```bash
chmod +x battery_saver.sh
./battery_saver.sh
```

## Security & Privacy
There is no sensitive information, credentials, or remote tracking present in this repository. All commands rely strictly on built-in Apple APIs (`pkill`, `launchctl`, `NSAppleScript`, `ps`).

## Requirements
*   macOS (Built and tested on standard Apple Silicon & Intel environments).
*   Admin privileges (required only when executing kill/logout actions).
*   Xcode Command Line Tools (only if modifying and recompiling the Swift source).

## License
Feel free to fork, enjoy, and modify!
