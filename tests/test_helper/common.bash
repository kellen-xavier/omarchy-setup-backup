# Helpers compartilhados entre os arquivos .bats deste repo.
# Carregado com: load test_helper/common

REPO_ROOT="$(cd -- "${BATS_TEST_DIRNAME}/.." &>/dev/null && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures"

# Cria um binário fake em $BATS_TEST_TMPDIR/bin, na frente do PATH, que grava
# cada invocação (args) em $2 (se dado) e sai com o código em $3 (default 0).
#
# install_mock <nome> [arquivo-de-registro] [exit-code]
install_mock() {
  local name="$1" record="${2:-/dev/null}" exit_code="${3:-0}"
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  cat >"$bindir/$name" <<MOCK
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$record"
exit $exit_code
MOCK
  chmod +x "$bindir/$name"
  export PATH="$bindir:$PATH"
}

# Remove um comando do PATH escondendo-o atrás de um PATH mínimo controlado
# (útil para testar "dependência ausente" sem depender do que está instalado
# na máquina/runner).
restrict_path_to() {
  local bindir="$BATS_TEST_TMPDIR/minpath"
  mkdir -p "$bindir"
  local cmd
  for cmd in "$@"; do
    local real
    real="$(command -v "$cmd" || true)"
    [[ -n "$real" ]] && ln -sf "$real" "$bindir/$cmd"
  done
  export PATH="$bindir"
}
