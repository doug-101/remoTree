---
# remoTree
---

remoTree is basically a remote file manager.  It can be used for typical file
management tasks on both remote and local file systems, as well as file
transfer.  It also provides access to a command line shell on the remote
system.

remoTree is primarily intended to be used from Android systems, but it can
also be run from Linux or Windows operating systems.  Remote systems must be
running a SSH sever, since SSH/SFTP is used for the connection.

Also visit <http://remotree.bellz.org> for more information.

# Features

* Shows graphical tree views for both remote and local file systems.
* Files and directories can be transferred using simple copy and paste
  commands.
* Includes a basic editor for text files.
* Includes a basic command line shell on the remote system.
* Can easily create public/private key pairs (optionally with a passphrase) to
  control access without using system passwords.

# System Requirements

## Android

remoTree should run on Android 4.1 (Jelly Bean) and above.

## Linux

remoTree should run on any 64-bit Linux OS.  There is no support for 32-bit
platforms.

The following dependencies are required to build and run remoTree, but the
install script will automatically install them using your native packaging
system:

* Clang
* CMake
* curl
* git
* GTK development headers
* Ninja build
* pkg-config
* XZ development headers

## Windows

remoTree should run on Windows 10 and above, 64-bit.  There is no support for
32-bit platforms.

## macOS

Due to a lack of Macs for testing, remoTree on macOS is not supported.
Assistance with creating a Mac port would be appreciated.

## iOS

Due to a lack of hardware for development and testing, TreeTag on iOS is not
supported.  Assistance with creating an iOS port would be appreciated.

# Installation

## Android

remoTree can be installed from Google Play,
[here](https://play.google.com/store/apps/details?id=org.bellz.remotree).

Alternatively, an APK file (remotree_x.x.x.apk) is provided that can be
downloaded to an Android device and run.

## Linux

Extract the files from the archive (remotree_x.x.x.tar.gz) into a user-owned
directory.  You need to have at least 2GB of disk space available for the
automated build.  Then change to the `remoTree` directory in a terminal, and
run the following commands:

    $ sudo ./rt_make.sh depends
    $ ./rt_make.sh build
    $ sudo ./rt_make.sh install

The first command automatically installs dependencies using the `apt-get`,
`dnf` or `pacman` native packaging system.  If desired, you can manually
install the dependencies in the [Requirements](requirements.md) section and
skip this line.

The second line (build) downloads Flutter and builds remoTree.

The third line (install) copies the necessary files into directories under
`/opt`.  After this step, the temporary `remoTree` build directory can be
deleted.

## Windows

The simplest approach is to download the "remotree_x.x.x.zip" file and
extract all of its contents to an empty folder.  Then run the "remotree.exe"
file.

To compile remoTree from source, install the remoTree source from
<https://github.com/doug-101/remoTree>.  Also install Flutter based on the
instructions in <https://docs.flutter.dev/get-started/install> for the desired
platform.

# Usage

## Remote Connections

remoTree shows lists of available host servers on the Remote Files and Remote
Terminal tab views.  On the initial use, these lists will be blank.  Use the
"+" button at the upper right to add server information.  The Display Name,
User Name and Address are all required fields.  The Private Key button will be
discussed in the next section.  Once those fields are entered, use the check
button at the upper left to complete the host creation.

A tap or click on a host in the list will attempt to make a connection.  It
will prompt for a password if no authentication keys have been defined.  Once
connected, depending on the active tab, the file view or the terminal view
will be active.

The menu button to the right of each host in the list can be used to edit or
delete the host.

## Key Authentication

When editing host information, the Add Private Key button can be used to set
up key-based authentication.  The first option, Create on server, will use the
ssh-keygen command on the server to create the keys.  It will prompt for a key
passphrase - leave the field empty to skip the passphrase.  It will then
automatically add the public key to the "~/.ssh/authorized_keys" file on the
server and load the private key into remoTree.

The second option, Load from file, will load an existing private key from the
local file system.  It will assume that the public key has or will be copied
to the server manually.

## File Management

Both the Local Files and Remote Files tab views support the following
commands:

* Directories can be clicked or tapped to expand or collapse their contents.
* A long click or tap will toggle the selection of a directory or folder.
* The buttons in the file path at the top of the main view area will set
  higher level directories to become the new root directory.
* When nothing is selected:
    * The refresh button will update the view.
    * The eye button will toggle showing hidden dot files.
    * The sort button will allow the user to choose the sorting method.
    * On the remote view, a logout button will disconnect from the server.
* When files or directories are selected:
    * If one directory is selected, an anchor button will make the selected
      directory the new root directory.
    * If one text file is selected, a pencil icon will edit the file.
    * The copy button will collect selected files and/or directories for file
      transfer.
    * The "i" button can be used to show additional information about selected
      objects.  Links in the information view can be used for renames or file
      permission changes.
    * The trash icon is used to delete selected files and/or directories.
    * The back button at the upper left can be used to cancel a selection.
* When items have been marked for copying/file transfer:
    * If one directory is selected, a paste button will copy or transfer the
      marked items.  
    * The back button at the upper left can be used to cancel the copy
      marking.

## Remote Terminal

If connected to a remote server, the Remote Terminal tab view will show a
basic text-based terminal window.  This emulates a dumb terminal, so it does
not support curses applications or other advanced terminal programs.

## Settings

The "Settings" menu item allows for changing several default options. These
settings are automatically stored so that remoTree will re-start with the
settings last used.

There are settings for the default file sorting method and the visibility of
hidden dot files.  These only affect the conditions at startup - the controls
on the views can be used to override these settings.

The remaining options control appearances.  The view scale ratio can be set to
make the content smaller or larger (useful for high-dpi displays). The window
size and position will be restored from the previous session use if enabled.
The final setting selects between light and dark color schemes.
