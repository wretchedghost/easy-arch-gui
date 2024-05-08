#!/bin/bash

yay_install() {

    cd /opt
    git clone https://aur.archlinux.org/yay-git
    chown -R $username:$username ./yay-git
    cd yay-git
}

# This script is designed to install install the setup that is used in my i3-workstation repo

# function to check if running as root

pacman -Syyu

pacman -S - < pkglist.txt

# Yay AUR install
## check to make sure you are not running as root

yay_install
makepkg -si

# Yay packages install and themes
yay -S - < yaylist.txt
