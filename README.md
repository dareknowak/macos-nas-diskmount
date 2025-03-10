# macos-nas-diskmount
MacOS NAS disk mount via plist

# Problem and solution
* Whenever my Mac mini goes to sleep or is rebooted, I have to manually reconnect, mount my NAS drives back using Finder.
* Have you noticed that famous "Disk Not Ejected properly" notifications on MAC, well I have many times for my network NAS drive
* For instance, if I want to listen to FLAC files in Foobar2000 and the drive becomes disconnected, my music library becomes inaccessible. I must then remember to reconnect the drive manually by navigating to Finder and the network and attaching it back.
* Use the following script and .plist to connect (mount drive) and keep alive connection even after the OS has been rebooted or went to sleep

# Prerequisites
* Store the NAS password in macOS Keychain: You can store the password in the Keychain using the security command. 
* Open the terminal and run the following command to store the password for your NAS server:

`security add-generic-password -a "user" -s "NAS617DB0" -w`

* Replace "user" with your NAS username.
* Replace "NAS617DB0" with a label to identify this password (the server name or an appropriate description).
This command will prompt you to enter the password and store it in your Keychain.

* Create the Directory in Your Home Directory:
`mkdir -p ~/Media`

* Update Your Script to use this new mount point and nas server name:
`MOUNT_POINT="$HOME/Media"`
`SERVER_ADDRESS="NAS617DB0"`

No Permissions Issue: Since this directory is inside your home folder, your user has full permissions to create and manage it.

* Drop the script in convenient directory, and set execute permission e.g.
`chmod +x /usr/local/bin/media_nas_connect.sh`

* Move the .plist to ~/Library/LaunchAgents/:
`sudo mv com.user.remountnetworkdrive.plist ~/Library/LaunchDaemons/`

* Load the Agent or reboot the macOS*:
`launchctl load ~/Library/LaunchAgents/com.user.remountnetworkdrive.plist`

#### NOTE: the agent definition will also keep it alive and load at run (OS restart), see .plist code<br />
#### NOTE: tested on macOS Sonoma, Sequoia 15.0.1 (24A348)

# Logs:

* Your log file is at `/tmp/remount_network_drive.log` and `remount_network_drive`, you can use following to tail logs:

`tail -f /tmp/remount_network_drive.log`
`tail -f /tmp/remount_network_drive_error.log`
or use following to tail both logs
`tail -f /tmp/remount*`