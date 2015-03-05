#!/bin/bash

logoutput="/serenix_output.log"

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
    local GREEN="\033[0;32m"
    local NO_COLOUR="\033[0m"

    echo -e "==-== `date +%D-%T` ${bldgrn}$*${txtrst}"
    echo -e "==-== `date +%D-%T` $*" >>$logoutput
}

function err()
{
    local RED="\033[0;31m"
    local NO_COLOUR="\033[0m"

    echo -e "==-== `date +%D-%T` ${bldred}$*${txtrst}"
    echo -e "==-== `date +%D-%T` $*" >>$logoutput
}


info "Running in chroot"

info "Mounting /proc, /sys, /dev/pts"
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export HOME=/root
export LC_ALL=C

# gets the version of the build as the first argument
version=$1

info "Copying resources to system"
cp -Rf resources/* /

# ubuntu extras
info "Adding ubuntu-extras gpg key"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192 >>$logoutput

info "Updating system"
apt-get -y update >>$logoutput

info "Installing dbus"
apt-get -y install dbus dbus-x11 >>$logoutput

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl >>$logoutput

#NOTE: grub-pc is interactive, so we use the noninteractive flag
info "Installing kernel"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install linux-generic linux-headers-generic >>$logoutput

info "Installing memtest86+"
apt-get -y install memtest86+ >>$logoutput

info "Installing casper, ubuntu-standard, os-prober"
apt-get -y --allow-unauthenticated install ubuntu-standard casper lupin-casper discover laptop-detect os-prober >>$logoutput

# configure casper
info "Configuring casper"
cat <<EOF >/etc/casper.conf
# This file should go in /etc/casper.conf
# Supported variables are:
# USERNAME, USERFULLNAME, HOST, BUILD_SYSTEM, FLAVOUR

export USERNAME="serenix"
export USERFULLNAME="Live session user"
export HOST="serenix"
export BUILD_SYSTEM="Ubuntu"

# USERNAME and HOSTNAME as specified above won't be honoured and will be set to
# flavour string acquired at boot time, unless you set FLAVOUR to any
# non-empty string.

export FLAVOUR="Ubuntu"
EOF

# configure plymouth
info "Configuring plymouth"
cat <<EOF >/lib/plymouth/themes/ubuntu-text/ubuntu-text.plymouth
[Plymouth Theme]
Name=Ubuntu Text
Description=Text mode theme based on ubuntu-logo theme
ModuleName=ubuntu-text

[ubuntu-text]
title=Serenix Dawn $version
black=0x000066
white=0xffffff
brown=0x000000
blue=0x988592
EOF

info "Installing console tools"
apt-get -y install plymouth-x11 mc nano >>$logoutput

info "Installing xorg"
apt-get -y install xserver-xorg xinit xterm >>$logoutput

# FIXME: unauthenticated repo?
info "Installing ubiquity"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --allow-unauthenticated install ubiquity-frontend-gtk ubiquity ubiquity-frontend-gtk ubiquity-casper >>$logoutput

info "Installing desktop-base, gtk-engines"
apt-get -y install desktop-base gtk2-engines-pixbuf gtk2-engines >>$logoutput

# FIXME: this is a dirty hack. Ubiquity fails if this file is present. Investigate further
rm /usr/lib/ubiquity/apt-setup/generators/40cdrom

# START variant specific stuff

info "Installing variant specific packages"
cat /packages.list|grep -v ^\# | while read packages;
do
    # make sure $packages is not an empty line (or contains just spaces)
    [ ! -z "`echo $packages`" ] &&
	{
	    info "Installing $packages (output stripped)"
	    # FIXME: if I don't redirect the output, the while loop gets screwed (because of "read packages" I guess).
	    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --allow-unauthenticated install $packages >>$logoutput

	    # time consuming but might be usefull, some failed packages might need this
	    apt-get -y -f install >>$logoutput
        }
done

info "Running variant specific code"
bash /variant.sh

# END variant speciffic stuff

rm /var/lib/dbus/machine-id
dpkg-divert --rename --remove /sbin/initctl

info "Cleaning up"
apt-get -y -f install >>$logoutput
apt-get -y clean >>$logoutput
apt-get -y autoremove >>$logoutput
rm -rf /tmp/*

info "Copying resources to system (again)"
cp -Rf resources/* /
rm -rf resources

info "Unmounting /proc, /sys, /dev/pts"
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts

info "Exiting from customize_chroot"
exit
