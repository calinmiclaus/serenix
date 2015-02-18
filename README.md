
# Serenix Linux iso builder

### Why ?
I would like an ubuntu/debian distro with e19 as a window manager. It should focus on security and privacy. 
Also, an education-oriented version should be taken into consideration.

### What is here so far
* a builder script which spits out an iso, the customization is relatively easy to do
* livecd mode working
* bugs

### What is missing
* a more mature builder
* a properly configured installer for the livecd (ubiquity)
* customizations
* proper package selection
* builtin support for multiple variants (kde, educational, minimal, ...)
* documentation

# How to build an iso

```
git clone https://github.com/calinmiclaus/serenix.git
cd serenix
./build.sh
```
* This will build a new iso (called `serenix-VERSION.iso`)
* must run on an *Ubuntu64 14.04 system
* make sure to have at least 1.2GB free disk space
* make sure to run the build script as root (as it requires mount/chroot privileges), on a partition which supports setuid files (needed for the suid files in the chroot environment).
* the builder won't erase the *chroot* directory automatically at the end. On invocation however, it will ask you if you want to delete it. If manual testing takes place in the chroot environment some processes might hook up /dev and its unmount will fail. In this case, the builder will complain and you will have to unmount *chroot/dev* and delete *chroot* manually . It is a security measure designed for your own protection :)

## Under the hood
* based on Ubuntu 14.04 (could work for debian also)

### The build steps

* create a minimal base system
    * debootstrap into the `chroot` directory
    * copy /etc/hosts, /etc/resolv.conf (needed for apt-get)
* copy artefacts to the newly created system
    * /etc/apt/sources.list (includes bodhi's repos)
    * gtk themes (E17gtk)
    * skel files (.xinitrc, .gtkrc-2.0, .e, .elementary)
    * e19 themes
* chroot into that system and run the configuration script (`customize_chroot.sh`)
    * mount /proc, /sys and /dev/pts
    * import apt keys (for ubuntu extras or others)
    * install dbus, kernel
    * install and configure casper (livecd tool)
    * configure plymouth (startup "theme")
    * install xorg
    * install e19
    * install xfce
    * install other tools (mc, ...)
    * unmount /proc, /sys, /dev/pts
* create an iso image
    * create an `image` directory where to store the iso content
    * copy kernel binaries, memtest86
    * copy isolinux conf files
    * configure casper (remove ephemeral livecd packages from /casper/filesystem.manifest-desktop)
    * compress the chroot directory (mksquashfs) and put it in here
    * calculate md5sum files
    * build the iso (mkisofs)
* cleanup
    * remove the `image` directory
    * we'll leave `chroot` here for debuging
* increment the build number (the the *version* file)
