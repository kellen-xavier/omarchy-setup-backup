# Changelog

Todas as mudanças notáveis deste backup são documentadas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Como este é um backup pessoal (não um software versionado), as entradas usam
data em vez de número de versão.

## [Não lançado]

## [v2026.08.15] - 2026-08-15

### Added

- Suíte de testes com [bats-core](https://github.com/bats-core/bats-core)
  (`tests/`) cobrindo `export.sh`, `install.sh`, `personaliza-meu-omarchy.sh`
  e os scripts de release — 33 testes.
- Pipeline de CI (`.github/workflows/ci.yml`): roda os testes e o lint
  (shellcheck + shfmt) em toda branch e PR; em push para `develop`/`feature/**`
  também aplica auto-fix de formatação e comita de volta.
- Pipeline de release (`.github/workflows/release.yml`): depois que a CI passa
  num push na `main`, gera a versão (calver), monta as notas a partir dos
  Conventional Commits desde a última tag, atualiza este CHANGELOG
  automaticamente, empacota um `.tar.gz` da release, publica no GitHub
  Releases e sincroniza `main` de volta em `develop`.
- `-y`/`--yes` e `-h`/`--help` em `install.sh`, `-h`/`--help` em `export.sh`,
  pra deixar os três scripts consistentes e roteirizáveis (necessário pros
  testes automatizados).

### Fixed

- `export.sh`: o loop que copiava `hypr/`, `waybar/`, etc. pra `dotfiles/`
  usava caminho relativo sem antes trocar pro `$HOME`, então `cp` falhava
  silenciosamente (stderr suprimido) e o script morria no meio da cópia sem
  nenhuma mensagem de erro.
- `export.sh`: o cálculo de `pacman-extra.txt` comparava com um arquivo
  temporário poluído pelo prefixo `arquivo:` que o `grep` adiciona ao ler
  múltiplos arquivos — na prática, o diff contra a base do Omarchy nunca
  filtrava nada.
- `.github/scripts/conventional-notes.sh`: `git log --pretty=format:` não
  emite newline no último commit, então o `read` do loop descartava a última
  linha (silenciosamente, sem erro).
- `install.sh`: `yay -S --needed $pkgs` (SC2086, word-splitting não
  intencional) e `[ -n "$app" ] && ... || true` (SC2015) trocados por um
  array (`mapfile`) e um `if` explícito.
- `.github/scripts/insert-changelog-section.sh`: bullets já escritos à mão em
  `[Não lançado]` antes da release ficavam órfãos abaixo da nova seção em vez
  de entrar nela — corrigido pra preservar esse conteúdo dentro da seção nova.
- `release.yml`: `git push origin main` falhava com `src refspec main does
  not match any` porque o `actions/checkout` com `ref: <sha>` deixa o HEAD
  destacado (sem branch local). Corrigido com `git checkout -B main` logo
  após o checkout.

### Added

- add script de personalização (aa986f9)
- backup sistema operacional omarchy (3245348)

### Fixed

- check tags release (e204a08)

### Changed

- add config de pipeline and tests (4763060)
- add changelog into the repo (ffe5db0)


## [2026-08-15] - Script de personalização visual

### Added (personalização visual)

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

### Added (backup inicial)

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
