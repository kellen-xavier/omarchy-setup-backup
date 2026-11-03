#!/usr/bin/env bash
#
# Insere uma nova seção de release logo abaixo de "## [Não lançado]" no
# CHANGELOG.md (formato Keep a Changelog), deixando a seção Unreleased vazia
# de novo por cima da seção recém-criada.
#
# Qualquer bullet já escrito à mão em [Não lançado] antes da release (prática
# normal deste repo) é preservado e MESCLADO com as notas geradas: para cada
# categoria (### Added, ### Fixed, ...) sai um único bloco, com os bullets
# escritos à mão antes dos gerados automaticamente — nunca dois blocos com o
# mesmo cabeçalho na mesma versão.
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
captured="$(mktemp)"
merged="$(mktemp)"
trap 'rm -f "$tmp" "$captured" "$merged"' EXIT

# 1) Extrai o corpo escrito manualmente em [Nao lancado] (entre o cabecalho e o
#    próximo "## ").
awk '
  /^## \[Não lançado\]/ { cap = 1; next }
  cap && /^## /          { cap = 0 }
  cap                    { print }
' "$CHANGELOG" >"$captured"

# 2) Mescla o conteúdo manual com as notas geradas num único bloco por
#    categoria. A ordem das categorias segue a primeira aparição (manual
#    primeiro, pois é concatenado antes); dentro de cada categoria os bullets
#    manuais vêm antes dos gerados. Linhas antes de qualquer "### " viram
#    preâmbulo (ex.: o aviso "Sem mudanças notáveis").
cat "$captured" "$BODY_FILE" | awk '
  /^### / {
    cat = $0
    if (!(cat in seen)) { seen[cat] = ++ncat; order[ncat] = cat }
    cur = cat
    next
  }
  {
    if (cur == "") { pre[++npre] = $0; next }
    bucket[cur] = bucket[cur] $0 "\n"
  }
  END {
    for (i = 1; i <= npre; i++) print pre[i]
    for (k = 1; k <= ncat; k++) {
      print order[k]
      print ""
      printf "%s", bucket[order[k]]
    }
  }
' >"$merged"

# 3) Reconstrói o CHANGELOG: mantém [Não lançado] vazia, descarta o corpo
#    manual antigo e insere a nova seção de versão com o bloco mesclado.
awk -v version="$VERSION" -v date="$DATE" -v mergedfile="$merged" '
  /^## \[Não lançado\]/ && !done {
    print
    print ""
    print "## [" version "] - " date
    print ""
    while ((getline line < mergedfile) > 0) print line
    close(mergedfile)
    cap = 1
    done = 1
    next
  }
  cap && /^## / { cap = 0 } # chegou na próxima seção já existente
  cap           { next }    # engole o corpo antigo de [Não lançado]
  { print }
' "$CHANGELOG" >"$tmp"

# 4) Normaliza: colapsa sequências de linhas em branco em uma só e remove as
#    linhas em branco do fim do arquivo (mantém idempotente entre releases).
awk '
  { lines[NR] = $0 }
  END {
    last = NR
    while (last > 0 && lines[last] == "") last--
    blank = 0
    for (i = 1; i <= last; i++) {
      if (lines[i] == "") {
        if (blank) continue
        blank = 1
      } else {
        blank = 0
      }
      print lines[i]
    }
  }
' "$tmp" >"$CHANGELOG"
