#!/bin/bash
[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

# Basic logging functions
log() {
    local msg="$1"
    local sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}

progress() {
    clear
    log "$@"
}

# User input handling
get_input() {
    local var="$1"; shift
    local prompt="$1"; shift

    local LOWER=0 
    local DEFAULT=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--lower) LOWER=1 ;;
            -d|--default) shift; DEFAULT="$1" ;;
            *) echo "Unknown flag: $1" >&2 ;;
        esac
        shift
    done

    [[ -n "$DEFAULT" ]] && prompt="$prompt ($DEFAULT)"
    local input
    read -rp "$prompt: " input

    [[ -n "$DEFAULT" && -z "$input" ]] && input="$DEFAULT" # default
    [[ $LOWER -eq 1 ]] && input="${input,,}" # lowercase

    export "$var"="$input"
}

# pacman -S shorthand
pacstall() {
    pacman -S --noconfirm --needed "$@"
}

# Mirrors and system upgrade
progress "Updating mirrors and upgrading system..."
log "Fetching latest Arch mirrors and syncing package databases..."

reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
pacman -Syu --noconfirm

# AUR package manager
pacstall aur-install
aur-install yay
pacman -R --noconfirm aur-install

# Add host to hosts
HOSTNAME=$(cat /etc/hostname)
grep -q "$HOSTNAME" /etc/hosts || echo "127.0.1.1    $HOSTNAME.localdomain    $HOSTNAME" >> /etc/hosts

# Realtime Audio
USERNAME=${SUDO_USER:-$USER}
if [[ -n "$USERNAME" ]]; then
    groupadd -f realtime
    
    mkdir -p /etc/security/limits.d
    [[ ! -f /etc/security/limits.d/99-realtime.conf ]] && cat <<EOF > /etc/security/limits.d/99-realtime.conf
@realtime   -   rtprio     95
@realtime   -   memlock    unlimited
EOF

    usermod -aG realtime "$USERNAME"
fi

# Use Encrypted DNS
progress "Enabling EDNS..."
cat <<EOF > "/etc/systemd/resolved.conf" # Configure DNS-over-TLS
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8#dns.google
DNSOverTLS=yes
Cache=yes
EOF
systemctl enable --now systemd-resolved

# Firewall
progress "Installing Firewall (ufw)..."
pacstall ufw
ufw enable
systemctl enable ufw

# Battery
if ls /sys/class/power_supply/BAT* &>/dev/null; then
    progress "Battery detected installing power saving..."
    pacstall tlp
    systemctl enable tlp
fi

# SSD
progress "SSD..."
ROOT_DEV=$(findmnt -no SOURCE /) # Get the device backing the root filesystem, e.g., /dev/mapper/cryptroot or /dev/sda2

# Strip partition number to get the block device
if [[ $ROOT_DEV =~ ^/dev/mapper/ ]]; then
    # LVM or LUKS: get underlying physical device
    ROOT_BLK=$(lsblk -no PKNAME "$ROOT_DEV")   # e.g., sda
    ROOT_BLK="/dev/$ROOT_BLK"
else
    # Regular partition: remove trailing number
    ROOT_BLK=$(lsblk -no PKNAME "$ROOT_DEV")   # e.g., sda
    ROOT_BLK="/dev/$ROOT_BLK"
fi

# Check rotational flag: 0 = SSD, 1 = HDD
ROTATIONAL=$(cat /sys/block/$(basename "$ROOT_BLK")/queue/rotational)
if [[ $ROTATIONAL -eq 0 ]]; then
    echo "SSD detected: enabling fstrim.timer"
    systemctl enable --now fstrim.timer
fi

# Terminal tools
progress "Installing terminal tools (bash-completion pacman-contrib fastfetch tmux)..."
pacstall bash-completion pacman-contrib fastfetch tmux
grep -qxF "fastfetch" /etc/bash.bashrc || echo "fastfetch" >> /etc/bash.bashrc

# Sensors
progress "Installing sensors (lm_sensors acpi acpid)..." 
pacstall lm_sensors acpi acpid 
systemctl enable acpid
log "Detecting sensors..."
sensors-detect --auto

# Networking
progress "Installing network monitor (vnstat)..."
pacstall vnstat
systemctl enable vnstat

# IME
progress "IME..."
get_input installIME "Do you want to install an IME" -d Y 
if [[ "$installIME" == "y" ]]; then
    log "Installing fcitx5..."

    pacstall fcitx5-im fcitx5-configtool fcitx5-gtk fcitx5-qt

    # Not required for Wayland, but doesn't hurt. Especially if the user will switch between Wayland and X11.
    cat <<EOF >> /etc/environment

GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
    log "Fcitx 5 IME environment variables set."
fi

# Fonts
log "Installing fonts"
pacstall noto-fonts noto-fonts-cjk noto-fonts-emoji

# SSH
progress "SSH..."
get_input installSSH "Do you want to install SSH" -d N
if [[ "$installSSH" == "y" ]]; then
    log "Installing OpenSSH..."
    log "SSH host is disabled and disallowed in UFW by default. 
    This can be manually amended by running 'systemctl enable --now sshd && ufw allow ssh && ufw reload' as superuser."
    pacstall openssh fail2ban

    # Harden
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i '/^\[sshd\]$/a enabled = true' /etc/fail2ban/jail.local

    sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

    # Prompt for custom port
    get_input sshPort "Enter SSH port to use" -d 22
    sed -i "s/^#Port 22/Port $sshPort/" /etc/ssh/sshd_config

    # Update firewall
    ufw allow "$sshPort"/tcp

    systemctl enable --now fail2ban
    # systemctl enable --now sshd
    ufw reload
fi

pacman -R --noconfirm archpostinstall

log "Arch Linux post install setup complete!" o
sleep 1; echo "."; sleep 1; echo ".."; sleep 1; echo "..."
exit 0