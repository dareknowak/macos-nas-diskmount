#!/bin/bash

# Log file locations
LOG_FILE="/tmp/remount_network_drive.log"
ERROR_LOG_FILE="/tmp/remount_network_drive_error.log"

# Set log retention period in days
LOG_RETENTION_DAYS=1

# Configuration
MOUNT_POINT="$HOME/NAS_media_mountpoint"
SERVER_ADDRESS="NAS617DB0"
SHARE_NAME="Media"
USERNAME="username"
MOUNT_TIMEOUT=30  # Timeout in seconds

# Function to check network connectivity to the server
check_network() {
    ping -c 1 -W 3 "$SERVER_ADDRESS" >/dev/null 2>&1
    return $?
}

# Function to back up logs and clean old backups
backup_and_clean_logs() {
    local log_file=$1
    local backup_file="${log_file}.$(date +%Y%m%d).backup"

    if [ -f "$log_file" ]; then
        mv "$log_file" "$backup_file"
        echo "$(date): Log file $log_file backed up to $backup_file" >> "/tmp/log_management.log"
    fi

    find "$(dirname "$log_file")" -name "$(basename "$log_file")*.backup" -mtime +$LOG_RETENTION_DAYS -exec rm {} \;
}

# Function to check if the network drive is already mounted
is_mounted() {
    mount | grep -q "$MOUNT_POINT" && [ -w "$MOUNT_POINT" ]
}

# Function to mount with timeout
mount_with_timeout() {
    local timeout=$1
    local cmd=$2
    
    # Start the mount command in background
    eval "$cmd" &
    local pid=$!
    
    # Wait for specified timeout
    local count=0
    while [ $count -lt $timeout ]; do
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid
            return $?
        fi
        sleep 1
        ((count++))
    done
    
    # If we're here, the command is still running
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    echo "Mount operation timed out after $timeout seconds"
    return 1
}

# Backup and clean both log files
backup_and_clean_logs "$LOG_FILE"
backup_and_clean_logs "$ERROR_LOG_FILE"

# Check if already mounted
if is_mounted; then
    echo "$(date): $MOUNT_POINT is already mounted." >> "$LOG_FILE"
    exit 0
fi

# Check network connectivity first
if ! check_network; then
    echo "$(date): Cannot reach $SERVER_ADDRESS. Network may be down." >> "$ERROR_LOG_FILE"
    exit 1
fi

# Retrieve the password from the Keychain
PASSWORD=$(security find-generic-password -a "$USERNAME" -s "$SERVER_ADDRESS" -w)

if [ -z "$PASSWORD" ]; then
    echo "$(date): Failed to retrieve password for $USERNAME from Keychain. Exiting..." >> "$ERROR_LOG_FILE"
    exit 1
fi

# Check if the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "$(date): Mount point $MOUNT_POINT does not exist, creating it..." >> "$LOG_FILE"
    mkdir -p "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
        echo "$(date): Failed to create $MOUNT_POINT. Exiting..." >> "$ERROR_LOG_FILE"
        exit 1
    fi
fi

# URL-encode the password
url_encode() {
    echo "$1" | python3 -c 'import sys, urllib.parse as ul; print(ul.quote(sys.stdin.read().strip()))'
}
PASSWORD=$(url_encode "$PASSWORD")

echo "$(date): Attempting to mount SMB share $SERVER_ADDRESS at $MOUNT_POINT" >> "$LOG_FILE"

# Mount command with timeout
MOUNT_CMD="mount_smbfs '//$USERNAME:$PASSWORD@$SERVER_ADDRESS/$SHARE_NAME' '$MOUNT_POINT' >> '$LOG_FILE' 2>> '$ERROR_LOG_FILE'"
if mount_with_timeout $MOUNT_TIMEOUT "$MOUNT_CMD"; then
    echo "$(date): Successfully mounted $SERVER_ADDRESS at $MOUNT_POINT" >> "$LOG_FILE"
else
    echo "$(date): Failed to mount $SERVER_ADDRESS at $MOUNT_POINT. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE"
    exit 1
fi