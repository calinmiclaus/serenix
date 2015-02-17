#!/bin/bash

version=`cat version`
version=$(( $version + 1 ))

# installs the tools needed to build the iso 
#apt-get install debootstrap syslinux squashfs-tools genisoimage

function info()
{
    local GREEN="\033[0;32m"
    local NO_COLOUR="\033[0m"

    echo -e "===== ${GREEN}$*${NO_COLOUR}"
}

function err()
{
    local RED="\033[0;31m"
    local NO_COLOUR="\033[0m"

    echo -e "===== ${RED}$*${NO_COLOUR}"
}

function warn()
{
    local YELLOW="\033[0;33m"
    local NO_COLOUR="\033[0m"

    echo -e "===== ${YELLOW}$*${NO_COLOUR}"
}

# create the directory 'chroot', exit if it exists
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
    echo -n "There doesen't seem to be anything mounted inside 'chroot'. Do you want to remove it forcefully [y/n] ? "
    read answer
    [ "$answer" == "y" ] &&
        {
	    rm -rf chroot
	    mkdir -p chroot
	    info "Directory removed, an empty one created"
	} ||
	{
	    echo "Exiting..."
	    exit 1
	}
fi
}

# install the base system in chroot
info "Installing the base system in chroot"
#debootstrap --arch=amd64 saucy chroot

#FIXME: temporary
cp -R chroot.clean/* chroot/

# mount device files in chroot/dev
info "Mounting /dev in chroot"
mount -o bind /dev chroot/dev

# copying sources.list and resolv.conf in chroot/etc
info "Copying /etc/hosts, /etc/resolv.conf"
mkdir chroot/etc
cp /etc/hosts chroot/etc/hosts
cp /etc/resolv.conf chroot/etc/resolv.conf

info "Copying resources to chroot"
cp -R resources/* chroot/


# copying the customization script in chroot
info "Running customize_chroot.sh"
cp customize_chroot.sh chroot/
chmod +x chroot/customize_chroot.sh

#err "acuma rulez customize_chroot, intra manual pe el"
#read

# run the customization script in chroot. This will take a while, it will install all additional packages...
chroot chroot /customize_chroot.sh $version

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
	unmount chroot/dev
}

info "Preparing the livecd image"
mkdir -p image/{casper,isolinux,install}

# copy kernel files and other boot related stuff
info "Copying boot stuff, isolinux, memtest..."
cp chroot/boot/vmlinuz-*-generic image/casper/vmlinuz
cp chroot/boot/initrd.img-*-generic image/casper/initrd.lz
cp /boot/memtest86+.bin image/install/memtest

cp /usr/lib/syslinux/isolinux.bin image/isolinux/
cp isolinux.cfg image/isolinux/
cat <<EOF >image/isolinux/isolinux.txt
************************************************************************

This is Serenix Dawn, build $version.

Trough serenity you will achive enlightenment.

************************************************************************
EOF

# create manifest
info "Create casper manifest"
chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | tee image/casper/filesystem.manifest
cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop

# FIXME: add ubiquity and other unnecessary packages
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for pkg in $REMOVE 
do
  sed -i "/${pkg}/d" image/casper/filesystem.manifest-desktop
done

# compress the chroot environment
info "Compress the chroot environment"
mksquashfs chroot image/casper/filesystem.squashfs

# write the image size, its needed by the installer
info "Finalizing iso"
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

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

# build the iso
info "Build the iso"
mkisofs -r -V "Serenix $version" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../serenix-${version}.iso . && echo $version >../version
cd ..

info "Deleting image remains"
rm -rf image

info "Finish!"
