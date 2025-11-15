# aurinstall

Minimal AUR installer with multi-package support for Arch Linux.

## Features

- Installs one or multiple AUR packages
- Supports `--noconfirm` for unattended installs
- Supports `-r|--reinstall` to force reinstall packages
- Avoids running as root, drops privileges to user automatically
- Skips already installed packages unless reinstall is requested

## Usage

```sh
aurinstall [--noconfirm] [-r|--reinstall] package1 package2 ...
```

## Notes

> Designed for Arch Linux systems.
> Avoid running as root; the script will switch to the regular user automatically.