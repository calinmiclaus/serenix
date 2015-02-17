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

info "Current buildnumber is : $version"

# ubuntu extras
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 16126D3A3E5C1192

info "Updating system"
apt-get -y update

info "Installing dbus"
apt-get -y install dbus dbus-x11

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl

#FIXME: here is grub-pc installed, which requires user intervention
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

export USERNAME="serenity"
export USERFULLNAME="Live session user"
export HOST="serenix"
export BUILD_SYSTEM="Ubuntu"

# USERNAME and HOSTNAME as specified above won't be honoured and will be set to
# flavour string acquired at boot time, unless you set FLAVOUR to any
# non-empty string.

# export FLAVOUR="Ubuntu"
EOF

info "Installing utility tools"
apt-get -y install plymouth-x11 mc nano 

# configure plymouth
#FIXME: still taken into account ?

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

# e18 (from vase's repo, deprecated)
#apt-get -y install enlightenment libasound2-plugins alsa-utils terminology ephoto econnman-bin

# install e19 and all the apps from bodhi's repos
#apt-get install bodhi-icons elaptopcheck esudo e19 eepdater matrilneare-icon-theme comp-scale desksanity-e19 deskshow-e19 eandora eccess econcentration econnman edbus edeb efbb efx elemines enjoy emotion-generic-players enventor epad ephoto epour equate eruler etext radiance-blue-theme-e19 radiance-blue-theme-gtk rage terminology valosoitin elementary efl python-efl

# install e19

info "Installing e19"
apt-get --allow-unauthenticated -y install dh-python
apt-get --allow-unauthenticated -y install bodhi-icons elaptopcheck esudo e19 eepdater matrilneare-icon-theme comp-scale desksanity-e19 deskshow-e19 econnman edbus edeb efx elemines radiance-blue-theme-e19 radiance-blue-theme-gtk terminology elementary efl python-efl

# FIXME: unauthenticated repo?
info "Installing ubiquity"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --allow-unauthenticated install ubiquity-frontend-gtk ubiquity-casper ubiquity

info "Installing xorg"
apt-get -y install xserver-xorg

# FIXME: remove this after stabilizing e19
info "Installing xfce"
apt-get --allow-unauthenticated -y install xfce4 xfwm4-themes xfce4-goodies xfce4-power-manager thunar-archive-plugin thunar gnome-icon-theme thunar xfce4-terminal gtk2-engines-pixbuf

info "Customizations..."

info "Setting E17gtk as default gtk theme"
echo "include \"/usr/share/themes/E17gtk/gtk-2.0/gtkrc\"" >/etc/skel/.gtkrc-2.0

#FIXME: find a way to start x (or a DM) automatically
info "Adding enlightenment_start to xinitrc"
echo "exec enlightenment_start" >/etc/skel/.xinitrc

#info "Adding xfce to xinitrc"
#echo "exec xfce4" >/etc/skel/.xinitrc

rm /var/lib/dbus/machine-id
dpkg-divert --rename --remove /sbin/initctl

info "Cleaning up"
apt-get clean
rm -rf /tmp/*

info "Unmounting /proc, /sys, /dev/pts"
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts
exit
