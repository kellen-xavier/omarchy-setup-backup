#!/usr/bin/env bash
#
# Gera bullets de changelog (agrupados como no Keep a Changelog) a partir de
# commits em formato Conventional Commits, entre duas refs do git.
#
# Uso: conventional-notes.sh [ref-desde] [ref-até=HEAD]
#   conventional-notes.sh v2026.08.01 HEAD
#   conventional-notes.sh ""          HEAD   # desde o início do histórico
set -euo pipefail

SINCE="${1:-}"
UNTIL="${2:-HEAD}"

RANGE="$UNTIL"
[[ -n "$SINCE" ]] && RANGE="$SINCE..$UNTIL"

declare -A GROUP_OF=(
  [feat]="Added"
  [fix]="Fixed"
  [perf]="Changed"
  [refactor]="Changed"
  [style]="Changed"
  [chore]="Changed"
  [build]="Changed"
  [ci]="Changed"
  [docs]="Changed"
  [test]="Changed"
  [remove]="Removed"
  [revert]="Removed"
)

declare -A BUCKET=([Added]="" [Fixed]="" [Changed]="" [Removed]="")

while IFS='|' read -r hash subject; do
  [[ -z "$subject" ]] && continue
  [[ "$subject" == "Merge "* ]] && continue
  [[ "$subject" == *"[skip ci]"* ]] && continue
  [[ "$subject" == "chore(release):"* ]] && continue

  type="other"
  desc="$subject"
  if [[ "$subject" =~ ^([a-zA-Z]+)(\([^\)]*\))?!?:\ (.*)$ ]]; then
    type="$(tr '[:upper:]' '[:lower:]' <<<"${BASH_REMATCH[1]}")"
    desc="${BASH_REMATCH[3]}"
  fi
  section="${GROUP_OF[$type]:-Changed}"
  BUCKET["$section"]+="- ${desc} (${hash})"$'\n'
done < <(git log "$RANGE" --no-merges --pretty=tformat:'%h|%s')

any=0
for section in Added Fixed Changed Removed; do
  if [[ -n "${BUCKET[$section]}" ]]; then
    any=1
    printf '### %s\n\n%s\n' "$section" "${BUCKET[$section]}"
  fi
done

if [[ "$any" -eq 0 ]]; then
  echo "_Sem mudanças notáveis desde a última release._"
fi
