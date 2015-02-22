#!/bin/bash
# variant speciffic code
# it will get executed inside chroot

# FIXME: until I add a pre_packages.sh and post_packages.sh, install ppa's from here
# also, this could be done from resources/etc/apt/
apt-add-repository -y ppa:ubuntu-mate-dev/ppa
apt-add-repository -y ppa:ubuntu-mate-dev/trusty-mate
apt-get -y update
apt-get -y upgrade
apt-get -y install ubuntu-mate-core ubuntu-mate-desktop mate-session-manager

dpkg --configure -a


# creating/updadeing icon caches
find /usr/share/icons -maxdepth 1 -type d|grep -vx "/usr/share/icons"|while read icon;
do
    gtk-update-icon-cache $icon
done
