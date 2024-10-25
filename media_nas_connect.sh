#!/bin/bash

# Log file locations
LOG_FILE="/tmp/remount_network_drive.log"
ERROR_LOG_FILE="/tmp/remount_network_drive_error.log"

# Set log retention period in days (you can change this value as needed)
LOG_RETENTION_DAYS=1

# Function to back up logs and clean old backups
backup_and_clean_logs() {
    local log_file=$1
    local backup_file="${log_file}.$(date +%Y%m%d).backup"

    # Back up the log file (only if it exists)
    if [ -f "$log_file" ]; then
        mv "$log_file" "$backup_file"
        echo "$(date): Log file backed up to $backup_file" > "$log_file"
    fi

    # Remove log backups older than the specified retention period
    find "$(dirname "$log_file")" -name "$(basename "$log_file").*.backup" -mtime +$LOG_RETENTION_DAYS -exec rm {} \;
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

# Log the current timestamp and operation start
echo "$(date): Attempting to remount network drive" >> "$LOG_FILE"
echo "$(date): Checking if $MOUNT_POINT exists" >> "$LOG_FILE"

# Check if the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "$(date): Mount point $MOUNT_POINT does not exist, creating it..." >> "$LOG_FILE"
    mkdir "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
        echo "$(date): Successfully created $MOUNT_POINT" >> "$LOG_FILE"
    else
        echo "$(date): Failed to create $MOUNT_POINT. Exiting..." >> "$ERROR_LOG_FILE"
        exit 1
    fi
fi

echo "$(date): Checking if $MOUNT_POINT is mounted" >> "$LOG_FILE"

# Function to check if the network drive is already mounted
is_mounted() {
    mount | grep -q "$MOUNT_POINT"
}

# Check if the network drive is mounted
if ! is_mounted; then
    # Mount the SMB share using mount_smbfs and log the outcome
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
