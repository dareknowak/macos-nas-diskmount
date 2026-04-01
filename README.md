# macos-nas-diskmount
MacOS NAS disk mount via launchd plist

# Problem and solution
* Whenever my Mac mini goes to sleep or is rebooted, I have to manually reconnect/mount my NAS drives using Finder.
* This causes "Disk Not Ejected Properly" notifications and makes network-backed apps (e.g. Foobar2000 playing FLAC files) lose access to their libraries.
* The script and `.plist` in this repo automatically mount the SMB share on login, after sleep, and after reboot — and re-mount it if it drops.

# Prerequisites

## 1. Store your NAS password in macOS Keychain
```bash
security add-generic-password -a "YOUR_NAS_USERNAME" -s "YOUR_NAS_SERVER_NAME" -w
```
Replace `YOUR_NAS_USERNAME` with your NAS username and `YOUR_NAS_SERVER_NAME` with the NAS hostname or IP. You will be prompted to enter the password.

## 2. Create the mount point directory
```bash
mkdir -p ~/NAS_media_mountpoint
```

## 3. Configure the script
Edit `media_nas_connect.sh` and replace the placeholder values:
```bash
MOUNT_POINT="$HOME/NAS_media_mountpoint"
SERVER_ADDRESS="YOUR_NAS_SERVER_NAME"   # must match the -s value used in Keychain above
SHARE_NAME="YOUR_SHARE_NAME"
USERNAME="YOUR_NAS_USERNAME"            # must match the -a value used in Keychain above
```

## 4. Install the script
```bash
cp media_nas_connect.sh /usr/local/bin/media_nas_connect.sh
chmod +x /usr/local/bin/media_nas_connect.sh
```

## 5. Configure and install the plist
Edit `com.user.remountnetworkdrive.plist` and replace `/path/to/media_nas_connect.sh` with the actual path (e.g. `/usr/local/bin/media_nas_connect.sh`).

Then copy it to `~/Library/LaunchAgents/` (no `sudo` needed — this is a user-level agent):
```bash
cp com.user.remountnetworkdrive.plist ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```

## 6. Load the agent
```bash
launchctl load ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```
The agent will also auto-load on reboot. To unload it:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```

# Using the `local/` directory (recommended)
The `local/` directory is gitignored. Copy the files there and fill in your real values — they will never be committed:
```
local/
├── media_nas_connect.sh                  # your real configured script
└── com.user.remountnetworkdrive.plist    # your real configured plist
```

# Security notes
* The password is retrieved from Keychain at runtime — it is never stored in the script.
* Log files are created with `chmod 600` (owner read/write only).
* **Known limitation**: `mount_smbfs` receives the password as part of the SMB URL, which is briefly visible in `ps` output during mounting. This is a limitation of `mount_smbfs` and cannot be avoided without a wrapper utility.

# Logs
Log files are stored in `~/Library/Logs/remount_network_drive/` (persists across reboots):
```bash
tail -f ~/Library/Logs/remount_network_drive/remount_network_drive.log
tail -f ~/Library/Logs/remount_network_drive/remount_network_drive_error.log
# or both at once:
tail -f ~/Library/Logs/remount_network_drive/remount*
```
Logs older than 1 day are automatically rotated (configurable via `LOG_RETENTION_DAYS` in the script).

---
#### NOTE: tested on macOS Sonoma, Sequoia 15.0.1 (24A348)
