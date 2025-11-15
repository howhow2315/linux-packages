# pacstall

A lightweight wrapper around `pacman` for shorthand usage and script automation.

> [!WARNING]
> Deprecated: Please just use `paru` instead. They did a fantastic job on it!

## Features

- Simplifies `pacman` commands for installation and management.
- Defaults to `-S` (install/sync) if no operation is specified.
- Automatically adds `--noconfirm` in non-interactive environments.
- Fully compatible with all `pacman` operations.

## Usage

```bash
pacstall [operation] [options] [package(s)]
```

### Examples

```bash
# Install a package (default operation)
pacstall vim

# Update system
pacstall -Syu

# Remove a package
pacstall -Rns package_name
```

### Notes

* The script detects if it's running in a non-interactive shell and adds `--noconfirm` automatically.
* If no operation is provided, it defaults to `-S` for installation.
* Supports any valid `pacman` operation since it wraps `pacman` entirely.
* Requires root privileges for all operations.