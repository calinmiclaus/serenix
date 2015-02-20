#!/bin/bash

function info()
{
    local GREEN="\033[0;32m"
    local NO_COLOUR="\033[0m"

    echo -e "==-== ${GREEN}$*${NO_COLOUR}"
}

function err()
{
    local RED="\033[0;31m"
    local NO_COLOUR="\033[0m"

    echo -e "==-== ${RED}$*${NO_COLOUR}"
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

# ubuntu extras
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192

info "Updating system"
apt-get -y update

info "Installing dbus"
apt-get -y install dbus dbus-x11

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl

#NOTE: grub-pc is interactive, so we use the noninteractive flag
info "Installing kernel"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install linux-generic

info "Installing memtest86+"
apt-get -y install memtest86+

info "Installing casper, ubuntu-standard, os-prober"
apt-get -y --allow-unauthenticated install ubuntu-standard casper lupin-casper discover laptop-detect os-prober

# configure casper
info "Configuring casper"
cat <<EOF >/etc/casper.conf
# This file should go in /etc/casper.conf
# Supported variables are:
# USERNAME, USERFULLNAME, HOST, BUILD_SYSTEM, FLAVOUR

export USERNAME="serenix"
export USERFULLNAME="Live session user"
export HOST="serenix"
export BUILD_SYSTEM="Ubuntu1"

# USERNAME and HOSTNAME as specified above won't be honoured and will be set to
# flavour string acquired at boot time, unless you set FLAVOUR to any
# non-empty string.

export FLAVOUR="Ubuntu2"
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
apt-get -y install plymouth-x11 mc nano 

info "Installing xorg"
apt-get -y install xserver-xorg

# FIXME: unauthenticated repo?
info "Installing ubiquity"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --allow-unauthenticated install ubiquity-frontend-gtk ubiquity ubiquity-frontend-gtk ubiquity-casper

# FIXME: this is a dirty hack. Ubiquity fails if this file is present. Investigate further
rm /usr/lib/ubiquity/apt-setup/generators/40cdrom

# FIXME: shamelessly replacing "Bodhi" with "Serenix" in the desktop installer launcher
sed -i s/"Bodhi Linux 3.0.0"/"Serenix $version"/g /usr/share/applications/ubiquity.desktop


# START variant specific stuff

info "Installing variant specific packages"
cat /packages.list|grep -v ^\# | while read packages;
do
    [ ! -z "$packages" ] &&
	{
	    info "Installing $packages (output stripped)"
	    # FIXME: if I don't redirect the output, the while loop gets screwed (because of "read packages" I guess).
	    DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --allow-unauthenticated install $packages >/dev/null
        }
done

info "Running variant specific code"
bash /variant.sh

# END variant speciffic stuff

rm /var/lib/dbus/machine-id
dpkg-divert --rename --remove /sbin/initctl

info "Cleaning up"
apt-get clean
apt-get autoremove
rm -rf /tmp/*

info "Unmounting /proc, /sys, /dev/pts"
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts
exit
