#!/bin/bash
# Arch Linux desktop post-install script
source /usr/lib/howhow/common.sh
_require_root "$@"

# Mirrors and system upgrade
_notif_sep "Updating mirrors and upgrading system..."
_notif "Fetching latest Arch mirrors and syncing package databases..."

reflector --score 25 --latest 25 --threads 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
-Syu --noconfirm

# AUR package manager
pacman -S --noconfirm aurinstall
aurinstall paru-bin
pacman -R --noconfirm aurinstall

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

    usermod -aG realtime "$USERNAME" # Realtime Permissions
    usermod -aG audio "$USERNAME" # MIDI Permissions
fi

# Use Encrypted DNS
_notif_sep "Enabling EDNS..."
cat <<EOF > "/etc/systemd/resolved.conf" # Configure DNS-over-TLS
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=8.8.8.8#dns.google
DNSOverTLS=yes
Cache=yes
EOF
systemctl enable --now systemd-resolved

# Firewall
_notif_sep "Installing Firewall (ufw)..."
pacman -S --noconfirm ufw
ufw enable
systemctl enable ufw

# Battery
if _silently ls /sys/class/power_supply/BAT*; then
    _notif_sep "Battery detected installing power saving..."
    pacman -S --noconfirm tlp
    systemctl enable tlp
fi

# SSD
_notif_sep "SSD..."
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
_notif_sep "Installing terminal tools (bash-completion pacman-contrib fastfetch tmux)..."
pacman -S --noconfirm bash-completion pacman-contrib fastfetch tmux
grep -qxF "fastfetch" /etc/bash.bashrc || echo "fastfetch" >> /etc/bash.bashrc

# Sensors
_notif_sep "Installing sensors (lm_sensors acpi acpid)..." 
pacman -S --noconfirm lm_sensors acpi acpid 
systemctl enable acpid
_notif "Detecting sensors..."
sensors-detect --auto

# Networking
_notif_sep "Installing network monitor (vnstat)..."
pacman -S --noconfirm vnstat
systemctl enable vnstat

# IME
_notif_sep "IME..."
_notif "Installing fcitx5..."
pacman -S --noconfirm fcitx5-im fcitx5-configtool fcitx5-gtk fcitx5-qt

cat <<EOF >> /etc/environment

# Virtual Keyboard / IME / fcitx 5
INPUT_METHOD=fcitx
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=fcitx

EOF
_notif "Fcitx 5 IME environment variables set."

# Fonts
_notif "Installing fonts"
pacman -S --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji

# SSH
_notif_sep "SSH..."
_notif "Installing OpenSSH..."
pacman -S --noconfirm openssh fail2ban

# Harden
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i '/^\[sshd\]$/a enabled = true' /etc/fail2ban/jail.local

sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Update firewall
_notif "SSH host is disabled and disallowed in UFW by default. 
This can be manually amended by running 'systemctl enable --now sshd && ufw allow 22/tcp && ufw reload' as superuser.
A custom port instead of the default 22 is recommended. This can be done by modifying the port in /etc/ssh/sshd_config"

systemctl enable --now fail2ban
ufw reload

# Plasma cleanup
if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || _silently pgrep -x plasmashell; then
    echo "Plasma detected: Running cleanup..."

    # Flatpak + Flathub
    _notif_sep "Installing Flatpak + enabling Flathub..."
    pacman -S --noconfirm flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Define apps
    pacman_apps=(firefox)
    flatpak_apps=(
        com.github.tchx84.Flatseal
        it.mijorus.gearlever
        io.github.andreibachim.shortcut
        org.libreoffice.LibreOffice
        # org.qbittorrent.qBittorrent
    )

    # Install pacman apps
    _notif_sep "Installing pacman apps..."
    pacman -S --noconfirm "${pacman_apps[@]}"

    # Install flatpak apps
    _notif_sep "Installing flatpak apps..."
    flatpak install -y flathub "${flatpak_apps[@]}"
fi

# Cleanup then done
_bell
pacman -R archpostinstall

_notif "Arch Linux post install setup complete!" o
timeleft=3
while [ $timeleft -gt 0 ]; do
    echo "Rebooting in $timeleft..."; _bell; sleep 1
    ((timeleft--)) # decrement the counter
done
reboot