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

# We only want to be clearing out the packages we want to update
mkdir -p docs

# Remove old repo database only (not all packages)
echo "[*] Cleaning old repo database..."
rm -f "docs/$REPO_NAME".db* "docs/$REPO_NAME".files*

# Build packages
cd arch
for pkg in *; do
    dir="$pkg/"
    # Check for the PKGBUILD file
    if [[ ! -f "$dir/PKGBUILD" ]]; then
        echo "[!] Missing PKGBUILD in $dir, skipping..."
        continue
    fi

    # Check if the package exists 
    PACKAGE_EXISTS=false
    if [[ -n "$(ls "../docs/$pkg"*.pkg.tar.zst 2>/dev/null)" ]]; then
        PACKAGE_EXISTS=true
    fi
    
    # Check if the directory has uncommitted or committed changes
    if $PACKAGE_EXISTS && git diff --quiet HEAD -- "$pkg" && [[ "$1" != "--force" ]]; then
        echo "[*] No changes detected in $pkg, skipping..."
        continue
    fi

    cd "$dir"

    if $PACKAGE_EXISTS; then
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
            read -rp "Bump pkgrel for $dir? [y/N]: " bumpRel
            bumpRel="${bumpRel,,}"
            if [[ "$bumpRel" == [yY] ]]; then
                old_rel=$(grep '^pkgrel=' PKGBUILD | cut -d= -f2)
                new_rel=$((old_rel + 1))
                sed -i "s/^pkgrel=.*/pkgrel=$new_rel/" PKGBUILD
                echo "[o] Bumped pkgrel to $new_rel"
            fi
        fi
    fi

    echo "[*] Updating checksums in $dir..."
    updpkgsums

    echo "[*] Building package in $dir..."
    makepkg -cf

    # Remove old copy of the package if it exists & move the new package
    rm -f ../../docs/"$pkg"*.pkg.tar.zst
    mv ./"$pkg"*.pkg.tar.zst ../../docs/

    # Cleanup work files & continue
    rm -rf pkg src
    cd ..
done

# Create repo
cd ../docs
echo "[*] Creating repo database..."
repo-add "$REPO_NAME.db.tar.gz" *.pkg.tar.zst
cd ..

# Commit and push
echo "[*] Comitting to GitHub..."
if git diff --quiet docs/ && git diff --cached --quiet docs/; then
    echo "[*] No changes to commit."
else
    git add docs/
    git commit -m "Update $REPO_NAME packages on $(date +'%Y-%m-%d %H:%M:%S')"
    
    read -rp "Push to Git? (Y/n)" pushGit
    if [[ "$pushGit" == [yY] ]]; then
        git push origin main
    fi
fi