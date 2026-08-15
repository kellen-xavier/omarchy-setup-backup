#!/usr/bin/env bash
# Run this ON THE NEW MACHINE to restore packages + dotfiles from this backup.
#
# Assumes Omarchy is already installed (https://omarchy.org) — this script only
# layers your personal extras and config tweaks on top of a fresh Omarchy install.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

confirm() {
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

echo "== Omarchy personal setup restore =="

if ! command -v yay >/dev/null; then
  echo "yay (AUR helper) not found. This script expects an Omarchy base install." >&2
  exit 1
fi

# --- Packages -----------------------------------------------------------
if [ -s packages/pacman-extra.txt ] || [ -s packages/aur-extra.txt ]; then
  if confirm "Install extra pacman + AUR packages listed in packages/?"; then
    pkgs=$(grep -vE '^\s*(#|$)' packages/pacman-extra.txt packages/aur-extra.txt 2>/dev/null | cut -d: -f2- | tr '\n' ' ')
    if [ -n "$pkgs" ]; then
      yay -S --needed $pkgs
    fi
  fi
fi

if [ -s packages/flatpak.txt ] && command -v flatpak >/dev/null; then
  if confirm "Install flatpak apps listed in packages/flatpak.txt?"; then
    while read -r app; do
      [ -n "$app" ] && flatpak install -y flathub "$app" || true
    done < packages/flatpak.txt
  fi
fi

if [ -f packages/manual-notes.txt ]; then
  echo
  echo "== Manual-install apps (see packages/manual-notes.txt) =="
  cat packages/manual-notes.txt
  echo
fi

# --- Webapps --------------------------------------------------------------
if [ -s webapps/webapps.txt ] && command -v omarchy-webapp-install >/dev/null; then
  if confirm "Recreate Omarchy webapps (ChatGPT, Discord, Figma, etc.)?"; then
    while IFS='|' read -r name url; do
      [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
      echo "-> $name ($url)"
      omarchy-webapp-install "$name" "$url" || echo "   failed, skipping"
    done < webapps/webapps.txt
  fi
fi

# --- Dotfiles ---------------------------------------------------------
if confirm "Restore dotfiles into \$HOME (existing files get a .pre-restore backup)?"; then
  find dotfiles -type f | while read -r f; do
    rel="${f#dotfiles/}"
    target="$HOME/$rel"
    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] && ! cmp -s "$f" "$target"; then
      cp "$target" "$target.pre-restore.bak"
    fi
    cp "$f" "$target"
    echo "restored $rel"
  done
fi

echo
echo "Done. Reload Hyprland (or reboot) to pick up hypr/waybar changes:"
echo "  hyprctl reload"
