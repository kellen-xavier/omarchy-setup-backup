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

## Desenvolvimento & CI/CD

Fluxo de branches: `feature/*` → PR pra `develop` → PR de `develop` pra `main`.
Commits seguem [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `chore:`, `docs:`, ...) — a pipeline de release depende
disso pra gerar o changelog automaticamente.

### Testes

```bash
# instalar bats-core uma vez (https://github.com/bats-core/bats-core)
git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
sudo /tmp/bats-core/install.sh /usr/local

# rodar a suíte
bats -r tests
```

Os testes rodam os scripts de verdade (não reimplementam a lógica): copiam
`export.sh`/`install.sh`/`personaliza-meu-omarchy.sh` pra um diretório
temporário junto de fixtures pequenas, apontam `$HOME` pra outro diretório
temporário e usam mocks (`tests/test_helper/common.bash`) pra `pacman`, `yay`,
`flatpak`, `omarchy-theme-set` etc. Nada toca a máquina real.

### Pipeline (`.github/workflows/`)

- **`ci.yml`** — em toda branch e PR: roda a suíte `bats` e o `shellcheck`.
  Em push direto pra `develop`/`feature/**` (não pra `main`), também aplica
  `shfmt -w` (auto-fix de formatação) e comita a correção de volta com
  `[skip ci]`. Push/PR na `main` só verifica, nunca comita.
- **`release.yml`** — dispara depois que a `ci.yml` termina com sucesso num
  push na `main` (ou seja, depois que `develop` foi mergeada). Se houver
  commits novos desde a última tag: calcula a versão (`vAAAA.MM.DD`, com
  sufixo se já existir tag no dia), gera as notas a partir dos Conventional
  Commits (`.github/scripts/conventional-notes.sh`), insere uma nova seção
  no `CHANGELOG.md` logo abaixo de `[Não lançado]` preservando o que já
  estava escrito lá à mão (`.github/scripts/insert-changelog-section.sh`),
  empacota um `.tar.gz` da release, publica no GitHub Releases e sincroniza
  `main` de volta em `develop`.

**Configuração única no GitHub** (Settings → Actions → General → Workflow
permissions): marque **"Read and write permissions"**, senão os jobs que
comitam de volta (auto-fix e release) falham com 403.
