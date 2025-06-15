#!/bin/bash

# Log file for appending a historical record of new processes.
# This file will be created in the directory where you run the script.
LOG_FILE="process.log"

# State file to compare against the last run (will be overwritten each time).
STATE_FILE="/tmp/process_snapshot.txt"

# --- Function to get all current processes ---
# Outputs a clean, sortable list format (PID:ProcName).
get_current_processes() {
    for pid_dir in /proc/[0-9]*; do
        PID=$(basename "$pid_dir")
        
        # Check if the exe file exists, is a symbolic link, and is readable
        if [ -L "$pid_dir/exe" ] && [ -r "$pid_dir/exe" ]; then
            # Read the symbolic link to get the full path of the executable
            exe_path=$(readlink -f "$pid_dir/exe")
            
            # If readlink successfully returned a path
            if [ -n "$exe_path" ]; then
                PROC_NAME=$(basename "$exe_path")
                # Output in a format suitable for comparison (PID:ProcessName)
                echo "$PID:$PROC_NAME"
            fi
        fi
    done
}

# --- Main Script Logic ---

# Get the current timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
#echo "--- Running check at: $TIMESTAMP ---"

# Get the current list of processes and store sorted in a temporary file
CURRENT_PROCESSES_FILE=$(mktemp)
get_current_processes | sort > "$CURRENT_PROCESSES_FILE"

# Check if a previous state file exists to compare against
if [ -f "$STATE_FILE" ]; then
    # SUBSEQUENT RUN: Compare current processes with the previous list
    
    # Compare the old and new lists to find new processes
    # 'comm -13' shows lines that are unique to the second file
    NEW_PROCESSES=$(comm -13 "$STATE_FILE" "$CURRENT_PROCESSES_FILE")
    
    if [ -n "$NEW_PROCESSES" ]; then
#        echo "New processes detected. Appending to $LOG_FILE."
        
        # Append the timestamp and the new processes to the historical log file
        {
            echo "$TIMESTAMP"
            printf "%-9s %-30s\n" "PID" "PROCESS NAME"
            printf "%-9s %-30s\n" "---" "------------"
            echo "$NEW_PROCESSES" | while IFS=: read -r pid name; do
                printf "%-9s %-30s\n" "$pid" "$name"
            done
            echo "" # Add a blank line for readability
        } >> "$LOG_FILE"
        
#    else
#        echo "No new processes detected since the last run."
    fi
    
else
    # FIRST RUN: Create the initial process snapshot and log
#    echo "First run. Creating initial process snapshot and log at $LOG_FILE."
    
    # Append the timestamp and the complete initial list to the historical log file
    {
        echo "$TIMESTAMP"
        printf "%-9s %-30s\n" "PID" "PROCESS NAME"
        printf "%-9s %-30s\n" "---" "------------"
        # Read from the current process list and format for the log
        while IFS=: read -r pid name; do
            printf "%-9s %-30s\n" "$pid" "$name"
        done < "$CURRENT_PROCESSES_FILE"
        echo "" # Add a blank line for readability
    } >> "$LOG_FILE"
    
#    echo "Initial log created."
fi

# ALWAYS update the state file with the current list for the next run
mv "$CURRENT_PROCESSES_FILE" "$STATE_FILE"

#echo "State file at $STATE_FILE has been updated for the next run."
#echo "--- Script finished ---"
