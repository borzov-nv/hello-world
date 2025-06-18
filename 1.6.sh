#!/bin/bash
LOG_FILE="process.log"
STATE_FILE="/tmp/process_snapshot.txt"
get_current_processes() {
    for pid_dir in /proc/[0-9]*; do
        PID=$(basename "$pid_dir")
        if [ -L "$pid_dir/exe" ] && [ -r "$pid_dir/exe" ]; then
            exe_path=$(readlink -f "$pid_dir/exe")
            if [ -n "$exe_path" ]; then
                PROC_NAME=$(basename "$exe_path")
                echo "$PID:$PROC_NAME"
            fi
        fi
    done
}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')
CURRENT_PROCESSES_FILE=$(mktemp)
get_current_processes | sort > "$CURRENT_PROCESSES_FILE"
if [ -f "$STATE_FILE" ]; then
    NEW_PROCESSES=$(comm -13 "$STATE_FILE" "$CURRENT_PROCESSES_FILE")
    if [ -n "$NEW_PROCESSES" ]; then        {
            echo "$TIMESTAMP"
            printf "%-9s %-30s\n" "PID" "PROCESS NAME"
            printf "%-9s %-30s\n" "---" "------------"
            echo "$NEW_PROCESSES" | while IFS=: read -r pid name; do
                printf "%-9s %-30s\n" "$pid" "$name"
            done
            echo "" 
        } >> "$LOG_FILE"
    fi
else    {
        echo "$TIMESTAMP"
        printf "%-9s %-30s\n" "PID" "PROCESS NAME"
        printf "%-9s %-30s\n" "---" "------------"
        while IFS=: read -r pid name; do
            printf "%-9s %-30s\n" "$pid" "$name"
        done < "$CURRENT_PROCESSES_FILE"
        echo ""
    } >> "$LOG_FILE"
fi
mv "$CURRENT_PROCESSES_FILE" "$STATE_FILE"
