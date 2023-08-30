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

info_print "Let's install all the things to get i3 working. 
