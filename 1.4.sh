#!/bin/bash

# Define a function to sanitize output for table display
# Replaces newlines with spaces, handles specific /proc file formats, and truncates long lines
sanitize_output() {
    local input="$1"
    local max_len="${2:-100}" # Default max length to 100 characters
    local file_type="$3"    # New parameter to handle specific file formats

#    local sanitized=""

    case "$file_type" in
        "status")
            # For /proc/N/status, extract 'Name:', 'State:', and 'VmRSS:'
#            local name_line=$(echo "$input" | grep -E "^Name:" | head -n 1)
            local state_line=$(echo "$input" | grep -E "^State:" | head -n 1)
#            local vm_rss_line=$(echo "$input" | grep -E "^VmRSS:" | head -n 1)
            
            sanitized="${state_line}"
            sanitized=$(echo "$sanitized" | sed 's/  */ /g' | xargs echo -n) # Compress spaces and trim
            ;;
        *)
            # Default for other files: replace newlines with spaces, compress spaces, trim
            sanitized=$(echo "$input" | tr '\n' ' ' | sed 's/  */ /g' | xargs echo -n)
            ;;
    esac

    if [ ${#sanitized} -gt $max_len ]; then
        echo "${sanitized:0:$max_len}..."
    else
        echo "$sanitized"
    fi
}

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
