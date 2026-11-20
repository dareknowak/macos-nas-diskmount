#!/usr/bin/env python3
"""Mount the configured SMB share when it is not already mounted."""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

LOG_DIR = Path.home() / "Library/Logs/remount_network_drive"
LOG_FILE = LOG_DIR / "remount_network_drive.log"
ERROR_LOG_FILE = LOG_DIR / "remount_network_drive_error.log"
LOG_RETENTION_DAYS = 1

# Replace these placeholders with your NAS settings.
MOUNT_POINT = Path.home() / "NAS_media_mountpoint"
SERVER_ADDRESS = "YOUR_NAS_SERVER_NAME"
SHARE_NAME = "YOUR_SHARE_NAME"
USERNAME = "YOUR_NAS_USERNAME"


def timestamp() -> str:
    return datetime.now().astimezone().strftime("%a %b %d %H:%M:%S %Z %Y")


def log(message: str, *, error: bool = False) -> None:
    with (ERROR_LOG_FILE if error else LOG_FILE).open("a", encoding="utf-8") as stream:
        stream.write(f"{timestamp()}: {message}\n")


def backup_and_clean_logs(log_file: Path) -> None:
    if log_file.exists():
        backup = log_file.with_name(f"{log_file.name}.{datetime.now():%Y%m%d-%H%M%S}.{os.getpid()}.backup")
        log_file.rename(backup)

    cutoff = datetime.now().timestamp() - LOG_RETENTION_DAYS * 24 * 60 * 60
    for backup in log_file.parent.glob(f"{log_file.name}*.backup"):
        try:
            if backup.stat().st_mtime < cutoff:
                backup.unlink()
        except OSError:
            pass


def is_mounted() -> bool:
    result = subprocess.run(["/sbin/mount"], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return False
    mount_text = f" on {MOUNT_POINT} ("
    return any(mount_text in line for line in result.stdout.splitlines()) and os.access(MOUNT_POINT, os.W_OK)


def main() -> int:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    backup_and_clean_logs(LOG_FILE)
    backup_and_clean_logs(ERROR_LOG_FILE)
    for path in (LOG_FILE, ERROR_LOG_FILE):
        path.touch()
        path.chmod(0o600)

    if not MOUNT_POINT.is_dir():
        log(f"Mount point {MOUNT_POINT} does not exist, creating it...")
        MOUNT_POINT.mkdir(parents=True, exist_ok=True)

    log("Attempting to remount network drive")
    password_result = subprocess.run(
        ["/usr/bin/security", "find-generic-password", "-a", USERNAME, "-s", SERVER_ADDRESS, "-w"],
        capture_output=True,
        text=True,
        check=False,
    )
    if password_result.returncode != 0:
        with ERROR_LOG_FILE.open("a", encoding="utf-8") as stream:
            stream.write(password_result.stderr)
        log(f"Failed to retrieve password for {USERNAME} from Keychain. Exiting...", error=True)
        return 1

    if is_mounted():
        log(f"{MOUNT_POINT} is already mounted.")
        return 0

    encoded_password = quote(password_result.stdout.rstrip("\r\n"), safe="")
    log(f"Mounting SMB share {SERVER_ADDRESS}/{SHARE_NAME} at {MOUNT_POINT}")
    # mount_smbfs receives the password in its URL, where it is briefly visible in ps output.
    result = subprocess.run(
        ["/sbin/mount_smbfs", f"//{USERNAME}:{encoded_password}@{SERVER_ADDRESS}/{SHARE_NAME}", str(MOUNT_POINT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.stdout:
        with LOG_FILE.open("a", encoding="utf-8") as stream:
            stream.write(result.stdout)
    if result.stderr:
        with ERROR_LOG_FILE.open("a", encoding="utf-8") as stream:
            stream.write(result.stderr)
    if result.returncode == 0:
        log(f"Successfully mounted {SERVER_ADDRESS} at {MOUNT_POINT}")
        return 0

    log(f"Failed to mount {SERVER_ADDRESS} at {MOUNT_POINT}. Check {ERROR_LOG_FILE} for details.")
    return result.returncode or 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except OSError as exc:
        # Avoid emitting settings or credentials if an operating-system operation fails.
        try:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            with ERROR_LOG_FILE.open("a", encoding="utf-8") as stream:
                stream.write(f"{timestamp()}: Operating-system error: {exc}\n")
        except OSError:
            pass
        sys.exit(1)
