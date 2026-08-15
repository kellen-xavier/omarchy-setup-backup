#!/usr/bin/env bash
#
# Insere uma nova seção de release logo abaixo de "## [Não lançado]" no
# CHANGELOG.md (formato Keep a Changelog), deixando a seção Unreleased vazia
# de novo por cima da seção recém-criada.
#
# Qualquer bullet já escrito à mão em [Não lançado] antes da release (prática
# normal deste repo) é preservado: some da seção Unreleased e entra no topo
# do corpo da nova seção de versão, antes das notas geradas automaticamente.
#
# Uso: insert-changelog-section.sh <changelog> <versão> <data-iso> <arquivo-com-corpo>
set -euo pipefail

CHANGELOG="${1:?uso: insert-changelog-section.sh <changelog> <versão> <data> <corpo>}"
VERSION="${2:?versão obrigatória}"
DATE="${3:?data obrigatória}"
BODY_FILE="${4:?arquivo com o corpo da seção obrigatório}"

[[ -f "$CHANGELOG" ]] || {
  echo "CHANGELOG não encontrado: $CHANGELOG" >&2
  exit 1
}
[[ -f "$BODY_FILE" ]] || {
  echo "Arquivo de corpo não encontrado: $BODY_FILE" >&2
  exit 1
}
grep -q '^## \[Não lançado\]' "$CHANGELOG" || {
  echo "Seção '## [Não lançado]' não encontrada em $CHANGELOG" >&2
  exit 1
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v version="$VERSION" -v date="$DATE" -v bodyfile="$BODY_FILE" '
  function flush_section(   i, start, end) {
    print "## [" version "] - " date
    print ""

    # imprime o que já estava escrito à mão em [Não lançado], sem as linhas
    # em branco de sobra no início/fim
    start = 1
    end = n_captured
    while (start <= end && captured[start] == "") start++
    while (end >= start && captured[end] == "") end--
    if (end >= start) {
      for (i = start; i <= end; i++) print captured[i]
      print ""
    }

    while ((getline line < bodyfile) > 0) print line
  }

  BEGIN { state = "normal"; inserted = 0; n_captured = 0 }

  state == "normal" && /^## \[Não lançado\]/ && !inserted {
    print
    state = "capture"
    next
  }

  state == "capture" && /^## / {
    print ""
    flush_section()
    print ""
    print
    state = "normal"
    inserted = 1
    next
  }

  state == "capture" {
    captured[++n_captured] = $0
    next
  }

  { print }

  END {
    if (state == "capture") {
      print ""
      flush_section()
    }
  }
' "$CHANGELOG" >"$tmp"

mv "$tmp" "$CHANGELOG"
