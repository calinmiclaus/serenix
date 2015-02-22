
# Serenix Linux iso builder

### Why ?
I would like an ubuntu/debian distro with enlightenment as window manager. It should focus on security and privacy, in the end.
Also, an education-oriented variant whould be nice to have.

### What is here so far
* a builder script which spits out an iso
* livecd mode
* system is installable using ubuntu's ubiquity installer
* templates for multiple variants (e17, e19, mate, xfce, gnome-shell)
* bugs

### What is missing
* a more mature builder
* variant customizations
* documentation

### Status of variants
* mate
    * lacks proper package selection
    * template is still broken

* xfce
    * some panel customizations
    * lacks proper package selection

* e17
    * uses packages from ubuntu repos
    * some panel customizations
    * mathing E17gtk theme
    * lacks proper package selection

* gnome-shell
    * lacks proper package selection
    * considered pre-alpha

* e19
    * uses packages from bodhi's repos
    * ubiquity behaves strangely (bodhi's customizations ?)
    * mathing E17gtk theme
    * lacks proper package selection
    * considered pre-alpha


# How to build an iso

```
git clone https://github.com/calinmiclaus/serenix.git
cd serenix
./build.sh VARIANTNAME
```
* This will build a new iso (called `serenix-BUILDNR-VARIANTNAME_amd64.iso`)
* must run on an *ubuntu64 14.04 system
* make sure to have at least 4GB free disk space
* make sure to run the build script as root (as it requires mount/chroot privileges), on a partition which supports setuid files (needed for the suid files in the chroot environment).
* variant exists in the *variants/* directory

## Variant structure
A variant is a folder (in *variants/*) which has the following structure :
* resources/ - a folder which holds files which will be copied onto the target system
* packages.list - a list of packages which will be installed on the target system
* variant.sh - a script which is ran after all the packages have been installed. You can put customization code here, if you need to

## Under the hood
* based on Ubuntu 14.04 (might work on debian also though it uses ubiquity)

### The build steps

* create a minimal base system
    * debootstrap into the `chroot` directory
    * copy /etc/hosts, /etc/resolv.conf (needed for apt-get)
* copy resources (variants/*VARIANTNAME*/resources/) to the newly created system. These may include:
    * etc/apt/sources.list (for extra repos one might need)
    * usr/share/themes/... (gtk themes)
    * /etc/skel/... files (.xinitrc, .gtkrc-2.0, .config, ...). There will be places in the user's home directory, both on the livecd as well as the target system
* chroot into that system and run the configuration script (`customize_chroot.sh`)
    * mount /proc, /sys and /dev/pts
    * import apt keys (for ubuntu extras or others)
    * install dbus, kernel
    * install and configure casper (livecd tool)
    * configure plymouth (startup "theme")
    * install some console tools (mc, ...)
    * install xorg, xinit, xterm (we need these for now, for ubiquity-gtk)
    * install variant speciffic packages (from variants/VARIANTNAME/packages.list)
    * optionally run speciffic variant customization code (from variants/VARIANTNAME/variant.sh)
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
    * remove the `chroot` directory, if no process uses *chroot/dev*
* increment the build number (in *variants/VARIANTNAME/build*)
