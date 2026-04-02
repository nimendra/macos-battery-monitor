#!/bin/bash

echo "=========================================="
echo "   macOS Battery Saver & Cleanup Script   "
echo "=========================================="
echo ""
echo "This script will:"
echo "1. Log out all other users."
echo "2. List processes currently draining the battery."
echo "3. Allow you to quit apps or disable daemons."
echo ""
echo "Note: 4-hour historical battery data per app is restricted by macOS sandboxing and SIP."
echo "We will use current active high-CPU/Power processes instead as a proxy for battery drain."
echo ""

# Request sudo up front
echo "[*] Requesting sudo privileges..."
sudo -v

# 1. Logout other users
echo ""
echo "[*] Identifying users..."
CURRENT_USER=$(stat -f "%Su" /dev/console)
echo "Current active console user: $CURRENT_USER"

ALL_USERS=$(users | tr ' ' '\n' | sort -u)

for u in $ALL_USERS; do
    if [ "$u" != "$CURRENT_USER" ] && [ "$u" != "root" ] && [ "$u" != "daemon" ]; then
        echo "Logging out user session for: $u"
        # Kill their loginwindow and background processes
        sudo pkill -u "$u"
    fi
done
echo "[+] Other users processed."
echo ""

# 2. List draining apps
echo "[*] Finding power-draining processes..."
echo "These are the highest CPU/Power consuming processes right now:"
echo ""
printf "%-10s %-10s %-40s\n" "PID" "%CPU" "COMMAND"
printf "%-10s %-10s %-40s\n" "---" "----" "-------"

# Get top 20 processes
# We use ps -eo pid,pcpu,comm to avoid top's complex formatting
ps -eo pid,pcpu,comm | sort -k 2 -n -r | head -n 20 > /tmp/draining_apps.txt

while read -r pid cpu comm; do
    # Extract just the executable name if it's a long path
    short_comm=$(basename "$comm")
    if [ "$pid" = "PID" ]; then continue; fi
    if [ "$cpu" = "0.0" ]; then continue; fi
    printf "%-10s %-10s %-40s\n" "$pid" "$cpu" "$short_comm"
done < /tmp/draining_apps.txt
echo ""

# 3. Handle apps/daemons
echo "--------------------------------------------------------"
echo "Options:"
echo " - Enter a PID to Quit/Kill a specific process."
echo " - Enter 'd <PID>' to target a LaunchDaemon/Agent (disables it if found)."
echo " - Enter 'q' to finish and exit."
echo "--------------------------------------------------------"

while true; do
    read -p "> " user_input
    
    if [[ "$user_input" == "q" ]]; then
        break
    elif [[ "$user_input" =~ ^d\ [0-9]+$ ]]; then
        target_pid=$(echo "$user_input" | awk '{print $2}')
        
        # Find the launchd label if possible
        service_label=$(sudo launchctl list | awk -v pid="$target_pid" '$1 == pid {print $3}')
        
        if [ -n "$service_label" ]; then
            echo "Found launchd service: $service_label"
            echo "Attempting to disable and stop $service_label..."
            
            # Try to boot it out from the system domain
            sudo launchctl bootout system/"$service_label" 2>/dev/null
            if [ $? -ne 0 ]; then
                # If that failed, try to boot it out from the current user's GUI domain
                sudo launchctl bootout gui/$(id -u)/"$service_label" 2>/dev/null
            fi
            
            echo "Done. Note: If it respawns, it might be protected by macOS SIP."
        else
            echo "Could not find an active launchd service for PID $target_pid."
            echo "It might be a regular application, or it has already exited."
        fi
    elif [[ "$user_input" =~ ^[0-9]+$ ]]; then
        # Kill process
        echo "Sending SIGTERM to PID $user_input..."
        sudo kill -15 "$user_input" 2>/dev/null
        sleep 1
        if ps -p "$user_input" > /dev/null; then
            echo "Process did not quit gracefully. Sending SIGKILL (-9)..."
            sudo kill -9 "$user_input" 2>/dev/null
        fi
        echo "Done."
    elif [[ -z "$user_input" ]]; then
        continue
    else
        echo "Invalid input. Please enter a PID, 'd <PID>', or 'q'."
    fi
done

echo ""
echo "[+] Cleanup finished!"
