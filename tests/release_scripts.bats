setup() {
  load test_helper/common
  CONV_SCRIPT="$REPO_ROOT/.github/scripts/conventional-notes.sh"
  INSERT_SCRIPT="$REPO_ROOT/.github/scripts/insert-changelog-section.sh"
}

# --- conventional-notes.sh -------------------------------------------------

setup_fixture_repo() {
  REPO="$BATS_TEST_TMPDIR/fixture-repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"

  echo a >a.txt
  git add a.txt
  git commit -qm "chore: setup inicial"
  git tag v0.0.1

  echo b >b.txt
  git add b.txt
  git commit -qm "feat: adiciona script de personalização"

  echo c >c.txt
  git add c.txt
  git commit -qm "fix(install): passa pacotes como array pro yay"

  echo d >d.txt
  git add d.txt
  git commit -qm "chore(release): v0.0.2 [skip ci]"

  git checkout -qb tmp-branch
  echo e >e.txt
  git add e.txt
  git commit -qm "docs: atualiza README"
  git checkout -q -
  git merge -q --no-ff tmp-branch -m "Merge branch 'tmp-branch'"
}

@test "conventional-notes agrupa feat/fix corretamente e ignora merge/skip-ci/release commits" {
  setup_fixture_repo
  run "$CONV_SCRIPT" v0.0.1 HEAD
  [ "$status" -eq 0 ]
  [[ "$output" == *"### Added"* ]]
  [[ "$output" == *"adiciona script de personalização"* ]]
  [[ "$output" == *"### Fixed"* ]]
  [[ "$output" == *"passa pacotes como array pro yay"* ]]
  [[ "$output" == *"### Changed"* ]]
  [[ "$output" == *"atualiza README"* ]]
  [[ "$output" != *"setup inicial"* ]]
  [[ "$output" != *"Merge branch"* ]]
  [[ "$output" != *"v0.0.2 [skip ci]"* ]]
}

@test "conventional-notes sem ref inicial cobre o histórico inteiro" {
  setup_fixture_repo
  run "$CONV_SCRIPT" "" HEAD
  [ "$status" -eq 0 ]
  [[ "$output" == *"setup inicial"* ]]
}

@test "conventional-notes indica quando não há mudanças notáveis" {
  REPO="$BATS_TEST_TMPDIR/empty-repo"
  mkdir -p "$REPO" && cd "$REPO"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  echo a >a.txt
  git add a.txt
  git commit -qm "chore(release): v0.0.1 [skip ci]"
  git tag v0.0.1

  run "$CONV_SCRIPT" v0.0.1 HEAD
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sem mudanças notáveis"* ]]
}

# --- insert-changelog-section.sh -------------------------------------------

@test "insere a nova seção logo abaixo de [Não lançado] mantendo-a vazia" {
  changelog="$BATS_TEST_TMPDIR/CHANGELOG.md"
  cat >"$changelog" <<'EOF'
# Changelog

## [Não lançado]

## [2026-08-15] - Backup inicial

### Added

- coisa antiga
EOF
  body="$BATS_TEST_TMPDIR/body.md"
  printf '### Added\n\n- coisa nova (abc123)\n' >"$body"

  run "$INSERT_SCRIPT" "$changelog" "v2026.08.16" "2026-08-16" "$body"
  [ "$status" -eq 0 ]

  # Unreleased continua vazia (próxima linha não-vazia já é a nova seção)
  awk '/^## \[Não lançado\]/{f=1; next} f && NF {print; exit}' "$changelog" | grep -qx "## \[v2026.08.16\] - 2026-08-16"

  grep -q "coisa nova (abc123)" "$changelog"
  grep -q "coisa antiga" "$changelog"

  # a seção antiga continua depois, intacta
  run grep -n "2026-08-15" "$changelog"
  [ "$status" -eq 0 ]
}

@test "preserva bullets já escritos à mão em [Não lançado] dentro da nova seção" {
  changelog="$BATS_TEST_TMPDIR/CHANGELOG.md"
  cat >"$changelog" <<'EOF'
# Changelog

## [Não lançado]

### Added

- nota escrita à mão antes da release

## [2026-08-15] - Backup inicial

### Added

- coisa antiga
EOF
  body="$BATS_TEST_TMPDIR/body.md"
  printf '### Added\n\n- nota gerada do commit (abc123)\n' >"$body"

  run "$INSERT_SCRIPT" "$changelog" "v2026.08.16" "2026-08-16" "$body"
  [ "$status" -eq 0 ]

  # a nota manual não ficou órfã: está dentro da seção nova, não sobrou em Unreleased
  awk '/^## \[Não lançado\]/{f=1; next} f && NF {print; exit}' "$changelog" | grep -qx "## \[v2026.08.16\] - 2026-08-16"
  grep -q "nota escrita à mão antes da release" "$changelog"
  grep -q "nota gerada do commit (abc123)" "$changelog"

  # e a nota manual aparece ANTES da nota gerada, dentro da nova seção
  awk '/## \[v2026.08.16\]/{f=1} f{print; if (/Backup inicial/) exit}' "$changelog" |
    grep -n "nota escrita à mão\|nota gerada do commit" | awk -F: '{print $1}' >"$BATS_TEST_TMPDIR/order.txt"
  [ "$(sed -n '1p' "$BATS_TEST_TMPDIR/order.txt")" -lt "$(sed -n '2p' "$BATS_TEST_TMPDIR/order.txt")" ]
}

@test "falha com mensagem clara se o CHANGELOG não existe" {
  body="$BATS_TEST_TMPDIR/body.md"
  echo "- x" >"$body"
  run "$INSERT_SCRIPT" "$BATS_TEST_TMPDIR/nao-existe.md" "v1" "2026-01-01" "$body"
  [ "$status" -ne 0 ]
  [[ "$output" == *"não encontrado"* ]]
}

@test "falha com mensagem clara se não houver seção [Não lançado]" {
  changelog="$BATS_TEST_TMPDIR/CHANGELOG.md"
  printf '# Changelog\n\nsem seção unreleased aqui\n' >"$changelog"
  body="$BATS_TEST_TMPDIR/body.md"
  echo "- x" >"$body"
  run "$INSERT_SCRIPT" "$changelog" "v1" "2026-01-01" "$body"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Não lançado"* ]]
}
