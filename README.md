# macos-nas-diskmount
MacOS NAS disk mount via plist

# Problem and solution
Whenever my Mac mini goes to sleep or is rebooted, I have to manually reconnect my NAS drive using Finder. For instance, if I want to listen to FLAC files in Foobar2000 and the drive is disconnected, my music library becomes inaccessible. I must then remember to reconnect the drive manually by navigating to the network and attaching it."

# Prerequisites 

Create the Directory in Your Home Directory:

`mkdir -p ~/Media`

Update Your Script to use this new mount point and nas server name:
`MOUNT_POINT="$HOME/Media"`
`SERVER_ADDRESS="NAS617DB0"`

No Permissions Issues: Since this directory is inside your home folder, your user has full permissions to create and manage it.

`chmod +x /usr/local/bin/remount_network_drive.sh`

Move the .plist to /Library/LaunchAgents/:
`sudo mv com.user.remountnetworkdrive.plist /Library/LaunchDaemons/`

Load the Agent or reboot the OS*:
`launchctl load /Library/LaunchAgents/com.user.remountnetworkdrive.plist`

#### NOTE: the agent definition will also keep it alive and load at run (OS restart), see .plist code<br />
#### NOTE: tested on macOS Sonoma, Sequoia 15.0.1 (24A348)