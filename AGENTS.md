# Repository workflow notes

## Templates and installed runtime files

The files in this repository are the shareable GitHub templates. They use placeholder NAS settings and must not contain the user's real server, share, username, or other private configuration.

The user's configured runtime copies are separate:

- `~/Tools/media_nas_connect.sh` contains the real NAS settings.
- `~/Library/LaunchAgents/com.user.remountnetworkdrive.plist` is the installed LaunchAgent plist and points to the script in `~/Tools` using an absolute path.

The NAS password is retrieved from macOS Keychain at runtime; do not put it in either script or in Git.

## Updating both copies

When the user asks to apply a repository change to the live installation:

1. Update and review the template files in this repository as usual.
2. Apply script logic changes to `~/Tools/media_nas_connect.sh` while preserving its configured values and any runtime-specific settings. Never replace the whole live script with the template.
3. Apply plist behavior changes to the installed plist while preserving its `ProgramArguments` path to `~/Tools/media_nas_connect.sh` and any other installation-specific settings. Never replace the installed plist wholesale with the template.
4. Keep real NAS settings out of terminal output, diffs, notes, commits, and GitHub.

The intended workflow is to push template changes through a GitHub branch and pull request, then separately synchronize the relevant logic and plist behavior into the live files when requested.

## Reloading the LaunchAgent

After changing the live shell script or installed plist, including after publishing corresponding template changes, always ask the user whether they want the LaunchAgent restarted/reloaded to apply the changes. Do not reload it until the user explicitly confirms. Explain that loading this agent runs the script immediately because the plist has `RunAtLoad` enabled.
