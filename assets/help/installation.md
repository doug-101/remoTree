---
# Installation
---

## Android

remoTree can be installed from Google Play,
[here](https://play.google.com/store/apps/details?id=org.bellz.remotree).

Alternatively, an APK file (remotree_x.x.x.apk) is provided that can be
downloaded to an Android device and run.

---

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

---

## Windows

The simplest approach is to download the "remotree_x.x.x.zip" file and
extract all of its contents to an empty folder.  Then run the "remotree.exe"
file.

To compile remoTree from source, install the remoTree source from
<https://github.com/doug-101/remoTree>.  Also install Flutter based on the
instructions in <https://docs.flutter.dev/get-started/install/linux>.  The
Android Setup is not required - just the Linux setup from the bottom of the
page.
