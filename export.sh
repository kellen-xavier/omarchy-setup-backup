#!/usr/bin/env bash
# Run this ON THE SOURCE MACHINE (the real Omarchy machine, in a normal
# terminal — not inside a sandboxed/agent session) to regenerate an
# authoritative snapshot of packages, flatpaks and dotfiles into this folder.
#
# It replaces the best-effort files under packages/ with the real thing,
# and refreshes dotfiles/ with the current state of your configs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

OMARCHY_SHARE="$HOME/.local/share/omarchy"
if [ ! -d "$OMARCHY_SHARE" ]; then
  echo "This doesn't look like an Omarchy machine ($OMARCHY_SHARE not found)." >&2
  echo "export.sh still works, but the pacman diff against Omarchy's base list will be skipped." >&2
fi

echo "==> Exporting explicitly installed pacman packages..."
pacman -Qqe > packages/pacman-all.txt

echo "==> Exporting foreign (AUR) packages..."
pacman -Qqm > packages/aur-extra.txt

echo "==> Exporting flatpak apps..."
if command -v flatpak >/dev/null; then
  flatpak list --app --columns=application > packages/flatpak.txt
else
  : > packages/flatpak.txt
fi

echo "==> Computing pacman-extra.txt (everything not in Omarchy's own base/other lists)..."
if [ -d "$OMARCHY_SHARE/install" ]; then
  grep -vE '^\s*(#|$)' "$OMARCHY_SHARE/install/omarchy-base.packages" "$OMARCHY_SHARE/install/omarchy-other.packages" \
    | sort -u > /tmp/omarchy-default-pkgs.txt
  comm -23 <(sort -u packages/pacman-all.txt) /tmp/omarchy-default-pkgs.txt > packages/pacman-extra.txt
  rm -f /tmp/omarchy-default-pkgs.txt
else
  cp packages/pacman-all.txt packages/pacman-extra.txt
fi

echo "==> Exporting Omarchy webapps (Name|URL)..."
: > webapps/webapps.txt
grep -l 'Exec=omarchy-launch-webapp' "$HOME"/.local/share/applications/*.desktop 2>/dev/null | while read -r f; do
  name=$(grep '^Name=' "$f" | head -1 | cut -d= -f2-)
  url=$(grep '^Exec=' "$f" | head -1 | sed -E 's/^Exec=omarchy-launch-webapp\s+//')
  echo "${name}|${url}" >> webapps/webapps.txt
done

echo "==> Refreshing dotfiles..."
rm -rf dotfiles
mkdir -p dotfiles/.config/git
for d in hypr waybar alacritty kitty ghostty tmux nvim btop fastfetch fcitx5 walker mako qalculate environment.d mise omarchy; do
  [ -e "$HOME/.config/$d" ] && cp -rL --parents ".config/$d" dotfiles/ 2>/dev/null
done
(cd "$HOME" && for f in .config/starship.toml .config/mimeapps.list .config/xdg-terminals.list .bashrc .bash_profile; do
  [ -e "$f" ] && cp --parents "$f" "$OLDPWD/dotfiles/" 2>/dev/null
done)
[ -e "$HOME/.config/git/config" ] && cp "$HOME/.config/git/config" dotfiles/.config/git/config
[ -e "$HOME/.config/git/ignore" ] && cp "$HOME/.config/git/ignore" dotfiles/.config/git/ignore
find dotfiles -name "*.bak*" -delete

echo "Done. Review packages/pacman-extra.txt, packages/aur-extra.txt and packages/flatpak.txt before committing/sharing."
