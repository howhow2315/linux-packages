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
    cd "$dir"

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