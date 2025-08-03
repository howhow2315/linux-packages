#!/bin/bash
# Requires: bash, git, base-devel, pacman-contrib
set -euo pipefail

GIT_REPO="linux-packages"
REPO_NAME="howhow"

# Are we in the right repo?
if [[ "$(basename "$PWD")" != "$GIT_REPO" ]]; then
    echo "Please cd into the repo to publish. (expected: $GIT_REPO)"
    exit 1
fi

# Ensure docs
rm -rf docs
mkdir -p docs

# Build packages
cd arch
for dir in */ ; do
    if [[ ! -f "$dir/PKGBUILD" ]]; then
        echo "[!] Missing PKGBUILD in $dir, skipping..."
        continue
    fi
    cd "$dir"

    # Read current version and release
    current_ver=$(grep '^pkgver=' PKGBUILD | cut -d= -f2)
    current_rel=$(grep '^pkgrel=' PKGBUILD | cut -d= -f2)
    echo "[*] Current version: $current_ver"
    echo "[*] Current release: $current_rel"

    # Optional pkgver prompt
    read -rp "Set new pkgver for $dir? (leave empty to skip): " new_ver
    if [[ -n "$new_ver" ]]; then
        sed -i "s/^pkgver=.*/pkgver=$new_ver/" PKGBUILD
        sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
        echo "[o] Set pkgver to $new_ver and reset pkgrel to 1"
    else
        read -rp "Bump pkgrel for $dir? [y/N]: " bump_rel
        bump_rel="${bump_rel,,}"
        if [[ "$bump_rel" == "y" ]]; then
            old_rel=$(grep '^pkgrel=' PKGBUILD | cut -d= -f2)
            new_rel=$((old_rel + 1))
            sed -i "s/^pkgrel=.*/pkgrel=$new_rel/" PKGBUILD
            echo "[o] Bumped pkgrel to $new_rel"
        fi
    fi

    echo "[*] Updating checksums in $dir..."
    updpkgsums

    echo "[*] Building package in $dir..."
    makepkg -cf
    mv ./*.pkg.tar.zst ../../docs/
    rm -rf pkg src
    cd ..
done

# Create repo
cd ../docs
echo "[*] Creating repo database..."
repo-add "$REPO_NAME.db.tar.gz" *.pkg.tar.zst
cd ..

# Commit and push
echo "[*] Pushing to GitHub..."
git add docs/
git commit -m "Update $REPO_NAME packages"
git push origin main

# Done
echo "[o] Published linux-packages/arch successfully!"