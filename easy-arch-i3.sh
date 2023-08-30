#!/bin/bash

# Cleaning the TTY.   
clear

# Cosmetics (colors for text).  
BOLD='\e[1m'  
BRED='\e[91m'  
BBLUE='\e[34m'    
BGREEN='\e[92m'  
BYELLOW='\e[93m'  
RESET='\e[0m'  

# Pretty print (function).  
info_print () {  
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"  
}  

# Pretty print for input (function).
input_print () {  
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"  \
}

# Alert user of bad input (function).  
error_print () {  
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"  
}

info_print "Let's install all the things to get i3 working. Warning this will flatten your current i3 configs."

if [ -x "$(command -v yay)" ]; then
    print "Found yay install"
else
    print "Will install yay now."
    git clone https://aur.archlinux/yay.git
    cd yay
    makepgk -fsri
    cd ..
    rm -rf yay/
fi

pacman -S --needed $(cat deps.pacman)
yay -S --noconfirm --needed $(cat deps.yay)

# Folder to build 
# ~/.config
# ~/.config/rofi
# ~/.config/dunst
# ~/.config/redshift
# ~/.vim

# Install yay (Yet Another Yogurt) AUR Helper written in Go
