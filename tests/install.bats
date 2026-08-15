setup() {
  load test_helper/common

  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR/packages" "$WORKDIR/webapps"
  cp "$REPO_ROOT/install.sh" "$WORKDIR/"

  cat >"$WORKDIR/packages/pacman-extra.txt" <<'EOF'
# comentário, deve ser ignorado
darktable
qbittorrent
EOF
  cat >"$WORKDIR/packages/aur-extra.txt" <<'EOF'
google-chrome
EOF
  : >"$WORKDIR/packages/flatpak.txt"

  cat >"$WORKDIR/webapps/webapps.txt" <<'EOF'
# comentário
ChatGPT|https://chatgpt.com/
Discord|https://discord.com/channels/@me
EOF

  mkdir -p "$WORKDIR/dotfiles/.config/tmux"
  echo "tmux-fixture" >"$WORKDIR/dotfiles/.config/tmux/tmux.conf"

  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME"
  export HOME="$FAKE_HOME"

  SCRIPT="$WORKDIR/install.sh"
}

@test "-h mostra o uso e sai com sucesso" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "opção desconhecida falha com mensagem clara" {
  run "$SCRIPT" --oops
  [ "$status" -ne 0 ]
  [[ "$output" == *"Opção desconhecida"* ]]
}

@test "falha se yay não está instalado" {
  restrict_path_to bash cat mkdir cp rm grep sed dirname basename cmp printf mktemp find
  run "$SCRIPT" -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"yay"* ]]
}

@test "instala pacotes extras passando cada pacote como argumento separado (sem word-splitting quebrado)" {
  install_mock yay "$BATS_TEST_TMPDIR/yay-calls.log"
  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/yay-calls.log" ]
  grep -qx -- "-S --needed darktable qbittorrent google-chrome" "$BATS_TEST_TMPDIR/yay-calls.log"
}

@test "recria os webapps listados, pulando comentários e linhas vazias" {
  install_mock yay
  install_mock omarchy-webapp-install "$BATS_TEST_TMPDIR/webapp-calls.log"
  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$BATS_TEST_TMPDIR/webapp-calls.log")" -eq 2 ]
  grep -qx "ChatGPT https://chatgpt.com/" "$BATS_TEST_TMPDIR/webapp-calls.log"
  grep -qx "Discord https://discord.com/channels/@me" "$BATS_TEST_TMPDIR/webapp-calls.log"
}

@test "restaura dotfiles para dentro do HOME e faz backup do que já existia" {
  install_mock yay
  mkdir -p "$FAKE_HOME/.config/tmux"
  echo "tmux-do-usuario" >"$FAKE_HOME/.config/tmux/tmux.conf"

  run "$SCRIPT" -y
  [ "$status" -eq 0 ]

  [ "$(cat "$FAKE_HOME/.config/tmux/tmux.conf")" = "tmux-fixture" ]
  [ -f "$FAKE_HOME/.config/tmux/tmux.conf.pre-restore.bak" ]
  [ "$(cat "$FAKE_HOME/.config/tmux/tmux.conf.pre-restore.bak")" = "tmux-do-usuario" ]
}
