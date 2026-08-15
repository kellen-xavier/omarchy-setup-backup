#!/usr/bin/env bash
# Run this ON THE NEW MACHINE to restore packages + dotfiles from this backup.
#
# Assumes Omarchy is already installed (https://omarchy.org) — this script only
# layers your personal extras and config tweaks on top of a fresh Omarchy install.
#
# Uso: ./install.sh [-y|--yes] [-h|--help]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

ASSUME_YES=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Restaura pacotes extras, apps flatpak, webapps do Omarchy e dotfiles deste
backup na máquina atual. Espera uma instalação Omarchy já existente.

Opções:
  -y, --yes    Não pergunta confirmação antes de cada etapa
  -h, --help   Mostra esta ajuda
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) ASSUME_YES=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $1 (use --help)" >&2
      exit 1
      ;;
  esac
  shift
done

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply
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
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' packages/pacman-extra.txt packages/aur-extra.txt 2>/dev/null | cut -d: -f2-)
    if [ "${#pkgs[@]}" -gt 0 ]; then
      yay -S --needed "${pkgs[@]}"
    fi
  fi
fi

if [ -s packages/flatpak.txt ] && command -v flatpak >/dev/null; then
  if confirm "Install flatpak apps listed in packages/flatpak.txt?"; then
    while read -r app; do
      if [ -n "$app" ]; then
        flatpak install -y flathub "$app" || true
      fi
    done <packages/flatpak.txt
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
    done <webapps/webapps.txt
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
