setup() {
  load test_helper/common
  cd "$REPO_ROOT"
  mapfile -t SCRIPTS < <(git ls-files '*.sh')
}

@test "todos os scripts .sh têm sintaxe bash válida" {
  for f in "${SCRIPTS[@]}"; do
    run bash -n "$f"
    [ "$status" -eq 0 ]
  done
}

@test "todos os scripts .sh têm shebang" {
  for f in "${SCRIPTS[@]}"; do
    head -n1 "$f" | grep -qE '^#!.*(bash|sh)'
  done
}

@test "shellcheck não acusa nenhum problema" {
  if ! command -v shellcheck >/dev/null; then
    skip "shellcheck não está instalado nesta máquina"
  fi
  run shellcheck "${SCRIPTS[@]}"
  [ "$status" -eq 0 ]
}

@test "shfmt não teria nada a formatar" {
  if ! command -v shfmt >/dev/null; then
    skip "shfmt não está instalado nesta máquina"
  fi
  run shfmt -d -i 2 -ci "${SCRIPTS[@]}"
  [ "$status" -eq 0 ]
}
