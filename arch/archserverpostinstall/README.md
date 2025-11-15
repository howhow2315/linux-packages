# archserverpostinstall

Automates common post-install setup tasks for an Arch Linux server.

## Features

- Updates mirrors and upgrades system
- Installs AUR helper (`paru-bin`)
- Installs battery and SSD optimizations (TLP, fstrim)
- Installs terminal tools (fastfetch, tmux)
- Detects hardware sensors and enables monitoring
- Disables lid switch suspend
- Installs networking tools (vnStat, wget)
- Enables encrypted DNS (DNS-over-TLS)
- Installs and configures firewall (`ufw`) with optional Docker support
- SSH hardening (fail2ban + sshd config)

## Usage

```sh
archserverpostinstall
```

> Requires root privileges.

## Notes

> * Designed for Arch Linux server environments.
> * Automatically reboots after completion.