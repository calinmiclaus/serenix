#!/bin/bash

txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White
bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White
txtrst='\e[0m'    # Text Reset


function info()
{
    echo -e "===== `date +%D-%T` ${bldgrn}$*${txtrst}"
    echo "===== `date +%D-%T` $*" >>$logoutput
}

function err()
{
    echo -e "===== `date +%D-%T` ${bldred}$*${txtrst}"
    echo "===== `date +%D-%T` $*" >>$logoutput
}

function warn()
{
    echo -e "===== `date +%D-%T` ${bldylw}$*${txtrst}"
    echo "===== `date +%D-%T` $*" >>$logoutput
}


variant=$1

# check if we have the first argument (variant)
[ $# -ne 1 ] &&
    {
    err "No variant specified."
    echo "Syntax:"
    echo "`basename $0` <variant>"
    echo
    echo "Here is a list of available variants (taken from the 'variants' directory):"
    echo -ne "${bldgrn}";ls variants/;echo -ne "${txtrst}"
    err "Exiting..."
    exit 1
    }

[ ! -d variants/${variant} ] &&
    {
	err "Variant ${variant} is missing from the 'variants' directory. Exiting..."
        echo
        echo "Here is a list of available variants (taken from the 'variants' directory):"
        echo -ne "${bldgrn}";ls variants/;echo -ne "${txtrst}"
	exit 1
    }

bitness="amd64"
buildversion=`cat variants/${variant}/build`
[ -z "${buildversion}" ] && buildversion=0
buildversion=$(( $buildversion + 1 ))
version="14.04-${variant}-build${buildversion}"

logoutput="serenix-${version}.log"

# installs the tools needed to build the iso 
apt-get -y install debootstrap syslinux squashfs-tools genisoimage >>$logoutput

# create the directory 'chroot', exit if it exists. Make sure nothing is mounted in it
[ ! -d chroot ] && mkdir -p chroot || \
{
warn "The 'chroot' directory already exists"

mount|grep chroot
chrootret=$?

if [ $chrootret -eq 0 ];
then
    err "There is something mounted in chroot. Handle it yourself. Exiting..."
    exit 1
else
    info "There doesen't seem to be anything mounted inside 'chroot'. Removing it"
    rm -rf chroot
    mkdir -p chroot
    info "Directory removed, an empty one created"
fi
}

# install the base system in chroot
info "Installing the base system in chroot"
debootstrap --arch=${bitness} trusty chroot >>$logoutput

#FIXME: temporary
#cp -R chroot.clean/* chroot/

# mount device files in chroot/dev
info "Mounting /dev in chroot"
mount -o bind /dev chroot/dev

# copy common resources BEFORE variant speciffic ones. Variant resources might need to overwrite common ones
info "Copying common resources to chroot"
mkdir chroot/resources
cp -R variants/COMMON/* chroot/resources

info "Copying variant resources to chroot"
cp -R variants/${variant}/resources/* chroot/resources

# copying the customization script in chroot
info "Running customize_chroot.sh"
cp customize_chroot.sh chroot/
cp variants/${variant}/variant.sh chroot/
cp variants/${variant}/packages.list chroot/
chmod +x chroot/customize_chroot.sh
chmod +x chroot/variant.sh

# run the customization script in chroot. This will take a while, it will install all additional packages...
chroot chroot /customize_chroot.sh $version

# remove the scripts from chroot
rm -f chroot/customize_chroot.sh chroot/packages.list chroot/variant.sh

# kill the processes still running in chroot which use devices in chroot/dev (dbus,cups,...). This is needed for unmounting the dev directory
info "Killing hanged processes"
for pid in `lsof 2>/dev/null|grep chroot/dev|awk '{print $2}'|sort|uniq`;
do
  kill $pid
done

# give the processes some time to die
info "Sleep 5 seconds"
sleep 5

# unmount chroot/dev
info "Unmounting dev"
umount chroot/dev || \
    {
	err "Something went wrong, I cant unmount chroot/dev . Use 'lsof|grep chroot/dev' and kill the processes yourself."
	err "Press ENTER when done and MAKE SURE nobody uses chroot/dev any more !"
	read
	umount chroot/dev || \
	    {
	    err "Can't unmount chroot/dev. Investigate manually. Exiting..."
	    exit 1
	    }
    }

info "Preparing the livecd image"
mkdir -p image/{casper,isolinux,install}

# copy kernel files and other boot related stuff
info "Copying boot stuff, isolinux, memtest..."
cp chroot/boot/vmlinuz-*-generic image/casper/vmlinuz
cp chroot/boot/initrd.img-*-generic image/casper/initrd.lz
cp /boot/memtest86+.bin image/install/memtest

cp /usr/lib/syslinux/isolinux.bin image/isolinux/

cat <<EOF >image/isolinux/isolinux.cfg
DEFAULT live
LABEL live
  menu label ^Start or install Serenix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 200
PROMPT 0
EOF

cat <<EOF >image/isolinux/isolinux.txt
************************************************************************

This is Serenix Dawn, build $version.

Trough serenity you will achive enlightenment.

************************************************************************
EOF

# create manifest
info "Create casper manifest"
chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' > image/casper/filesystem.manifest
cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop

# FIXME: add ubiquity and other unnecessary packages
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for pkg in $REMOVE 
do
  sed -i "/${pkg}/d" image/casper/filesystem.manifest-desktop
done

# compress the chroot environment
info "Compress the chroot environment"
mksquashfs chroot image/casper/filesystem.squashfs >>$logoutput

# write the image size, its needed by the installer
info "Finalizing iso"
fssize=`printf $(du -sx --block-size=1 chroot | cut -f1)`

# add 2.5gb extra space
fssize=$(( $fssize + 500000000 ))
echo $fssize > image/casper/filesystem.size

# create diskdefines
cat <<EOF >image/README.diskdefines
#define DISKNAME Serenix
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHi386  0
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF
touch image/ubuntu
mkdir image/.disk
cd image/.disk
touch base_installable
echo "full_cd/single" > cd_type
echo "Ubuntu Remix" > info
echo "http://serenix-release-notes.com" > release_notes_url
cd ../..

# calculate md5sums
info "Calculate md5sums"
cd image
find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt

# build the iso and increment version if successfull
info "Build the iso"
mkisofs -r -V "Serenix $version" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../serenix-${version}_${bitness}.iso . >> $logoutput && echo $buildversion >../variants/${variant}/build
cd ..

info "Deleting image remains"
rm -rf image

info "Finish building Serenix $version!"
