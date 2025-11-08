#!/bin/bash
# Arch Linux server post-install script
source /usr/lib/howhow/common.sh
_require_root "$@"

# Mirrors and system upgrade
_notif_sep "Updating mirrors and upgrading system..."
_notif "Fetching latest Arch mirrors and syncing package databases..."

reflector --latest 20 --threads 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
pacman -Syu

# Battery
if ls /sys/class/power_supply/BAT* &>/dev/null; then
    _notif_sep "Battery detected installing power saving..."
    pacstall tlp
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
_notif_sep "Installing terminal tools (\fastfetch tmux)..."
pacstall fastfetch tmux
grep -qxF "fastfetch" /etc/bash.bashrc || echo "fastfetch" >> /etc/bash.bashrc

# Sensors
_notif_sep "Installing sensors (lm_sensors acpi acpid)..." 
pacstall lm_sensors acpi acpid 
systemctl enable acpid
_notif "Detecting sensors..."
sensors-detect --auto

# Disable Lid Switch Suspend
sudo sed -i \
  -e 's/^#HandleLidSwitch=.*/HandleLidSwitch=ignore/' \
  -e 's/^#HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' \
  -e 's/^#HandleLidSwitchDocked=.*/HandleLidSwitchDocked=ignore/' \
  /etc/systemd/_notifind.conf

# Networking
_notif_sep "Networking..."
_notif "Installing network monitor (vnstat)..."
pacstall vnstat
systemctl enable vnstat

_notif "Installing networking tools (wget)..."
pacstall wget

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
pacstall ufw

# ufw-docker support
if systemctl is-active --quiet docker; then
    docker network create proxy

    wget -O /usr/bin/ufw-docker https://github.com/chaifeng/ufw-docker/raw/master/ufw-docker
    ufw-docker install
fi

ufw --force enable
systemctl enable --now ufw

# fail2ban
pacstall fail2ban
cp -n /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i '/^\[sshd\]$/a enabled = true' /etc/fail2ban/jail.local
systemctl enable --now fail2ban

# Check if sshd service is active
if systemctl is-active --quiet sshd; then
    _notif "sshd is running, configuring..."

    # Write hardened sshd config fragment
    tee /etc/ssh/sshd_config.d/sshd_harden.conf > /dev/null <<EOF
# Change the port to 2222
Port 2222

# Disable incoming ssh root logins
PermitRootLogin no

# Disable password-based logins, forcing keys only
# Comment out if you still need password login temporarily
#PasswordAuthentication no
EOF

    # Reload sshd to apply new config
    systemctl reload sshd

    # Allow SSH on port 2222 only from LAN
    ufw allow from 192.168.0.0/16 to any port 2222 proto tcp
    ufw reload
fi

# Cleanup then done
pacstall -R archserverpostinstall

# clear && fastfetch
_notif "Arch Linux server post install setup complete!" o