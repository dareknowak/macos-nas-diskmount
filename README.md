# macos-nas-diskmount

Mount an SMB share on macOS with a user LaunchAgent. This repository keeps two implementations side by side:

## Problem and solution

After a Mac mini sleeps or restarts, mounted NAS shares may disconnect. Reconnecting them manually can lead to “Disk Not Ejected Properly” notifications and can interrupt network backed apps such as Foobar2000 when they need files from the NAS. The LaunchAgent periodically checks the mount and reconnects the share when needed, including after login or restart.

- [`versions/bash/`](versions/bash/) — Bash version (`media_nas_connect.sh`)
- [`versions/python/`](versions/python/) — Python 3 version (`media_nas_connect.py`)

Choose one implementation and use the script and matching plist from that same folder. The templates contain placeholders only; keep your real NAS settings in your local installed copy, not in Git.

## Requirements

- macOS with `mount_smbfs` and the `security` command
- An SMB NAS share and a macOS user account that can access it
- For the Python version, Python 3 installed. Use the full path to that Python interpreter in the plist; launchd does not load your interactive shell's `PATH`.

## Configure Keychain and mount point

Store the NAS password in macOS Keychain. The account and service values must match the username and server address configured in the script:

```bash
security add-generic-password -a "YOUR_NAS_USERNAME" -s "YOUR_NAS_SERVER_NAME" -w
mkdir -p ~/NAS_media_mountpoint
```

The password is prompted for and retrieved by the script when it runs. It is not stored in either script or plist.

## Configure and install one version

Copy the chosen version's script to a stable location, then edit the copied script and replace its placeholder NAS settings. The Bash settings are in `versions/bash/media_nas_connect.sh`; the Python settings are near the top of `versions/python/media_nas_connect.py`.

For example, to install the Bash version:

```bash
mkdir -p ~/Tools
cp versions/bash/media_nas_connect.sh ~/Tools/media_nas_connect.sh
chmod 700 ~/Tools/media_nas_connect.sh
```

For Python, use a corresponding filename such as `~/Tools/media_nas_connect.py`:

```bash
mkdir -p ~/Tools
cp versions/python/media_nas_connect.py ~/Tools/media_nas_connect.py
chmod 700 ~/Tools/media_nas_connect.py
```

Edit the matching plist template in the same version folder. Set its script argument to the full path of the installed script. In the Python plist, also set the first `ProgramArguments` entry to the full path of your Python 3 interpreter. Then install the plist:

```bash
mkdir -p ~/Library/LaunchAgents
cp versions/bash/com.user.remountnetworkdrive.plist ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```

Use `versions/python/com.user.remountnetworkdrive.plist` instead for the Python implementation. The plist is a template: update its paths before loading it. Keep only one implementation installed under the `com.user.remountnetworkdrive` label at a time.

Load the user LaunchAgent to start it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```

The agent runs the script immediately when loaded (`RunAtLoad`), checks every five minutes, and also responds to volume mount events. To stop it:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist
```

## Behavior and logs

Both implementations retrieve the password from Keychain, create the mount point if needed, check whether the share is mounted and writable, and mount it when necessary. They rotate the current log files on each run and remove backups older than one day. Logs are stored in `~/Library/Logs/remount_network_drive/`:

```bash
tail -f ~/Library/Logs/remount_network_drive/remount_network_drive.log
tail -f ~/Library/Logs/remount_network_drive/remount_network_drive_error.log
```

The log files are restricted to the current user. `mount_smbfs` receives the password as part of the SMB URL, so it may be briefly visible in process listings while the mount command runs.

## Repository layout

```text
versions/
├── bash/
│   ├── media_nas_connect.sh
│   └── com.user.remountnetworkdrive.plist
└── python/
    ├── media_nas_connect.py
    └── com.user.remountnetworkdrive.plist
```

Tested on macOS Sonoma and Sequoia 15.0.1.
