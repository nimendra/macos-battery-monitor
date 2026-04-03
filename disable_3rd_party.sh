#!/bin/bash

echo "================================================="
echo "   Disabling Third-Party Background Daemons/Agents"
echo "================================================="
echo "Note: Re-enable these by running the equivalent 'load -w' commands."
echo ""

echo "[*] Requesting sudo for global daemons..."
sudo -v

echo ""
echo "[1/3] Disabling Docker Daemons..."
sudo launchctl unload -w /Library/LaunchDaemons/com.docker.socket.plist 2>/dev/null
sudo launchctl unload -w /Library/LaunchDaemons/com.docker.vmnetd.plist 2>/dev/null

echo "[2/3] Disabling Google Keystone/Updater Daemons..."
sudo launchctl unload -w /Library/LaunchDaemons/com.google.GoogleUpdater.wake.system.plist 2>/dev/null
sudo launchctl unload -w /Library/LaunchDaemons/com.google.keystone.daemon.plist 2>/dev/null
launchctl unload -w /Library/LaunchAgents/com.google.keystone.agent.plist 2>/dev/null
launchctl unload -w /Library/LaunchAgents/com.google.keystone.xpcservice.plist 2>/dev/null
launchctl unload -w ~/Library/LaunchAgents/com.google.GoogleUpdater.wake.plist 2>/dev/null
launchctl unload -w ~/Library/LaunchAgents/com.google.keystone.agent.plist 2>/dev/null
launchctl unload -w ~/Library/LaunchAgents/com.google.keystone.xpcservice.plist 2>/dev/null

echo "[3/3] Disabling Amazon CodeWhisperer/Q Agent..."
launchctl unload -w ~/Library/LaunchAgents/com.amazon.codewhisperer.launcher.plist 2>/dev/null

echo ""
echo "Done! The target 3rd-party daemons have been stopped and disabled from booting."
echo "Docker, Google Auto-Update, and Amazon CodeWhisperer background services will not run until re-enabled."
