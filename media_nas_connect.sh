#!/bin/bash
set -euo pipefail

# Log file locations
LOG_DIR="$HOME/Library/Logs/remount_network_drive"
LOG_FILE="$LOG_DIR/remount_network_drive.log"
ERROR_LOG_FILE="$LOG_DIR/remount_network_drive_error.log"

mkdir -p "$LOG_DIR"

# Set log retention period in days
LOG_RETENTION_DAYS=1

# Function to URL-encode a string using pure bash (no Python dependency)
url_encode() {
    local string="$1"
    local encoded=""
    local char
    for (( i=0; i<${#string}; i++ )); do
        char="${string:$i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) encoded+="$char" ;;
            *) printf -v encoded_char '%%%02X' "'$char"
               encoded+="$encoded_char" ;;
        esac
    done
    echo "$encoded"
}

# Function to back up logs and clean old backups
backup_and_clean_logs() {
    local log_file=$1
    local backup_file="${log_file}.$(date +%Y%m%d).backup"

    if [ -f "$log_file" ]; then
        mv "$log_file" "$backup_file"
        echo "$(date): Log file $log_file backed up to $backup_file" >> "/tmp/log_management.log"
    fi

    find "$(dirname "$log_file")" -name "$(basename "$log_file")*.backup" -mtime +$LOG_RETENTION_DAYS -exec rm {} \; || true
}

# Backup and clean both log files
backup_and_clean_logs "$LOG_FILE"
backup_and_clean_logs "$ERROR_LOG_FILE"

# Restrict permissions on log files (log dir already created above)
touch "$LOG_FILE" "$ERROR_LOG_FILE"
chmod 600 "$LOG_FILE" "$ERROR_LOG_FILE"

# Replace with your network drive information
MOUNT_POINT="$HOME/NAS_media_mountpoint"
SERVER_ADDRESS="YOUR_NAS_SERVER_NAME"
SHARE_NAME="YOUR_SHARE_NAME"
USERNAME="YOUR_NAS_USERNAME"

# Retrieve the password from the Keychain
# Use || to catch failure from 'security' before set -e can exit silently
PASSWORD=$(security find-generic-password -a "$USERNAME" -s "$SERVER_ADDRESS" -w 2>>"$ERROR_LOG_FILE") || {
    echo "$(date): Failed to retrieve password for $USERNAME from Keychain. Exiting..." >> "$ERROR_LOG_FILE"
    exit 1
}

echo "$(date): Attempting to remount network drive" >> "$LOG_FILE"

# Check if the mount point exists; create if missing
if [ ! -d "$MOUNT_POINT" ]; then
    echo "$(date): Mount point $MOUNT_POINT does not exist, creating it..." >> "$LOG_FILE"
    mkdir -p "$MOUNT_POINT"
fi

# Function to check if the network drive is already mounted and writable
is_mounted() {
    mount | grep -q "$MOUNT_POINT" && [ -w "$MOUNT_POINT" ]
}

if ! is_mounted; then
    ENCODED_PASSWORD=$(url_encode "$PASSWORD")

    echo "$(date): Mounting SMB share $SERVER_ADDRESS/$SHARE_NAME at $MOUNT_POINT" >> "$LOG_FILE"
    # NOTE: The password is briefly visible in ps output during mount_smbfs execution.
    # This is a known limitation of mount_smbfs and cannot be fully avoided.
    if mount_smbfs "//$USERNAME:$ENCODED_PASSWORD@$SERVER_ADDRESS/$SHARE_NAME" "$MOUNT_POINT" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"; then
        echo "$(date): Successfully mounted $SERVER_ADDRESS at $MOUNT_POINT" >> "$LOG_FILE"
    else
        echo "$(date): Failed to mount $SERVER_ADDRESS at $MOUNT_POINT. Check $ERROR_LOG_FILE for details." >> "$LOG_FILE"
        exit 1
    fi
else
    echo "$(date): $MOUNT_POINT is already mounted." >> "$LOG_FILE"
fi
