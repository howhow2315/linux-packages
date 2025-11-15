# howhow-common

A collection of common shell functions for scripting convenience. Designed to be **sourced** in other scripts.

## Features

- **Notification helpers**  
  - `_notif` – Print a message with a symbol prefix  
  - `_notif_sep` – Print a blank line, then a message  
  - `_notif_clear` – Clear terminal, then print a message  
  - `_bell` – Ring the terminal bell

- **Usage and error handling**  
  - `_usage` – Print usage message and optionally run help commands  
  - `_err` – Display an error message and exit  

- **Command helpers**  
  - `_silently` – Run a command suppressing stdout/stderr  
  - `_hascmd` – Check if a command exists in PATH  
  - `_contains_arg` – Check if an argument exists in a list  

- **Privilege and user management**  
  - `_is_root` – Check if script is running as root  
  - `_is_terminal` – True if stdin and stdout are terminals  
  - `_get_user` – Return original user who invoked the script  
  - `_require_root` – Ensure script runs as root (auto sudo)  
  - `_drop_privileges` – Re-run script as original user  
  - `_run_as_root` – Run a command as root, using sudo if necessary

## Usage

```sh
source /usr/lib/howhow/common.sh

# Example: require root
_require_root "$@"

# Example: notify
_notif "Hello world!"

# Example: drop privileges to user
_drop_privileges
```

## Notes

> Intended to be **sourced**, not executed directly.
> Provides standardized logging, privilege handling, and utility functions for other scripts.
