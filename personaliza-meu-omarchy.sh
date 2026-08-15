#!/usr/bin/env bash
#
# personaliza-meu-omarchy.sh
#
# Aplica só a PERSONALIZAÇÃO VISUAL (tema Omarchy + configs de terminal/prompt/
# waybar) deste backup numa instalação Omarchy já existente. Não mexe em
# pacotes, keybindings, monitores ou qualquer coisa "funcional" — isso é
# trabalho do install.sh. Este script é sobre aparência.
#
# Uso:
#   ./personaliza-meu-omarchy.sh [-y|--yes] [-n|--dry-run] [-h|--help]

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
readonly SCRIPT_DIR DOTFILES_DIR

ASSUME_YES=0
DRY_RUN=0

# Arquivos de aparência que sobrescrevem a config local (fora do que o
# omarchy-theme-set já cobre sozinho: waybar.css, kitty include, alacritty
# import, ghostty config-file, mako, btop, hyprlock/hyprland source etc.)
readonly -a APPEARANCE_FILES=(
  ".config/kitty/kitty.conf"
  ".config/alacritty/alacritty.toml"
  ".config/ghostty/config"
  ".config/waybar/config.jsonc"
  ".config/waybar/style.css"
  ".config/starship.toml"
  ".config/hypr/looknfeel.conf"
  ".config/btop/btop.conf"
  ".config/fastfetch/config.jsonc"
)

# --- output helpers -------------------------------------------------------

if [[ -t 1 ]]; then
  C_INFO=$'\e[36m'
  C_OK=$'\e[32m'
  C_WARN=$'\e[33m'
  C_ERR=$'\e[31m'
  C_RESET=$'\e[0m'
else
  C_INFO=""
  C_OK=""
  C_WARN=""
  C_ERR=""
  C_RESET=""
fi

log() { printf '%s==>%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
ok() { printf '%s✓%s %s\n' "$C_OK" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die() {
  printf '%s✗%s %s\n' "$C_ERR" "$C_RESET" "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Uso: $(basename "$0") [opções]

Aplica o tema Omarchy e as configs de aparência (kitty, alacritty, ghostty,
waybar, starship, btop, fastfetch, hypr look'n'feel) deste backup na máquina
atual.

Opções:
  -y, --yes       Não pergunta confirmação antes de aplicar
  -n, --dry-run   Mostra o que seria feito, sem alterar nada
  -h, --help      Mostra esta ajuda
EOF
}

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- arg parsing ------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes) ASSUME_YES=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "Opção desconhecida: $1 (use --help)" ;;
  esac
  shift
done

# --- pre-flight checks -----------------------------------------------------

[[ -d "$DOTFILES_DIR" ]] || die "Pasta dotfiles/ não encontrada em $SCRIPT_DIR — rode este script de dentro do backup."

if ! command -v omarchy-theme-set >/dev/null 2>&1; then
  die "omarchy-theme-set não encontrado. Este script espera uma instalação Omarchy (https://omarchy.org)."
fi

THEME_NAME_FILE="$DOTFILES_DIR/.config/omarchy/current/theme.name"
THEME_NAME=""
[[ -f "$THEME_NAME_FILE" ]] && THEME_NAME="$(<"$THEME_NAME_FILE")"

log "Backup:        $SCRIPT_DIR"
log "Tema alvo:     ${THEME_NAME:-<nenhum registrado>}"
log "Modo:          $([[ $DRY_RUN -eq 1 ]] && echo 'dry-run (nada será alterado)' || echo 'aplicar')"
echo

# --- 1. Tema Omarchy --------------------------------------------------------
# omarchy-theme-set já propaga cor/tema pra waybar.css, kitty/alacritty/
# ghostty (via include), hyprlock, mako, btop, vscode, gnome, browser etc,
# e reinicia os serviços afetados. É sempre o primeiro passo.

if [[ -n "$THEME_NAME" ]]; then
  if confirm "Aplicar o tema Omarchy '$THEME_NAME'?"; then
    log "Aplicando tema '$THEME_NAME'..."
    if run omarchy-theme-set "$THEME_NAME"; then
      ok "Tema '$THEME_NAME' aplicado."
    else
      warn "Tema '$THEME_NAME' não encontrado nesta máquina (rode 'omarchy theme install <repo>' se for um tema custom). Pulando."
    fi
  else
    warn "Aplicação de tema pulada a pedido."
  fi
else
  warn "Nenhum theme.name no backup — pulando seleção de tema."
fi
echo

# --- 2. Configs de aparência por app ---------------------------------------

if confirm "Restaurar configs de aparência (kitty, alacritty, ghostty, waybar, starship, btop, fastfetch, hypr looknfeel)?"; then
  for rel in "${APPEARANCE_FILES[@]}"; do
    src="$DOTFILES_DIR/$rel"
    dest="$HOME/$rel"

    [[ -f "$src" ]] || {
      warn "Ausente no backup, pulando: $rel"
      continue
    }

    if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
      run cp "$dest" "$dest.pre-personalize.bak"
    fi

    run mkdir -p "$(dirname "$dest")"
    run cp "$src" "$dest"
    ok "$rel"
  done
else
  warn "Restauração de configs pulada a pedido."
fi
echo

# --- 3. Recarregar o que não é coberto pelo omarchy-theme-set ---------------

log "Recarregando serviços..."
if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
  run hyprctl reload && ok "Hyprland recarregado"
fi
if pgrep -x waybar >/dev/null 2>&1 && command -v omarchy-restart-waybar >/dev/null 2>&1; then
  run omarchy-restart-waybar && ok "Waybar reiniciado"
fi

echo
ok "Personalização aplicada."
[[ $DRY_RUN -eq 1 ]] && warn "Modo dry-run: nada foi realmente alterado."
log "Terminais já abertos (kitty/alacritty/ghostty) precisam ser reabertos para pegar a config nova."
