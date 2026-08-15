# Changelog

Todas as mudanças notáveis deste backup são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Como este é um backup pessoal (não um software versionado), as entradas usam
data em vez de número de versão.

## [Não lançado]

## [2026-08-15] - Script de personalização visual

### Added
- `personaliza-meu-omarchy.sh` — aplica só a aparência (tema Omarchy via
  `omarchy-theme-set`, kitty, alacritty, ghostty, waybar, starship, btop,
  fastfetch, hypr look'n'feel) numa máquina que já tem tudo instalado, sem
  mexer em pacotes, bindings ou monitores. Suporta `-y`, `-n` (dry-run) e `-h`.
- `.gitignore` para excluir artefatos derivados e evitar que segredos entrem
  no repositório por acidente.

### Removed
- Assets do tema Catppuccin do Omarchy (`dotfiles/.config/omarchy/current/theme/`,
  `background`) e cópias derivadas (`mako/config`, `btop/themes/current.theme`,
  `fcitx5/conf/cached_layouts`) que tinham sido commitados por engano — são
  100% regenerados pelo próprio Omarchy ao aplicar o tema, não precisam ficar
  versionados. Isso tirou ~2.4 MB de binários redundantes do repositório.

## [2026-08-15] - Backup inicial

### Added
- Estrutura do repositório: `dotfiles/`, `packages/`, `webapps/`.
- `export.sh` — gera as listas autoritativas de pacotes (pacman/AUR/flatpak)
  e atualiza os dotfiles a partir da máquina de origem.
- `install.sh` — restaura pacotes extras, apps flatpak, webapps do Omarchy
  (ChatGPT, Discord, Figma, etc.) e dotfiles numa máquina nova.
- Dotfiles reais de: Hyprland, Waybar, terminais (alacritty/kitty/ghostty),
  tmux, neovim (LazyVim), btop, fastfetch, mako, walker, qalculate,
  environment.d, mise, tema/branding do Omarchy, git config, starship,
  mimeapps.list, xdg-terminals.list.
- `packages/pacman-extra.txt`, `packages/aur-extra.txt`, `packages/flatpak.txt`,
  `packages/manual-notes.txt` — pacotes além da base do Omarchy.
- `README.md` documentando o uso e as limitações do backup.
