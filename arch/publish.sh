#!/bin/bash
set -e

REPO_NAME="linux-packages"
REPO_DB_NAME="howhow"

BUILD_DIR="/tmp/pkgrepo"
mkdir -p "$BUILD_DIR"
rm -rf "$BUILD_DIR"/*

echo "[*] Copying built packages..."
cp arch/*/*.pkg.tar.zst "$BUILD_DIR/"
cd "$BUILD_DIR"

echo "[*] Building repo database..."
repo-add "$REPO_DB_NAME.db.tar.gz" *.pkg.tar.zst
mv "$REPO_DB_NAME.db.tar.gz" "$REPO_DB_NAME.db"
mv "$REPO_DB_NAME.files.tar.gz" "$REPO_DB_NAME.files"

echo "[*] Publishing to gh-pages branch..."
cd "$(git rev-parse --show-toplevel)"
git checkout gh-pages
rm -rf *
cp "$BUILD_DIR"/* .
git add .
git commit -m "Update repo on $(date)"
git push origin gh-pages
git checkout main