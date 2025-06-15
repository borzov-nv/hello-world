#!/bin/bash

STATE_FILE="/tmp/process_snapshot.txt"
get_current_processes() {
for pid_dir in /proc/[0-9]*; do
    PID=$(basename "$pid_dir")
    
    # Check if the exe file exists, is a symbolic link, and its target is readable
    if [ -L "$pid_dir/exe" ]; then
        if [ -e "$pid_dir/exe" ] && [ -r "$pid_dir/exe" ]; then
            # Read the symbolic link to get the full path of the executable
            exe_path=$(readlink -f "$pid_dir/exe")
            
            # If readlink -f successfully returned a path
            if [ -n "$exe_path" ]; then
                # Extract just the process name from the path
                PROC_NAME=$(basename "$exe_path")
            else
                # If exe_path is empty (unresolvable link), skip this PID
                continue
            fi
        else
            # If target doesn't exist or is not readable, skip this PID
            continue
        fi
    else
        # If /proc/N/exe is not a symbolic link, skip this PID
        continue
    fi

    # Only print if a process name was successfully found
    if [ -n "$PROC_NAME" ]; then
        printf "%-9s %-30s\n" "$PID" "$PROC_NAME"
    fi

done
}
# Get the current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "--- Run at: $TIMESTAMP ---"

# Check if a previous state file exists
if [ -f "$STATE_FILE" ]; then
    # SUBSEQUENT RUN: Compare current processes with the previous list
    echo "Checking for new processes..."
    
    # Get the current list of processes and store temporarily
    CURRENT_PROCESSES_FILE=$(mktemp)
    get_current_processes | sort > "$CURRENT_PROCESSES_FILE"
    
    # Compare the old and new lists to find new processes
    # 'comm -13' shows lines that are unique to the second file
    NEW_PROCESSES=$(comm -13 "$STATE_FILE" "$CURRENT_PROCESSES_FILE")
    
    if [ -n "$NEW_PROCESSES" ]; then
        echo "New processes detected:"
        printf "%-9s %-30s\n" "PID" "PROCESS NAME"
        printf "%-9s %-30s\n" "---" "------------"
        
        # Format the output nicely
        echo "$NEW_PROCESSES" | while IFS=: read -r pid name; do
            printf "%-9s %-30s\n" "$pid" "$name"
        done
    else
        echo "No new processes detected since the last run."
    fi
    
    # Update the state file for the next run
    mv "$CURRENT_PROCESSES_FILE" "$STATE_FILE"
    
else
    # FIRST RUN: Create the initial process list
    echo "First run. Creating initial process snapshot..."
    
    # Get all processes, sort them, and save to the state file
    get_current_processes | sort > "$STATE_FILE"
    
    echo "List of all current processes:"
    printf "%-9s %-30s\n" "PID" "PROCESS NAME"
    printf "%-9s %-30s\n" "---" "------------"
    
    # Read from the newly created file and format for display
    while IFS=: read -r pid name; do
        printf "%-9s %-30s\n" "$pid" "$name"
    done < "$STATE_FILE"
    
    echo ""
    echo "Snapshot saved to $STATE_FILE. Run the script again to see new processes."
fi

echo "--- Script finished ---
