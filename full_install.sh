#!/usr/bin/env -S bash -e

# Fixing annoying issue that breaks GitHub Actions
# shellcheck disable=SC2001

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
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Virtualization check (function). 
virt_check () {     
    hypervisor=$(systemd-detect-virt)     
    case $hypervisor in         
        kvm )   info_print "KVM has been detected, setting up guest tools."                 
            pacstrap /mnt qemu-guest-agent &>/dev/null                 
            systemctl enable qemu-guest-agent --root=/mnt &>/dev/null                 
            ;;         
        vmware  )   info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."                     
            pacstrap /mnt open-vm-tools >/dev/null                     
            systemctl enable vmtoolsd --root=/mnt &>/dev/null                     
            systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null                     
            ;;         
        oracle )    info_print "VirtualBox has been detected, setting up guest tools."                     
            pacstrap /mnt virtualbox-guest-utils &>/dev/null                     
            systemctl enable vboxservice --root=/mnt &>/dev/null                     
            ;;         
        microsoft ) info_print "Hyper-V has been detected, setting up guest tools."                     
            pacstrap /mnt hyperv &>/dev/null                     
            systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null                     
            systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null                     
            systemctl enable hv_vss_daemon --root=/mnt &>/dev/null                     
            ;;     
    esac 
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "List of kernels:"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied."
    info_print "2) Hardened: A security-focused Linux kernel. Forgoes the GLIBC for MUSL LIBC which is lighter on resources than GLIBC but GLIBC is faster."
    info_print "3) Longterm: Long-term support (LTS) Linux kernel. Older hardware but also for more stablility."
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage. I would suggest if you run on modern hardware."
    input_print "Please select the number of the corresponding kernel (e.g. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "You did not enter a valid selection, please try again."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Network utilities:"
    info_print "1) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "2) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice
    if ! ((1 <= network_choice <= 5)); then
        error_print "You did not enter a valid selection, please try again."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installing and enabling IWD."
            pacstrap /mnt iwd >/dev/null
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installing and enabling NetworkManager."
            pacstrap /mnt networkmanager >/dev/null
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installing and enabling wpa_supplicant and dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installing dhcpcd."
            pacstrap /mnt dhcpcd >/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
    esac
}

# User enters a password for the LUKS Container (function).
lukspass_selector () {
    input_print "Please enter a password for the LUKS container (you're not going to see the password): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "You need to enter a password for the LUKS Container, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password for the LUKS container again (you're not going to see the password): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector () {
    input_print "Please enter a password for the root user (you're not going to see it): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# User enters a hostname (function).
hostname_selector () {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# User chooses the locale (function).
locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search locales): " locale
    read -r locale
    case "$locale" in
        '') locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0;;
        '/') sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
                clear
                return 1;;
        *)  if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "The specified locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
    esac
}

# User chooses the console keyboard layout (function).
keyboard_selector () {
    input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to look up for keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
        '') kblayout="us"
            info_print "The standard US keyboard layout will be used."
            return 0;;
        '/') localectl list-keymaps
             clear
             return 1;;
        *) if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
               error_print "The specified keymap doesn't exist."
               return 1
           fi
        info_print "Changing console layout to $kblayout."
        loadkeys "$kblayout"
        return 0
    esac
}

yayinstall() { 
    cd /opt
    git clone https://aur.archlinux.org/yay-git
    chown -R $username:$username ./yay-git
    cd yay-git 
    su $username
    makepkg -si 
    return # used to exit the function and not the script due to needing to switch to non root user
}

# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
=============================================================================================================
███████╗ █████╗ ███████╗██╗   ██╗      █████╗ ██████╗  ██████╗██╗  ██╗      ███████╗██╗  ██╗████████╗██╗  ██╗
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝     ██╔══██╗██╔══██╗██╔════╝██║  ██║      ██╔════╝╚██╗██╔╝╚══██╔══╝██║  ██║
█████╗  ███████║███████╗ ╚████╔╝█████╗███████║██████╔╝██║     ███████║█████╗█████╗   ╚███╔╝    ██║   ███████║
██╔══╝  ██╔══██║╚════██║  ╚██╔╝ ╚════╝██╔══██║██╔══██╗██║     ██╔══██║╚════╝██╔══╝   ██╔██╗    ██║   ╚════██║
███████╗██║  ██║███████║   ██║        ██║  ██║██║  ██║╚██████╗██║  ██║      ███████╗██╔╝ ██╗   ██║        ██║
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝      ╚══════╝╚═╝  ╚═╝   ╚═╝        ╚═╝
=============================================================================================================
${RESET}"
info_print "Welcome to easy-arch, a script made in order to simplify the process of installing Arch Linux."
info_print "This script must be run on an EFI system. BIOS will not work. Checking now..."
sleep 2s

if [ -d /sys/firmware/efi ]; then 
    echo "System is running UEFI mode. The script will continue." 
else 
    echo "System is running in BIOS mode. Script will close now."
    exit 0
fi


# Setting up keyboard layout.
until keyboard_selector; do : ; done

# Set up time
timedatectl set-ntp true

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK="$ENTRY"
    info_print "Arch Linux will be installed on the following disk: $DISK"
    break
done

# Setting up LUKS password.
until lukspass_selector; do : ; done

# Setting up the kernel.
until kernel_selector; do : ; done

# User choses the network.
until network_selector; do : ; done

# User choses the locale.
until locale_selector; do : ; done

# User choses the hostname.
until hostname_selector; do : ; done

# User sets up the user/root passwords.
until userpass_selector; do : ; done
until rootpass_selector; do : ; done

# Warn user about deletion of old partition scheme.
input_print "This will delete the current partition table on $DISK once installation starts. Do you agree [y/N]?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit
fi
info_print "Wiping $DISK."
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 550MiB \
    set 1 esp on \
    mkpart CRYPTROOT 550MiB 100% \

ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the ESP as FAT32.
info_print "Formatting the EFI Partition as vFAT32."
mkfs.vfat -F32 "$ESP" &>/dev/null

# Creating a LUKS Container for the root partition.
info_print "Creating LUKS Container for the root partition."
echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null
echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d - 
fs_ext4="/dev/mapper/cryptroot"

# Formatting the LUKS Container as EXT4.
info_print "Formatting the LUKS container as EXT4."
mkfs.ext4 "$fs_ext4" &>/dev/null
mount "$fs_ext4" /mnt

mkdir /mnt/boot
mount "$ESP" /mnt/boot/

# Checking the microcode to install.
microcode_detector

# Setup the swapfile
info_print "Setting up a swapfile. What size do you want in MB? (ie 16384 = 16G, 24576 = 24G, or 32768 = 32G)"
sleep 1s
while :; do
    read -ep 'Swapfile Size: ' swap_response
    [[ $swap_response =~ ^[[:digit:]]+$ ]] || continue
    (( ( (swap_response=(10#$swap_response)) <= 99999 ) && swap_response >= 0 )) || continue
    break
done

#dd if=/dev/zero of=/mnt/.swapfile bs=1M count=$swap_response status=progress
dd if=/dev/zero of=/mnt/.swapfile bs=1M count=$swap_response status=progress
chmod 600 /mnt/.swapfile
mkswap /mnt/.swapfile
swapon /mnt/.swapfile

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (this may take a while)."
sleep 3s
pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers grub rsync efibootmgr sudo vim git neofetch screenfetch bash-completion 

# Setting up the hostname.
echo "$hostname" > /mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new fstab."
genfstab -U /mnt >> /mnt/etc/fstab

# Setup tmpfs in /mnt/etc/fstab.
info_print "Generating a tmpfs with the size of 8G. This size can be changed at anytime but please perform a reboot after the change to make sure things don't get wonky. noatime is disabled as default as this is not preferred to have enabled with an NVMe drive. For a SSD you SHOULD enable noatime."
sleep 3s
echo "tmpfs /tmp    tmpfs   rw,nodev,nosuid,size=8G,mode=1700 0 0" >> /mnt/etc/fstab

# Configure selected locale and console keymap
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

# Setting hosts file.
info_print "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Virtualization check.
#virt_check

# Setting up the network.
network_installer

# Configuring /etc/mkinitcpio.conf.
info_print "Configuring /etc/mkinitcpio.conf."
cat > /mnt/etc/mkinitcpio.conf <<EOF
HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)
EOF

# Setting up LUKS2 encryption in grub.
info_print "Setting up grub config."
UUID=$(blkid -s UUID -o value $CRYPTROOT)
sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&cryptdevice=UUID=$UUID:cryptroot," /mnt/etc/default/grub

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, GRUB)."
arch-chroot /mnt /bin/bash -e << EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=ARCHLINUX &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel,power -s /bin/bash "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Pacman eye-candy features and multilib.
info_print "Enabling colors, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf

printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /mnt/etc/pacman.conf

pacman -Syyu --noconfirm
pacman -S --noconfirm xorg-server xorg-xinit xorg-xrandr arandr xorg-xkill xorg-xset openssh curl wget zip unzip urxvt-perls i3-wm i3lock i3blocks lxappearance scrot picom feh dunst rofi conky ranger gsimplecal galculator xfce4-clipman-plugin volumeicon xautolock imagemagick ttf-font-awesome ttf-dejavu firefox thunar gvfs gvfs-smb gvfs-mtp gvfs-nfs wine thunderbird barrier pavucontrol lightdm-slick-greeter android-tools cifs-utils ntfs-3g nfs-utils neomutt base-devel

# Pull configs from git.
su $username
cd $username
git clone https://git.wretchednet.com/wretchedghost/i3-wretchedbox
cd i3-wretchedbox
rsync -a .bashrc .fehbg Pictures .tmux.conf .vim .vimrc .xinitrc .Xresources /home/$username/
cd .config
mkdir /home/$username/.config
rsync -a dunst i3 neomutt newsboat ranger redshift rofi /home/$username/.config/
exit 1

# Enable systemd services.
systemctl enable lightdm
systemctl enable sshd

# yay install.
until yayinstall; do : ; done 

# Finishing up.
info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
exit
