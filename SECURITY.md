# Política de Segurança

Este é um repositório **pessoal e público**: um backup do meu setup Omarchy
(pacotes, dotfiles, webapps) pra reinstalar rápido em outra máquina. Este
documento existe pra deixar explícito o que é e o que não é seguro versionar
aqui, e quais riscos `install.sh` carrega quando rodado numa máquina nova.

## O que este backup nunca inclui

Por design, nada disto entra neste repositório — nem por acidente:

- Credenciais: `.git-credentials`, chaves SSH (`id_rsa*`, `*.pem`, `*.key`),
  `.env`, `.netrc`, tokens de API.
- Perfis de browser (Chrome/Chromium/Opera), vault do Bitwarden, tokens de
  sessão do Slack/Discord.
- Histórico do bash, caches (`~/.cache`), SDKs grandes (Android SDK,
  `node_modules`, etc.) e save games.

O `.gitignore` bloqueia os padrões de arquivo mais comuns desses casos
(`*.pem`, `*.key`, `id_rsa*`, `.env`, `.netrc`, `*token*`) como uma rede de
segurança — mas isso é a **última** linha de defesa, não a única: `export.sh`
só copia diretórios de config explicitamente listados (nunca `$HOME` inteiro
ou `~/.ssh`), e qualquer arquivo novo que passe a ser exportado deve ser
revisado manualmente antes do commit.

## Higiene já garantida automaticamente

- **`git/config` nunca leva identidade real.** `export.sh` remove `name` e
  `email` da seção `[user]` do `~/.config/git/config` antes de copiar pro
  backup — mesmo sendo um e-mail de trabalho, ele nunca é versionado num
  repositório público. O resto do arquivo (aliases, `[pull]`, `[diff]` etc.)
  não é sensível e é preservado.
- **CI roda com o mínimo de permissão necessária.** O `GITHUB_TOKEN` é
  `contents: read` por padrão no workflow `CI`; só o job `lint-and-fix`
  (que comita a auto-formatação de volta) recebe `contents: write`, e mesmo
  assim só em push pra `develop`/`feature/**` — nunca em PR ou em `main`.

## Riscos conhecidos ao rodar `install.sh` numa máquina nova

`install.sh` não é sandboxed — ele instala pacotes e sobrescreve arquivos em
`$HOME` de verdade. Antes de rodar numa máquina nova (ou de confiar num fork
deste repo que não seja o meu):

1. **Revise `packages/pacman-extra.txt` e `packages/aur-extra.txt`.**
   `install.sh` passa essas listas direto pro `yay -S --needed`, instalando
   pacotes AUR (código de terceiros, sem revisão de segurança da Arch) com
   privilégio de root.
2. **Revise `dotfiles/` antes de restaurar.** Além de configs, o backup
   inclui `.bashrc` e os hooks do Omarchy
   (`dotfiles/.config/omarchy/hooks/**`, `dotfiles/.config/omarchy/plugins/**`),
   que rodam automaticamente (login, troca de tema, atualização do sistema
   etc.). Um dotfile malicioso aqui equivale a execução de código arbitrário
   no login.
3. `install.sh` faz backup (`.pre-restore.bak`) de qualquer arquivo existente
   antes de sobrescrever — mas isso é recuperação, não prevenção. Leia o
   `diff` antes de confirmar cada etapa se a origem do backup não for 100%
   confiável.

## Pendências identificadas (não corrigidas automaticamente)

Ficaram documentadas aqui em vez de corrigidas porque envolvem uma escolha
de trade-off que é minha, não um bug:

- **`credential.helper = store`** no `git/config` restaurado grava
  credenciais do git em **texto puro** em `~/.git-credentials` na máquina de
  destino. Considerar trocar para `cache` (expira sozinho) ou um helper de
  keyring do SO (`libsecret`, `pass`) antes de reusar esse config numa
  máquina nova.
- **`ci.yml`/`release.yml` baixam o binário do `shfmt`
  (`mvdan/sh`) via `curl` sem checar checksum/assinatura.** Se o release
  daquele projeto for comprometido, o binário baixado na CI não seria
  detectado. Mitigação futura: fixar o `sha256` esperado do binário por
  versão e validar antes do `chmod +x`.

## Reportar um problema de segurança

Encontrou um segredo vazado, uma dependência da CI comprometida, ou qualquer
outro problema de segurança neste repositório? Abra uma
[Security Advisory privada](../../security/advisories/new) no GitHub em vez
de uma issue pública — assim dá pra corrigir (e invalidar credenciais, se
for o caso) antes de qualquer detalhe ficar público.
