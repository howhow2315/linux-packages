# sysm

Arch Linux system maintenance script for updating packages, mirrors, and cleaning caches.

## Features

- Updates mirrors using `reflector` (if installed), only if older than 24 hours.
- Updates system packages via `paru` (preferred), or `pacman` fallback.
- Updates Flatpak applications (if installed).
- Cleans package cache using `paccache`.
- Provides informative notifications with elapsed times and status.

## Usage

```sh
sysm
````

> Requires root privileges for package updates and cache cleanup.

### Notes

* If `paru` is installed, it will be used for system updates. Otherwise, `pacman` is used.
* Flatpak updates are optional and only applied if Flatpak is installed.
* The script automatically runs `reflector` only if the mirrorlist is older than 24 hours.
* Cleans old package caches while keeping the 2 most recent versions.

> Designed for Arch Linux desktop or server environments.