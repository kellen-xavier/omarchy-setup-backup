# Omarchy Setup Backup

Backup do meu setup pessoal (Arch Linux + [Omarchy](https://omarchy.org)) para
reinstalar rapidamente em outra máquina.

## Aviso importante

Esta pasta foi gerada dentro de uma [sessão de agente sandboxed - leia mais aqui](https://github.com/akitaonrails/ai-jail), que **não tem acesso ao banco de dados real do pacman** desta máquina (roda isolado, só o seu
`$HOME` está montado de verdade). Por isso:

- `dotfiles/` é **real** — são cópias de verdade dos seus arquivos de config.
- `packages/pacman-extra.txt`, `packages/aur-extra.txt` e `packages/flatpak.txt`
  são um **palpite** baseado nas pastas presentes em `~/.config` (ex: pasta
  `~/.config/darktable` → pacote `darktable`). **Antes de usar em outra
  máquina, rode `./export.sh` num terminal normal desta máquina** para
  regenerar essas listas com o `pacman -Qqe` / `pacman -Qqm` reais.

## O que está aqui

- `export.sh` — roda na máquina de origem (a atual). Regenera as listas de
  pacotes autoritativas e atualiza os dotfiles.
- `install.sh` — roda na máquina nova, depois de instalar o Omarchy do zero.
  Instala os pacotes extras, os apps flatpak, recria os webapps do Omarchy
  (ChatGPT, Discord, Figma, etc.) e restaura os dotfiles.
- `personaliza-meu-omarchy.sh` — versão enxuta do `install.sh`: aplica só a
  aparência (tema Omarchy, kitty/alacritty/ghostty, waybar, starship, btop,
  fastfetch, hypr look'n'feel). Não mexe em pacotes nem em bindings/monitores.
  Útil pra igualar o visual numa máquina que já tem tudo instalado. Aceita
  `-y` (sem confirmação), `-n` (dry-run) e `-h` (ajuda).
- `packages/` — listas de pacotes pacman/AUR/flatpak que você tem *além* do
  que o Omarchy já instala por padrão (o Omarchy tem seu próprio
  `omarchy-reinstall-pkgs` para a base — não duplicamos isso aqui).
- `webapps/webapps.txt` — apps web registrados via `omarchy-launch-webapp`
  (Discord, Figma, ChatGPT, GitHub, etc.), no formato `Nome|URL`.
- `dotfiles/` — cópia real de:
  - `hypr/` — Hyprland (bindings, monitors, hyprlock, hypridle, hyprsunset, etc.)
  - `waybar/` — barra (config.jsonc + style.css customizados)
  - `alacritty/`, `kitty/`, `ghostty/` — terminais
  - `tmux/tmux.conf`
  - `nvim/` — config do neovim (LazyVim)
  - `btop/`, `fastfetch/`, `mako/`, `walker/`, `qalculate/`, `environment.d/`
  - `mise/config.toml` — versões de runtime (dotnet, java, node, ruby)
  - `omarchy/` — tema atual (catppuccin), hooks, branding
  - `.bashrc`, `.bash_profile`, `.config/git/config`, `starship.toml`,
    `mimeapps.list`, `xdg-terminals.list`

## O que NÃO está aqui (de propósito)

Nada de segredos ou dados grandes: `.git-credentials`, chaves SSH, perfis de
browser (Chrome/Chromium/Opera), vault do Bitwarden, tokens do Slack/Discord,
histórico do bash, caches (`~/.cache`), SDKs grandes (Android SDK, node_modules
etc.) e save games. Se quiser levar algo disso, copie manualmente — são dados
sensíveis ou grandes demais para ficar num script de setup.

Apps que não têm um pacote simples para instalar (GameMaker Studio 2 Beta,
Affinity via Wine, Unity via Unity Hub, JetBrains via Toolbox) estão listados
em `packages/manual-notes.txt` com instruções.

## Uso

Na máquina atual (para atualizar este backup com dados reais):

```bash
cd ~/omarchy-setup-backup
./export.sh
```

Depois, copie esta pasta inteira para a máquina nova (pendrive, git, scp,
syncthing — o que preferir) e, com o Omarchy já instalado nela:

```bash
cd ~/omarchy-setup-backup
./install.sh
```

O script pergunta antes de cada etapa (pacotes, flatpak, webapps, dotfiles) e
faz backup (`.pre-restore.bak`) de qualquer arquivo que for sobrescrever.
