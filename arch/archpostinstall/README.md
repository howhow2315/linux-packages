# archpostinstall

Automates common post-install setup tasks for an Arch Linux desktop.

## Features

- Updates mirrors and upgrades system
- Installs AUR helper (`paru-bin`)
- Configures hostname and `/etc/hosts`
- Sets up realtime audio permissions
- Enables encrypted DNS (DNS-over-TLS)
- Installs and configures firewall (`ufw`)
- Installs battery and SSD optimizations (TLP, fstrim)
- Installs terminal tools (bash-completion, tmux, fastfetch)
- Detects hardware sensors and enables monitoring
- Installs networking tools (vnStat)
- Sets up IME with `fcitx5`
- Installs fonts and SSH hardening (OpenSSH + fail2ban)

// KDE Plasma only
- Installs Flatpak and selected applications for KDE Plasma

## Usage

```sh
archpostinstall
```

> Requires root privileges.

## Notes

> * Designed for Arch Linux desktop environments.  
> * Automatically reboots after completion.