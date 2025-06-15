#!/bin/bash

# --- Configuration ---
PREVIOUS_PIDS_FILE="process_pids_cache.txt"
LOG_FILE="process_discovery.log"

# --- Define a function to sanitize output for table display ---
sanitize_output() {
    local input="$1"
    local max_len="${2:-100}" # Default max length to 100 characters
    local file_type="$3"    # Parameter to handle specific file formats

    local sanitized=""

    case "$file_type" in
        "status")
#            local name_line=$(echo "$input" | grep -E "^Name:" | head -n 1)
            local state_line=$(echo "$input" | grep -E "^State:" | head -n 1)
#            local vm_rss_line=$(echo "$input" | grep -E "^VmRSS:" | head -n 1)
            
            sanitized="${name_line}, ${state_line}, ${vm_rss_line}"
            sanitized=$(echo "$sanitized" | sed 's/  */ /g' | xargs echo -n)
            ;;
        *)
            sanitized=$(echo "$input" | tr '\n' ' ' | sed 's/  */ /g' | xargs echo -n)
            ;;
    esac

    if [ ${#sanitized} -gt $max_len ]; then
        echo "${sanitized:0:$max_len}..."
    else
        echo "$sanitized"
    fi
}

# --- Read PIDs from previous run into an associative array ---
declare -A previous_pids_map
if [ -f "$PREVIOUS_PIDS_FILE" ]; then
    while IFS= read -r pid_from_file; do
        previous_pids_map["$pid_from_file"]=1
    done < "$PREVIOUS_PIDS_FILE"
fi

# --- Initialize arrays for current run ---
declare -A current_pids_map # To store PIDs from this run
declare -a new_processes_list # To store descriptions of newly found processes

# --- Table Header ---
printf "%-6s | %-30s | %-20s | %-20s | %-10s | %-20s\n" \
       "PID" "Name" "Status" "CWD" "Root" "Mounts"
printf "%-6s   %-30s   %-20s   %-20s   %-10s   %-20s\n" \
       "---" "----" "------" "---" "----" "------"

for pid_dir in /proc/[0-9]*; do
    PID=$(basename "$pid_dir")
    PROC_NAME="" # Will be set or process skipped
    STATUS_CONTENT="N/A"
    CWD_PATH="N/A"
    LIMITS_CONTENT="N/A"
    MOUNTS_CONTENT="N/A"

    # 1. Get Process Name from exe symlink. If not valid, skip PID.
    if [ -L "$pid_dir/exe" ]; then
        if [ -e "$pid_dir/exe" ] && [ -r "$pid_dir/exe" ]; then
            exe_path=$(readlink -f "$pid_dir/exe")
            if [ -n "$exe_path" ]; then
                PROC_NAME=$(basename "$exe_path")
            else
                continue # Skip if exe path is empty (unresolvable link)
            fi
        else
            continue # Skip if target doesn't exist or is not readable
        fi
    else
        continue # Skip if /proc/N/exe is not a symlink
    fi

    # Add current PID to map for later cache update
    current_pids_map["$PID"]=1

    # Check if this PID is new compared to the previous run
    if [[ -z "${previous_pids_map[$PID]}" ]]; then
        # This PID was not in the previous list, it's new
        new_processes_list+=("$PID ($PROC_NAME)")
    fi

    # 2. Get Status (extracting Name, State, VmRSS)
    if [ -f "$pid_dir/status" ]; then
        if [ -r "$pid_dir/status" ]; then
            STATUS_FULL=$(< "$pid_dir/status")
            STATUS_CONTENT=$(sanitize_output "$STATUS_FULL" 80 "status")
        else
            STATUS_CONTENT="[No Perms]"
        fi
    fi

    # 3. Get CWD (Current Working Directory)
    if [ -L "$pid_dir/cwd" ]; then
        if [ -e "$pid_dir/cwd" ] && [ -r "$pid_dir/cwd" ]; then
            CWD_PATH=$(readlink -f "$pid_dir/cwd")
            if [ -n "$CWD_PATH" ]; then
                CWD_PATH=$(sanitize_output "$CWD_PATH" 20)
            else
                CWD_PATH="[Broken CWD Link/Target Gone]" # readlink -f can return empty
            fi
        elif [ -e "$pid_dir/cwd" ] && [ ! -r "$pid_dir/cwd" ]; then
            CWD_PATH="[CWD Target No Perms]"
        else
            CWD_PATH="[Broken CWD Link]"
        fi
    fi

    if [ -L "$pid_dir/root" ]; then
        if [ -e "$pid_dir/root" ] && [ -r "$pid_dir/root" ]; then
            ROOT_PATH=$(readlink -f "$pid_dir/root")
            if [ -n "$ROOT_PATH" ]; then
                ROOT_PATH=$(sanitize_output "$ROOT_PATH" 40)
            else
                ROOT_PATH="[Broken CWD Link/Target Gone]" # readlink -f can return empty
            fi
        elif [ -e "$pid_dir/root" ] && [ ! -r "$pid_dir/root" ]; then
            ROOT_PATH="[CWD Target No Perms]"
        else
            ROOT_PATH="[Broken CWD Link]"
        fi
    fi


    # 5. Get Mounts (first few lines)
    if [ -f "$pid_dir/mounts" ]; then
        if [ -r "$pid_dir/mounts" ]; then
            MOUNTS_CONTENT=$(head -n 1 "$pid_dir/mounts" | tr '\n' ' ') # Get first line
            MOUNTS_CONTENT=$(sanitize_output "$MOUNTS_CONTENT" 30)
        else
            MOUNTS_CONTENT="[No Perms]"
        fi
    fi

    # --- Print Row ---
    # Only print if PROC_NAME was successfully obtained from exe link
    if [ -n "$PROC_NAME" ]; then
        printf "%-6s | %-30s | %-20s | %-20s | %-10s | %-20s\n" \
               "$PID" "$PROC_NAME" "$STATUS_CONTENT" "$CWD_PATH" "$ROOT_PATH" "$MOUNTS_CONTENT"
    fi

done

# --- Logging New Processes ---
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

if [ ${#new_processes_list[@]} -gt 0 ]; then
    LOG_MESSAGE="$CURRENT_TIMESTAMP: New processes discovered: ${new_processes_list[*]}"
    echo "$LOG_MESSAGE" | tee -a "$LOG_FILE" # Use tee to print to stdout and log file
else
    LOG_MESSAGE="$CURRENT_TIMESTAMP: No new processes discovered."
    echo "$LOG_MESSAGE" | tee -a "$LOG_FILE" # Use tee to print to stdout and log file
fi

# --- Update previous PIDs cache file for the next run ---
# Clear the file and write current PIDs to it
> "$PREVIOUS_PIDS_FILE"
for pid in "${!current_pids_map[@]}"; do
    echo "$pid" >> "$PREVIOUS_PIDS_FILE"
done
