#!/usr/bin/env -S bash -e

# Enhanced Arch Linux Base Installation Script
# shellcheck disable=SC2001

clear

# Colors and formatting
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print functions
info_print() {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

input_print() {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

error_print() {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

critical_error() {
    error_print "CRITICAL ERROR: $1"
    error_print "Installation cannot continue. System state may be inconsistent."
    exit 1
}

# Check if packages exist before installation
check_packages() {
    local packages=("$@")
    info_print "Verifying package availability..."
    for pkg in "${packages[@]}"; do
        if ! pacman -Ss "^${pkg}$" &>/dev/null; then
            error_print "Package '$pkg' not found in repositories"
            return 1
        fi
    done
    info_print "All packages verified successfully"
    return 0
}

# Check internet connectivity
check_internet() {
    info_print "Checking internet connectivity..."
    if ! ping -c 3 8.8.8.8 &>/dev/null; then
        error_print "No internet connection detected"
        return 1
    fi
    info_print "Internet connection verified"
    return 0
}

# Backup function for timezone setup
setup_timezone() {
    info_print "Setting up timezone..."
    
    # Try to get timezone from internet first
    if timezone=$(curl -s --connect-timeout 10 http://ip-api.com/line?fields=timezone 2>/dev/null) && [[ -n "$timezone" ]]; then
        if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
            ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
            info_print "Timezone set to: $timezone"
            return 0
        fi
    fi
    
    # Fallback to UTC if internet fails
    error_print "Could not determine timezone automatically, falling back to UTC"
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    info_print "Timezone set to: UTC (you can change this later with 'timedatectl set-timezone')"
    return 0
}

# Virtualization check
virt_check() {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm)
            info_print "KVM detected, setting up guest tools."
            if ! pacstrap /mnt qemu-guest-agent &>/dev/null; then
                error_print "Failed to install qemu-guest-agent"
                return 1
            fi
            systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
            ;;
        vmware)
            info_print "VMware detected, setting up guest tools."
            if ! pacstrap /mnt open-vm-tools >/dev/null; then
                error_print "Failed to install open-vm-tools"
                return 1
            fi
            systemctl enable vmtoolsd --root=/mnt &>/dev/null
            systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
            ;;
        oracle)
            info_print "VirtualBox detected, setting up guest tools."
            if ! pacstrap /mnt virtualbox-guest-utils &>/dev/null; then
                error_print "Failed to install virtualbox-guest-utils"
                return 1
            fi
            systemctl enable vboxservice --root=/mnt &>/dev/null
            ;;
        microsoft)
            info_print "Hyper-V detected, setting up guest tools."
            if ! pacstrap /mnt hyperv &>/dev/null; then
                error_print "Failed to install hyperv"
                return 1
            fi
            systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
            systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
            systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
            ;;
    esac
}

# Kernel selection
kernel_selector() {
    info_print "Available kernels:"
    info_print "1) linux (Stable): Vanilla Linux kernel with Arch patches"
    info_print "2) linux-hardened: Security-focused kernel"
    info_print "3) linux-lts: Long-term support kernel for stability"
    info_print "4) linux-zen: Desktop-optimized kernel"
    input_print "Select kernel (1-4): "
    read -r kernel_choice
    case $kernel_choice in
        1) kernel="linux" ;;
        2) kernel="linux-hardened" ;;
        3) kernel="linux-lts" ;;
        4) kernel="linux-zen" ;;
        *) error_print "Invalid selection, please try again."; return 1 ;;
    esac
    return 0
}

# Network utility selection
network_selector() {
    info_print "Network utilities:"
    info_print "1) NetworkManager (Recommended): Universal network management"
    info_print "2) systemd-networkd: Lightweight, systemd-native"
    info_print "3) iwd: Intel's modern WiFi daemon"
    info_print "4) dhcpcd: Basic DHCP client for Ethernet"
    input_print "Select network utility (1-4): "
    read -r network_choice
    if ! ((1 <= network_choice <= 4)); then
        error_print "Invalid selection, please try again."
        return 1
    fi
    return 0
}

# Install selected network utility
network_installer() {
    case $network_choice in
        1)
            info_print "Installing NetworkManager..."
            if ! pacstrap /mnt networkmanager >/dev/null; then
                error_print "Failed to install NetworkManager"
                return 1
            fi
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        2)
            info_print "Installing systemd-networkd..."
            systemctl enable systemd-networkd --root=/mnt &>/dev/null
            systemctl enable systemd-resolved --root=/mnt &>/dev/null
            ;;
        3)
            info_print "Installing iwd..."
            if ! pacstrap /mnt iwd >/dev/null; then
                error_print "Failed to install iwd"
                return 1
            fi
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        4)
            info_print "Installing dhcpcd..."
            if ! pacstrap /mnt dhcpcd >/dev/null; then
                error_print "Failed to install dhcpcd"
                return 1
            fi
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
    esac
}

# LUKS password setup
lukspass_selector() {
    input_print "Enter LUKS container password (hidden): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "Password cannot be empty, please try again."
        return 1
    fi
    echo
    input_print "Confirm LUKS password (hidden): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# User account setup
userpass_selector() {
    input_print "Enter username (leave empty to skip user creation): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    
    # Validate username
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        error_print "Invalid username. Use lowercase letters, numbers, underscore, and hyphen only."
        return 1
    fi
    
    input_print "Enter password for $username (hidden): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "Password cannot be empty, please try again."
        return 1
    fi
    echo
    input_print "Confirm password (hidden): "
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Root password setup
rootpass_selector() {
    input_print "Enter root password (hidden): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "Root password cannot be empty, please try again."
        return 1
    fi
    echo
    input_print "Confirm root password (hidden): "
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# CPU microcode detection
microcode_detector() {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "AMD CPU detected, will install AMD microcode."
        microcode="amd-ucode"
    else
        info_print "Intel CPU detected, will install Intel microcode."
        microcode="intel-ucode"
    fi
}

# Hostname setup
hostname_selector() {
    input_print "Enter hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "Hostname cannot be empty."
        return 1
    fi
    
    # Validate hostname
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        error_print "Invalid hostname. Use letters, numbers, and hyphens only."
        return 1
    fi
    return 0
}

# Locale selection
locale_selector() {
    input_print "Enter locale (xx_XX format, empty for en_US, '/' to browse): "
    read -r locale
    case "$locale" in
        '')
            locale="en_US.UTF-8"
            info_print "Using default locale: $locale"
            return 0
            ;;
        '/')
            sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
            clear
            return 1
            ;;
        *)
            if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "Locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
    esac
}

# Keyboard layout selection
keyboard_selector() {
    input_print "Enter keyboard layout (empty for US, '/' to browse): "
    read -r kblayout
    case "$kblayout" in
        '')
            kblayout="us"
            info_print "Using US keyboard layout."
            return 0
            ;;
        '/')
            localectl list-keymaps
            clear
            return 1
            ;;
        *)
            if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
                error_print "Keyboard layout doesn't exist."
                return 1
            fi
            info_print "Setting keyboard layout to $kblayout."
            loadkeys "$kblayout"
            return 0
    esac
}

# Pre-flight checks
preflight_checks() {
    info_print "Running pre-flight checks..."
    
    # Check internet connectivity
    if ! check_internet; then
        error_print "Internet connection required for installation"
        return 1
    fi
    
    # Update package databases
    info_print "Updating package databases..."
    if ! pacman -Sy; then
        error_print "Failed to update package databases"
        return 1
    fi
    
    # Check if all required packages are available
    local base_packages=("base" "linux-firmware" "grub" "efibootmgr" "sudo" "vim" "git")
    if ! check_packages "${base_packages[@]}"; then
        error_print "Some required packages are not available"
        return 1
    fi
    
    info_print "Pre-flight checks completed successfully"
    return 0
}

# Welcome screen
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

info_print "Enhanced Arch Linux Base Installation Script"
info_print "This script installs a minimal base system with LUKS encryption"
sleep 2

# UEFI check
if [[ ! -d /sys/firmware/efi ]]; then
    error_print "This script requires UEFI mode. BIOS is not supported."
    exit 1
fi
info_print "UEFI mode confirmed."

# Run pre-flight checks
if ! preflight_checks; then
    critical_error "Pre-flight checks failed"
fi

# Configuration phase
info_print "=== CONFIGURATION PHASE ==="

until keyboard_selector; do : ; done
timedatectl set-ntp true

# Disk selection
info_print "Available disks:"
PS3="Select disk number: "
select ENTRY in $(lsblk -dpnoNAME | grep -P "/dev/(sd|nvme|vd|mmc)"); do
    DISK="$ENTRY"
    info_print "Selected disk: $DISK"
    break
done

until lukspass_selector; do : ; done
until kernel_selector; do : ; done

# Check kernel package availability
if ! check_packages "$kernel" "${kernel}-headers"; then
    critical_error "Selected kernel '$kernel' is not available"
fi

until network_selector; do : ; done
until locale_selector; do : ; done
until hostname_selector; do : ; done
until userpass_selector; do : ; done
until rootpass_selector; do : ; done

# Swap size selection
info_print "Swap configuration:"
info_print "1) 8GB (recommended for 8-16GB RAM)"
info_print "2) 16GB (recommended for 16-32GB RAM)"
info_print "3) 32GB (recommended for 32GB+ RAM)"
info_print "4) Custom size"
info_print "5) No swap"
input_print "Select swap option (1-5): "
read -r swap_choice

case $swap_choice in
    1) swap_size=8192 ;;
    2) swap_size=16384 ;;
    3) swap_size=32768 ;;
    4) 
        input_print "Enter swap size in MB: "
        read -r swap_size
        if ! [[ "$swap_size" =~ ^[0-9]+$ ]]; then
            error_print "Invalid size, defaulting to 8GB"
            swap_size=8192
        fi
        ;;
    5) swap_size=0 ;;
    *) 
        error_print "Invalid selection, defaulting to 8GB"
        swap_size=8192
        ;;
esac

# Final confirmation
echo
info_print "=== INSTALLATION SUMMARY ==="
info_print "Target disk: $DISK"
info_print "Kernel: $kernel"
info_print "Hostname: $hostname"
info_print "Locale: $locale"
info_print "Keyboard: $kblayout"
[[ -n "$username" ]] && info_print "User: $username"
[[ $swap_size -gt 0 ]] && info_print "Swap: ${swap_size}MB" || info_print "Swap: Disabled"
echo

input_print "WARNING: This will ERASE ALL DATA on $DISK. Continue? [y/N]: "
read -r confirm
if [[ ! "${confirm,,}" =~ ^(yes|y)$ ]]; then
    info_print "Installation cancelled."
    exit 0
fi

# === POINT OF NO RETURN ===
info_print "=== STARTING INSTALLATION ==="

# Disk preparation
info_print "Preparing disk..."
if ! wipefs -af "$DISK" &>/dev/null; then
    critical_error "Failed to wipe disk $DISK"
fi
if ! sgdisk -Zo "$DISK" &>/dev/null; then
    critical_error "Failed to initialize GPT on $DISK"
fi

# Partitioning
info_print "Creating partitions..."
if ! parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 550MiB \
    set 1 esp on \
    mkpart CRYPTROOT 550MiB 100%; then
    critical_error "Failed to create partitions"
fi

ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"

# Wait for partition devices
sleep 2
if ! partprobe "$DISK"; then
    critical_error "Failed to update partition table"
fi

# Verify partitions exist
for i in {1..10}; do
    if [[ -e "$ESP" ]] && [[ -e "$CRYPTROOT" ]]; then
        break
    fi
    sleep 1
    if [[ $i -eq 10 ]]; then
        critical_error "Partition devices not found after creation"
    fi
done

# Format ESP
info_print "Formatting EFI partition..."
if ! mkfs.vfat -F32 "$ESP" &>/dev/null; then
    critical_error "Failed to format EFI partition"
fi

# LUKS setup
info_print "Setting up LUKS encryption..."
if ! echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null; then
    critical_error "Failed to create LUKS container"
fi
if ! echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -; then
    critical_error "Failed to open LUKS container"
fi

# Format root filesystem
info_print "Creating root filesystem..."
if ! mkfs.ext4 /dev/mapper/cryptroot &>/dev/null; then
    critical_error "Failed to format root filesystem"
fi

# Mount filesystems
info_print "Mounting filesystems..."
if ! mount /dev/mapper/cryptroot /mnt; then
    critical_error "Failed to mount root filesystem"
fi
if ! mkdir -p /mnt/boot; then
    critical_error "Failed to create boot directory"
fi
if ! mount "$ESP" /mnt/boot; then
    critical_error "Failed to mount boot partition"
fi

# Setup swap
if [[ $swap_size -gt 0 ]]; then
    info_print "Creating ${swap_size}MB swapfile..."
    if dd if=/dev/zero of=/mnt/.swapfile bs=1M count=$swap_size status=progress; then
        chmod 600 /mnt/.swapfile
        if mkswap /mnt/.swapfile && swapon /mnt/.swapfile; then
            info_print "Swapfile created and activated"
        else
            error_print "Failed to setup swapfile, continuing without swap"
        fi
    else
        error_print "Failed to create swapfile, continuing without swap"
    fi
fi

# Detect microcode
microcode_detector

# Install base system
info_print "Installing base system (this may take several minutes)..."
base_packages=(
    "base"
    "$kernel"
    "${kernel}-headers"
    "$microcode"
    "linux-firmware"
    "grub"
    "efibootmgr"
    "sudo"
    "vim"
    "git"
    "wget"
    "curl"
    "base-devel"
    "openssh"
    "man-db"
    "man-pages"
    "bash-completion"
)

if ! pacstrap -K /mnt "${base_packages[@]}"; then
    critical_error "Failed to install base system"
fi

# Generate fstab
info_print "Generating fstab..."
if ! genfstab -U /mnt >> /mnt/etc/fstab; then
    critical_error "Failed to generate fstab"
fi

# Configure tmpfs
echo "tmpfs /tmp tmpfs rw,nodev,nosuid,size=2G,mode=1777 0 0" >> /mnt/etc/fstab

# System configuration
info_print "Configuring system..."

# Hostname
echo "$hostname" > /mnt/etc/hostname

# Hosts file
cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Locale configuration
sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen
echo "LANG=$locale" > /mnt/etc/locale.conf
echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf

# Network configuration
if ! network_installer; then
    critical_error "Failed to configure networking"
fi

# mkinitcpio configuration
cat > /mnt/etc/mkinitcpio.conf << 'EOF'
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
EOF

# GRUB configuration for LUKS
UUID=$(blkid -s UUID -o value "$CRYPTROOT")
if [[ -z "$UUID" ]]; then
    critical_error "Failed to get LUKS UUID"
fi
sed -i "s/^GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$UUID:cryptroot\"/" /mnt/etc/default/grub

# Chroot configuration
info_print "Finalizing system configuration..."
arch-chroot /mnt /bin/bash << EOF
# Setup timezone
$(declare -f setup_timezone)
setup_timezone

# System clock
hwclock --systohc

# Generate locales
locale-gen

# Build initramfs
mkinitcpio -P

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHLINUX
grub-mkconfig -o /boot/grub/grub.cfg

# Enable essential services
systemctl enable sshd
systemctl enable systemd-timesyncd
EOF

# Set passwords
info_print "Setting passwords..."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    arch-chroot /mnt useradd -m -G wheel,audio,video,optical,storage -s /bin/bash "$username"
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
    
    # Create flag file for post-install script
    echo "$username" > /mnt/home/.install_user
fi

# Virtualization tools
if ! virt_check; then
    error_print "Virtualization setup failed, continuing anyway"
fi

# Pacman configuration
info_print "Configuring pacman..."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 5/' /mnt/etc/pacman.conf
echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /mnt/etc/pacman.conf

# Cleanup
info_print "Cleaning up..."
sync
swapoff /mnt/.swapfile 2>/dev/null || true

info_print "=== BASE INSTALLATION COMPLETE ==="
info_print "Base Arch Linux system has been successfully installed!"
info_print ""
info_print "Next steps:"
info_print "1. Reboot into your new system"
info_print "2. Run the post-install script for GUI and applications"
info_print "3. Remove installation media before rebooting"
info_print ""
input_print "Press Enter to finish..."
read -r

exit 0
