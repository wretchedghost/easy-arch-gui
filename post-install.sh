#!/usr/bin/env bash

# Enhanced Arch Linux Post-Installation Script
# Installs GUI, applications, and user configurations

set -euo pipefail

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

warning_print() {
    echo -e "${BOLD}${BYELLOW}[ ${BRED}!${BYELLOW} ] $1${RESET}"
}

# Error handling
handle_error() {
    local exit_code=$?
    error_print "Script failed at line $1 with exit code $exit_code"
    error_print "Check the error above for details"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_print "This script should not be run as root!"
        error_print "Run as your regular user account with sudo privileges."
        exit 1
    fi
}

# Check if user has sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        error_print "This script requires sudo privileges."
        error_print "Please ensure your user is in the wheel group."
        exit 1
    fi
}

# Install AUR helper (yay)
install_yay() {
    if command -v yay &> /dev/null; then
        info_print "yay is already installed"
        return 0
    fi
    
    info_print "Installing yay AUR helper..."
    local tmp_dir="/tmp/yay-install"
    
    # Clean up any existing directory
    rm -rf "$tmp_dir"
    
    # Clone and build yay
    git clone https://aur.archlinux.org/yay.git "$tmp_dir"
    cd "$tmp_dir"
    makepkg -si --noconfirm
    cd - > /dev/null
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    if command -v yay &> /dev/null; then
        info_print "yay installed successfully"
    else
        error_print "Failed to install yay"
        return 1
    fi
}

# Install packages from official repositories
install_official_packages() {
    info_print "Updating system and installing official packages..."
    
    # Update system first
    sudo pacman -Syu --noconfirm
    
    # Core system packages
    local core_packages=(
        # Display server and drivers
        "xorg-server"
        "xorg-xinit"
        "xorg-xrandr"
        "xorg-xset"
        "xorg-xkill"
        
        # Graphics drivers (install common ones, user can remove unneeded)
        "mesa"
        "xf86-video-intel"
        "xf86-video-amdgpu"
        "xf86-video-nouveau"
        
        # Audio
        "pipewire"
        "pipewire-pulse"
        "pipewire-alsa"
        "pipewire-jack"
        "wireplumber"
        "pavucontrol"
        "volumeicon"
        
        # Window manager and desktop tools
        "i3-wm"
        "i3blocks"
        "i3lock"
        "rofi"
        "dunst"
        "picom"
        "lxappearance"
        "feh"
        "scrot"
        "conky"
        "xautolock"
        
        # Display manager
        "lightdm"
        "lightdm-gtk-greeter"
        
        # File management
        "thunar"
        "thunar-archive-plugin"
        "thunar-volman"
        "gvfs"
        "gvfs-smb"
        "gvfs-mtp"
        "gvfs-nfs"
        "ranger"
        
        # Terminal and shell tools
        "tmux"
        "htop"
        "neofetch"
        "tree"
        "unzip"
        "zip"
        "rsync"
        
        # Network tools
        "wget"
        "curl"
        "openssh"
        "cifs-utils"
        "nfs-utils"
        "sshfs"
        
        # Development tools
        "code"
        "firefox"
        "git"
        "base-devel"
        
        # Media and graphics
        "imagemagick"
        "ffmpeg"
        "vlc"
        "gimp"
        
        # Fonts
        "ttf-dejavu"
        "ttf-liberation"
        "ttf-font-awesome"
        "noto-fonts"
        "noto-fonts-emoji"
        
        # Utilities
        "galculator"
        "xfce4-clipman-plugin"
        "redshift"
        "barrier"
        "android-tools"
        "ntfs-3g"
    )
    
    # Install packages in batches to handle potential failures
    for package in "${core_packages[@]}"; do
        if ! sudo pacman -S --noconfirm --needed "$package" 2>/dev/null; then
            warning_print "Failed to install $package, continuing..."
        fi
    done
    
    info_print "Official packages installation completed"
}

# Install AUR packages
install_aur_packages() {
    if ! command -v yay &> /dev/null; then
        error_print "yay not found, cannot install AUR packages"
        return 1
    fi
    
    info_print "Installing AUR packages..."
    
    local aur_packages=(
        # Themes and icons
        "vimix-gtk-themes"
        "vimix-icon-theme"
        "vimix-cursors"
        
        # Utilities
        "caffeine-ng"
        "downgrade"
        "timeshift"
        "visual-studio-code-bin"
        
        # Additional tools
        "slack-desktop"
        "discord"
        "spotify"
    )
    
    # Install AUR packages one by one to handle failures gracefully
    for package in "${aur_packages[@]}"; do
        if ! yay -S --noconfirm --needed "$package" 2>/dev/null; then
            warning_print "Failed to install AUR package $package, continuing..."
        fi
    done
    
    info_print "AUR packages installation completed"
}

# Configure laptop-specific packages
configure_laptop() {
    input_print "Is this a laptop installation? [y/N]: "
    read -r is_laptop
    
    if [[ "${is_laptop,,}" =~ ^(yes|y)$ ]]; then
        info_print "Installing laptop-specific packages..."
        
        local laptop_packages=(
            "brightnessctl"
            "iw"
            "power-profiles-daemon"
            "powertop"
            "acpi"
            "tlp"
            "bluez"
            "bluez-utils"
        )
        
        for package in "${laptop_packages[@]}"; do
            if ! sudo pacman -S --noconfirm --needed "$package" 2>/dev/null; then
                warning_print "Failed to install laptop package $package"
            fi
        done
        
        # Enable laptop services
        sudo systemctl enable tlp.service
        sudo systemctl enable bluetooth.service
        
        info_print "Laptop configuration completed"
    fi
}

# Configure dotfiles
configure_dotfiles() {
    info_print "Configuring dotfiles..."
    
    # Get dotfiles repository URL
    input_print "Enter dotfiles repository URL (leave empty to skip): "
    read -r dotfiles_repo
    
    if [[ -z "$dotfiles_repo" ]]; then
        info_print "Skipping dotfiles configuration"
        return 0
    fi
    
    # Validate URL format
    if [[ ! "$dotfiles_repo" =~ ^(https?|git)://.+ ]] && [[ ! "$dotfiles_repo" =~ ^git@.+ ]]; then
        error_print "Invalid repository URL format"
        return 1
    fi
    
    local dotfiles_dir="$HOME/.dotfiles"
    
    # Clone dotfiles repository
    if [[ -d "$dotfiles_dir" ]]; then
        warning_print "Dotfiles directory already exists, updating..."
        cd "$dotfiles_dir"
        git pull
    else
        info_print "Cloning dotfiles repository..."
        git clone "$dotfiles_repo" "$dotfiles_dir"
        cd "$dotfiles_dir"
    fi
    
    # Check for installation script or deploy manually
    if [[ -f "install.sh" ]]; then
        info_print "Running dotfiles installation script..."
        chmod +x install.sh
        ./install.sh
    elif [[ -f "deploy.sh" ]]; then
        info_print "Running dotfiles deployment script..."
        chmod +x deploy.sh
        ./deploy.sh
    else
        info_print "No installation script found, deploying common files..."
        
        # Create common directories
        mkdir -p "$HOME/.config/"{i3,dunst,rofi,ranger,redshift}
        mkdir -p "$HOME/.local/share"
        
        # Copy common dotfiles if they exist
        local common_files=(
            ".bashrc"
            ".vimrc"
            ".xinitrc"
            ".Xresources"
            ".tmux.conf"
            ".fehbg"
        )
        
        for file in "${common_files[@]}"; do
            if [[ -f "$file" ]]; then
                cp "$file" "$HOME/"
                info_print "Copied $file"
            fi
        done
        
        # Copy config directories
        local config_dirs=(
            "i3"
            "dunst"
            "rofi"
            "ranger"
            "redshift"
            "conky"
        )
        
        for dir in "${config_dirs[@]}"; do
            if [[ -d ".config/$dir" ]]; then
                cp -r ".config/$dir" "$HOME/.config/"
                info_print "Copied .config/$dir"
            fi
        done
        
        # Copy Pictures directory for wallpapers
        if [[ -d "Pictures" ]]; then
            cp -r Pictures "$HOME/"
            info_print "Copied Pictures directory"
        fi
    fi
    
    cd - > /dev/null
    info_print "Dotfiles configuration completed"
}

# Configure services
configure_services() {
    info_print "Configuring system services..."
    
    # Enable display manager
    sudo systemctl enable lightdm.service
    
    # Enable audio
    systemctl --user enable pipewire.service
    systemctl --user enable pipewire-pulse.service
    systemctl --user enable wireplumber.service
    
    # Enable network time synchronization
    sudo systemctl enable systemd-timesyncd.service
    
    # Configure firewall if ufw is available
    if command -v ufw &> /dev/null; then
        sudo ufw enable
        info_print "Firewall enabled"
    fi
    
    info_print "Services configuration completed"
}

# Configure user environment
configure_user_environment() {
    info_print "Configuring user environment..."
    
    # Add user to additional groups
    sudo usermod -a -G audio,video,input,storage "$USER"
    
    # Create user directories
    mkdir -p "$HOME/"{Documents,Downloads,Pictures,Videos,Music}
    mkdir -p "$HOME/.local/"{bin,share}
    
    # Set up .xinitrc if it doesn't exist
    if [[ ! -f "$HOME/.xinitrc" ]]; then
        cat > "$HOME/.xinitrc" << 'EOF'
#!/bin/sh

# Load X resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Set wallpaper
[[ -f ~/.fehbg ]] && ~/.fehbg

# Start compositor
picom -b

# Start notification daemon
dunst &

# Start i3
exec i3
EOF
        chmod +x "$HOME/.xinitrc"
        info_print "Created .xinitrc"
    fi
    
    # Set up basic .bashrc additions if not present
    if ! grep -q "alias ll=" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Custom aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Custom functions
extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
EOF
        info_print "Enhanced .bashrc with aliases and functions"
    fi
    
    info_print "User environment configuration completed"
}

# Configure i3 window manager
configure_i3() {
    info_print "Configuring i3 window manager..."
    
    local i3_config_dir="$HOME/.config/i3"
    mkdir -p "$i3_config_dir"
    
    # Create basic i3 config if it doesn't exist
    if [[ ! -f "$i3_config_dir/config" ]]; then
        cat > "$i3_config_dir/config" << 'EOF'
# i3 config file (v4)
set $mod Mod4

# Font for window titles and bar
font pango:DejaVu Sans Mono 8

# Use Mouse+$mod to drag floating windows
floating_modifier $mod

# Start a terminal
bindsym $mod+Return exec i3-sensible-terminal

# Kill focused window
bindsym $mod+Shift+q kill

# Start rofi (program launcher)
bindsym $mod+d exec rofi -show run

# Change focus
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Move focused window
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# Split in horizontal orientation
bindsym $mod+h split h

# Split in vertical orientation
bindsym $mod+v split v

# Enter fullscreen mode
bindsym $mod+f fullscreen toggle

# Change container layout
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# Toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# Change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# Focus the parent container
bindsym $mod+a focus parent

# Define workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# Switch to workspace
bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5
bindsym $mod+6 workspace $ws6
bindsym $mod+7 workspace $ws7
bindsym $mod+8 workspace $ws8
bindsym $mod+9 workspace $ws9
bindsym $mod+0 workspace $ws10

# Move focused container to workspace
bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5
bindsym $mod+Shift+6 move container to workspace $ws6
bindsym $mod+Shift+7 move container to workspace $ws7
bindsym $mod+Shift+8 move container to workspace $ws8
bindsym $mod+Shift+9 move container to workspace $ws9
bindsym $mod+Shift+0 move container to workspace $ws10

# Reload the configuration file
bindsym $mod+Shift+c reload

# Restart i3 inplace
bindsym $mod+Shift+r restart

# Exit i3
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -b 'Yes, exit i3' 'i3-msg exit'"

# Resize window mode
mode "resize" {
        bindsym j resize shrink width 10 px or 10 ppt
        bindsym k resize grow height 10 px or 10 ppt
        bindsym l resize shrink height 10 px or 10 ppt
        bindsym semicolon resize grow width 10 px or 10 ppt

        bindsym Return mode "default"
        bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"

# Status bar
bar {
        status_command i3blocks
}

# Auto-start applications
exec --no-startup-id picom -b
exec --no-startup-id dunst
exec --no-startup-id feh --bg-scale ~/Pictures/wallpaper.jpg
EOF
        info_print "Created basic i3 configuration"
    fi
    
    info_print "i3 configuration completed"
}

# Final system optimization
optimize_system() {
    info_print "Performing system optimizations..."
    
    # Update font cache
    fc-cache -fv
    
    # Update desktop database
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    
    # Update icon cache
    gtk-update-icon-cache ~/.local/share/icons/ 2>/dev/null || true
    
    # Clean package cache
    sudo pacman -Sc --noconfirm
    
    info_print "System optimization completed"
}

# Main installation function
main() {
    echo -ne "${BOLD}${BYELLOW}
================================================================================
POST-INSTALLATION SETUP
================================================================================
${RESET}"
    
    info_print "Starting Arch Linux post-installation setup..."
    info_print "This script will install a complete desktop environment"
    
    # Perform checks
    check_root
    check_sudo
    
    # Installation phases
    info_print "=== PHASE 1: Package Installation ==="
    install_official_packages
    install_yay
    install_aur_packages
    
    info_print "=== PHASE 2: System Configuration ==="
    configure_laptop
    configure_services
    configure_user_environment
    
    info_print "=== PHASE 3: Desktop Environment ==="
    configure_i3
    configure_dotfiles
    
    info_print "=== PHASE 4: Optimization ==="
    optimize_system
    
    # Final messages
    echo
    info_print "=== POST-INSTALLATION COMPLETE ==="
    info_print "Your Arch Linux system is now ready to use!"
    echo
    info_print "Next steps:"
    info_print "1. Reboot your system"
    info_print "2. Log in through the display manager"
    info_print "3. Customize your desktop environment as needed"
    echo
    info_print "Default login: Use the user account you created during installation"
    info_print "To start GUI: System will auto-start, or run 'startx' manually"
    echo
    warning_print "Don't forget to:"
    warning_print "• Set up your firewall rules if needed"
    warning_print "• Configure your network connections"
    warning_print "• Install additional software as needed"
    echo
    input_print "Press Enter to finish..."
    read -r
}

# Run main function
main "$@"
