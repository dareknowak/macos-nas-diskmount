#!/bin/bash

# Log file locations
LOG_FILE="/tmp/remount_network_drive.log"
ERROR_LOG_FILE="/tmp/remount_network_drive_error.log"

# Set log retention period in days
LOG_RETENTION_DAYS=1

# Function to back up logs and clean old backups
backup_and_clean_logs() {
    local log_file=$1
    local backup_file="${log_file}.$(date +%Y%m%d).backup"

    # Back up the log file (only if it exists)
    if [ -f "$log_file" ]; then
        mv "$log_file" "$backup_file"
        echo "$(date): Log file $log_file backed up to $backup_file" >> "/tmp/log_management.log"
    fi

    # Remove log backups older than the specified retention period
    find "$(dirname "$log_file")" -name "$(basename "$log_file")*.backup" -mtime +$LOG_RETENTION_DAYS -exec rm {} \;
}

# Backup and clean both log files
backup_and_clean_logs "$LOG_FILE"
backup_and_clean_logs "$ERROR_LOG_FILE"

# Replace with your network drive information
MOUNT_POINT="$HOME/NAS_media_mountpoint"
SERVER_ADDRESS="NAS617DB0"
SHARE_NAME="Media"
USERNAME="username"

# Retrieve the password from the Keychain
PASSWORD=$(security find-generic-password -a "$USERNAME" -s "$SERVER_ADDRESS" -w)

if [ -z "$PASSWORD" ]; then
    echo "$(date): Failed to retrieve password for $USERNAME from Keychain. Exiting..." >> "$ERROR_LOG_FILE"
    exit 1
fi

# Log the current timestamp and operation start
echo "$(date): Attempting to remount network drive" >> "$LOG_FILE"

# Check if the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "$(date): Mount point $MOUNT_POINT does not exist, creating it..." >> "$LOG_FILE"
    mkdir "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
        echo "$(date): Failed to create $MOUNT_POINT. Exiting..." >> "$ERROR_LOG_FILE"
        exit 1
    fi
fi

# Function to check if the network drive is already mounted
is_mounted() {
    mount | grep -q "$MOUNT_POINT" && [ -w "$MOUNT_POINT" ]
}

# Check if the network drive is mounted
if ! is_mounted; then
    # URL-encode the password
    url_encode() {
        echo "$1" | python3 -c 'import sys, urllib.parse as ul; print(ul.quote(sys.stdin.read().strip()))'
    }
    PASSWORD=$(url_encode "$PASSWORD")

    echo "$(date): Mounting SMB share $SERVER_ADDRESS at $MOUNT_POINT" >> "$LOG_FILE"
    mount_smbfs "//$USERNAME:$PASSWORD@$SERVER_ADDRESS/$SHARE_NAME" "$MOUNT_POINT" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"

    if [ $? -eq 0 ]; then
        echo "$(date): Successfully mounted $SERVER_ADDRESS at $MOUNT_POINT" >> "$LOG_FILE"
    else
        echo "$(date): Failed to mount $SERVER_ADDRESS at $MOUNT_POINT. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE"
    fi
else
    echo "$(date): $MOUNT_POINT is already mounted." >> "$LOG_FILE"
fi
