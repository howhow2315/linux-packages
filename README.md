## linux-packages

Arch Linux package repo containing utility scripts. The goal is to make 'easy to use' commands for my friends, and save time for myself.

> [!NOTE]
> Originally this was supposed to be an Arch/Ubuntu Linux package repo.  
> However its moved to a fully Arch one as I've lost reason to build for Ubuntu.

### Add the custom pacman repo [howhow]
```sh
grep -i "howhow" /etc/pacman.conf &>/dev/null || _silently sudo tee -a /etc/pacman.conf <<'EOF'

[howhow]
SigLevel = Optional TrustAll
Server = https://howhow2315.github.io/linux-packages
EOF
```

---
### System/Package
#### [aurinstall](https://github.com/howhow2315/linux-packages/tree/main/arch/aurinstall)
#### [mac-spoof](https://github.com/howhow2315/linux-packages/tree/main/arch/mac-spoof)
#### [pacstall](https://github.com/howhow2315/linux-packages/tree/main/arch/pacstall) (Deprecated)
#### [sysm](https://github.com/howhow2315/linux-packages/tree/main/arch/sysm)

### Networking
#### [fixsshperms](https://github.com/howhow2315/linux-packages/tree/main/arch/fixsshperms)
#### [tunnel](https://github.com/howhow2315/linux-packages/tree/main/arch/tunnel)
#### [ufw-ipset](https://github.com/howhow2315/linux-packages/tree/main/arch/ufw-ipset)

### Wireguard
#### [wg-peer](https://github.com/howhow2315/linux-packages/tree/main/arch/wg-peer)
#### [wg-toggle](https://github.com/howhow2315/linux-packages/tree/main/arch/wg-toggle)

### Misc.
#### [cldl](https://github.com/howhow2315/linux-packages/tree/main/arch/cldl)

----

### Libs
#### [howhow-common](https://github.com/howhow2315/linux-packages/tree/main/arch/howhow-common)

----

This repository is fully licensed under the MIT License (see `LICENSE`).
