setup() {
  load test_helper/common

  # Sandbox isolada: copia o script real + um dotfiles/ fixture pequeno pra
  # um diretório temporário, e aponta $HOME pra outro diretório temporário.
  # Isso exercita o script de verdade, sem tocar na máquina real nem
  # depender do dotfiles/ completo (grande e com dados pessoais).
  WORKDIR="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORKDIR"
  cp "$REPO_ROOT/personaliza-meu-omarchy.sh" "$WORKDIR/"
  cp -r "$FIXTURES_DIR/mini-dotfiles" "$WORKDIR/dotfiles"

  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME"
  export HOME="$FAKE_HOME"

  SCRIPT="$WORKDIR/personaliza-meu-omarchy.sh"
}

@test "-h mostra o uso e sai com sucesso" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Uso:"* ]]
}

@test "opção desconhecida falha com mensagem clara" {
  run "$SCRIPT" --nao-existe
  [ "$status" -ne 0 ]
  [[ "$output" == *"Opção desconhecida"* ]]
}

@test "falha se omarchy-theme-set não está instalado" {
  restrict_path_to bash cat mkdir cp rm grep sed dirname basename cmp printf mktemp
  run "$SCRIPT" -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"omarchy-theme-set"* ]]
}

@test "falha se a pasta dotfiles/ não existe ao lado do script" {
  rm -rf "$WORKDIR/dotfiles"
  install_mock omarchy-theme-set
  run "$SCRIPT" -y
  [ "$status" -ne 0 ]
  [[ "$output" == *"dotfiles"* ]]
}

@test "--dry-run não altera nenhum arquivo no HOME" {
  install_mock omarchy-theme-set "$BATS_TEST_TMPDIR/theme-calls.log"
  run "$SCRIPT" -y -n
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_HOME/.config/kitty/kitty.conf" ]
  [ ! -e "$FAKE_HOME/.config/starship.toml" ]
  [ ! -f "$BATS_TEST_TMPDIR/theme-calls.log" ]
  [[ "$output" == *"dry-run"* ]]
}

@test "aplica o tema lido de theme.name chamando omarchy-theme-set" {
  install_mock omarchy-theme-set "$BATS_TEST_TMPDIR/theme-calls.log"
  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/theme-calls.log" ]
  grep -qx "faketheme" "$BATS_TEST_TMPDIR/theme-calls.log"
}

@test "restaura os arquivos de aparência para dentro do HOME" {
  install_mock omarchy-theme-set
  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [ -f "$FAKE_HOME/.config/kitty/kitty.conf" ]
  [ "$(cat "$FAKE_HOME/.config/kitty/kitty.conf")" = "kitty-personalizado-fixture" ]
  [ -f "$FAKE_HOME/.config/starship.toml" ]
}

@test "faz backup .pre-personalize.bak de um arquivo existente e diferente" {
  install_mock omarchy-theme-set
  mkdir -p "$FAKE_HOME/.config/kitty"
  echo "config-antiga-do-usuario" >"$FAKE_HOME/.config/kitty/kitty.conf"

  run "$SCRIPT" -y
  [ "$status" -eq 0 ]

  [ -f "$FAKE_HOME/.config/kitty/kitty.conf.pre-personalize.bak" ]
  [ "$(cat "$FAKE_HOME/.config/kitty/kitty.conf.pre-personalize.bak")" = "config-antiga-do-usuario" ]
  [ "$(cat "$FAKE_HOME/.config/kitty/kitty.conf")" = "kitty-personalizado-fixture" ]
}

@test "não cria backup quando o arquivo existente já é idêntico" {
  install_mock omarchy-theme-set
  mkdir -p "$FAKE_HOME/.config/kitty"
  echo "kitty-personalizado-fixture" >"$FAKE_HOME/.config/kitty/kitty.conf"

  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_HOME/.config/kitty/kitty.conf.pre-personalize.bak" ]
}

@test "pula arquivo de aparência ausente no backup sem falhar" {
  rm "$WORKDIR/dotfiles/.config/starship.toml"
  install_mock omarchy-theme-set
  run "$SCRIPT" -y
  [ "$status" -eq 0 ]
  [[ "$output" == *"Ausente no backup, pulando"* ]]
}
