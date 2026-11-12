#!/usr/bin/env bash
# omakase の層1（機械判定）。タスクの verify.sh を走らせ、最終行に RESULT を出す。
#   check.sh --cwd <作業ディレクトリ> --task <task ディレクトリ>
#   check.sh --selftest
set -uo pipefail

main() {
  local cwd="" task=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --cwd) cwd="$2"; shift 2;;
      --task) task="$2"; shift 2;;
      *) printf 'usage: check.sh --cwd <dir> --task <dir>\n' >&2; return 2;;
    esac
  done
  [ -d "${cwd:-}" ] && [ -n "${task:-}" ] || { printf 'RESULT: FAIL (no --cwd or --task)\n'; return 1; }

  local out status
  out=$(bash "$task/verify.sh" "$cwd" 2>&1); status=$?
  printf '%s\n' "$out"
  if [ "$status" -eq 0 ]; then printf 'RESULT: PASS (1/1)\n'; return 0; fi
  printf 'RESULT: FAIL (%s)\n' "$(printf '%s' "$out" | tail -1)"
  return 1
}

selftest() {
  local root; root=$(mktemp -d)
  local dir="$root/case" ok=0 bad=0
  local task="$root/task"
  mkdir -p "$task" "$dir/skills/pdf-tools"
  cp "$(dirname "$0")/task-01/verify.sh" "$task/verify.sh"

  cp "$(dirname "$0")/task-01/work/skills/pdf-tools/SKILL.md" "$dir/skills/pdf-tools/SKILL.md"
  bash "$0" --cwd "$dir" --task "$task" >/dev/null 2>&1
  if [ "$?" -ne 0 ]; then ok=$((ok + 1)); printf 'ok   元のまま -> fail\n'; else bad=$((bad + 1)); printf 'FAIL 元のまま -> pass\n'; fi

  sed -i '' 's/^description: PDF を扱うスキル。$/description: 請求書 PDF から金額・日付・取引先を抜き出して JSON Lines にするときに使う。/' "$dir/skills/pdf-tools/SKILL.md"
  bash "$0" --cwd "$dir" --task "$task" >/dev/null 2>&1
  if [ "$?" -eq 0 ]; then ok=$((ok + 1)); printf 'ok   description を直した -> pass\n'; else bad=$((bad + 1)); printf 'FAIL description を直した -> fail\n'; fi

  rm -rf "$root"
  if [ "$bad" -eq 0 ]; then printf 'selftest: ok (%s)\n' "$ok"; return 0; fi
  printf 'selftest: %s 件失敗\n' "$bad"; return 1
}

case "${1:-}" in
  --selftest) selftest;;
  *) main "$@";;
esac
