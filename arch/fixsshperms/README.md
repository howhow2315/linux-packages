# fixsshperms

Quickly fixes `.ssh` directory and file permissions for a user.

## Features

- Sets `~/.ssh` directory to `700`
- Sets private keys (`id_*`) to `600`
- Sets public keys (`*.pub`) to `644`
- Sets `authorized_keys` to `600`
- Sets `config`, `known_hosts`, and `known_hosts.old` to `644`
- Automatically detects the correct `.ssh` directory for the current or sudo user

## Usage

```sh
fixsshperms.sh
```

## Notes

> Requires root privileges to modify permissions.
> Ensures SSH files have correct permissions for secure access.
