#!/usr/bin/env bash
# subagent-ctl の層1（機械判定）。規約の遵守と成果物を検査する。
#   check.sh --cwd <作業ディレクトリ> --reply <返信ファイル> [--task <task ディレクトリ>]
#   check.sh --selftest
# 出力: 詳細行のあと、最終行に RESULT: PASS (n/n) か RESULT: FAIL (理由)。
set -uo pipefail

sessions_root() { printf '%s' "${PI_SESSIONS:-$HOME/.pi/agent/sessions}"; }

# Pi のセッションは cwd から slug を作る。先頭の / を落として / を - に置き換える。
# macOS では /tmp が /private/tmp に解決されるので、実パスでも探す。
slug_of() { printf '%s' "${1#/}" | sed 's|/|-|g'; }

transcript() {
  local dir="$1" cand found
  for cand in "$dir" "$(cd "$dir" 2>/dev/null && pwd -P)"; do
    found=$(ls -t "$(sessions_root)/--$(slug_of "$cand")--"/*.jsonl 2>/dev/null | head -1)
    if [ -n "$found" ]; then printf '%s' "$found"; return 0; fi
  done
  return 1
}

# transcript から、候補が実際に打った bash コマンドを数える。
# 自己申告ではなく、記録されたコマンドだけを見る。
protocol() {
  python3 - "$1" <<'PY'
import json, re, sys

spawn = stop = direct = 0
adapter = re.compile(r'hc-adapter(?:\.sh)?\s+(\w+)')
direct_re = re.compile(r'(?<![\w./-])hc\s+(run|send|wait|read|get|ls|kill|interrupt|events)\b')
try:
    lines = open(sys.argv[1], encoding="utf-8")
except OSError:
    print(0, 0, 0)
    raise SystemExit
for line in lines:
    try:
        entry = json.loads(line)
    except ValueError:
        continue
    for item in (entry.get("message") or {}).get("content") or []:
        if item.get("type") != "toolCall":
            continue
        command = (item.get("arguments") or {}).get("command")
        if not isinstance(command, str):
            continue
        verbs = adapter.findall(command)
        spawn += verbs.count("spawn")
        stop += verbs.count("stop")
        direct += len(direct_re.findall(command))
print(spawn, stop, direct)
PY
}

main() {
  local cwd="" reply="" task=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --cwd) cwd="$2"; shift 2;;
      --reply) reply="$2"; shift 2;;
      --task) task="$2"; shift 2;;
      *) printf 'usage: check.sh --cwd <dir> --reply <file> [--task <dir>]\n' >&2; return 2;;
    esac
  done
  [ -d "${cwd:-}" ] || { printf 'RESULT: FAIL (no --cwd)\n'; return 1; }
  [ -f "${reply:-}" ] || { printf 'RESULT: FAIL (no --reply)\n'; return 1; }

  local file; file=$(transcript "$cwd")
  local spawn stop direct
  # shellcheck disable=SC2046
  read -r spawn stop direct <<<"$(protocol "${file:-/dev/null}")"

  local detail="" total=0 fail=0 reason
  check() { total=$((total + 1)); if [ "$1" = ok ]; then detail+="ok   $2"$'\n'; else fail=$((fail + 1)); detail+="FAIL $2"$'\n'; reason="${reason:-$2}"; fi; }

  if [ -z "$file" ]; then
    check fail "transcript が見つからない（$(sessions_root)/--$(slug_of "$(cd "$cwd" && pwd -P)")--）"
  fi
  # 委任が無いときは、後片付けの判定は空振りする。数えない。
  if [ "$spawn" -ge 2 ]; then
    check ok "委任が 2 体以上（spawn ${spawn}）"
    if [ "$spawn" -eq "$stop" ]; then check ok "後片付け（spawn ${spawn} / stop ${stop}）"; else check fail "stop 漏れ（spawn ${spawn} / stop ${stop}）"; fi
  else
    check fail "委任が 2 体未満（spawn ${spawn}）"
  fi
  if [ "$direct" -eq 0 ]; then check ok "hc を直接呼んでいない"; else check fail "hc を直接呼んだ（${direct} 回）"; fi

  if [ -n "$task" ]; then
    if bash "$task/verify.sh" "$cwd" >/dev/null 2>&1; then check ok "成果物が通る（$task/verify.sh）"; else check fail "成果物が通らない（$task/verify.sh）"; fi
  fi

  printf '%s' "$detail"
  if [ "$fail" -eq 0 ]; then printf 'RESULT: PASS (%s/%s)\n' "$total" "$total"; return 0; fi
  printf 'RESULT: FAIL (%s)\n' "$reason"
  return 1
}

# 判定器そのものの確認。期待どおりの入力で、期待どおりに落ちるか。
selftest() {
  local root; root=$(mktemp -d)
  local dir="$root/case" ok=0 bad=0 slug
  mkdir -p "$dir/work" "$dir/task"
  slug="--$(slug_of "$dir/work")--"
  mkdir -p "$dir/sessions/$slug"

  # 規約を守った候補。
  cat >"$dir/good.jsonl" <<'JSON'
{"message":{"content":[{"type":"toolCall","arguments":{"command":"bash skills/subagent-ctl/scripts/hc-adapter.sh spawn w1"}},{"type":"toolCall","arguments":{"command":"bash skills/subagent-ctl/scripts/hc-adapter.sh spawn w2"}},{"type":"toolCall","arguments":{"command":"bash skills/subagent-ctl/scripts/hc-adapter.sh stop w1"}},{"type":"toolCall","arguments":{"command":"bash skills/subagent-ctl/scripts/hc-adapter.sh stop w2"}}]}}
JSON
  printf 'w1 reason=status, w2 reason=status\n' >"$dir/good.reply"

  # hc を直に呼び、stop を忘れた候補。
  cat >"$dir/bad.jsonl" <<'JSON'
{"message":{"content":[{"type":"toolCall","arguments":{"command":"hc run --bg --name w1 pi && hc send w1 hi"}}]}}
JSON
  printf 'done\n' >"$dir/bad.reply"

  printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/task/verify.sh"

  run_case() {  # $1 label, $2 expected pass/fail, $3 transcript, $4 reply
    local got
    cp "$3" "$dir/sessions/$slug/t.jsonl"
    PI_SESSIONS="$dir/sessions" bash "$0" --cwd "$dir/work" --reply "$4" --task "$dir/task" >/dev/null 2>&1
    got=$([ "$?" -eq 0 ] && echo pass || echo fail)
    if [ "$got" = "$2" ]; then ok=$((ok + 1)); printf 'ok   %s -> %s\n' "$1" "$got";
    else bad=$((bad + 1)); printf 'FAIL %s -> %s (期待 %s)\n' "$1" "$got" "$2"; fi
  }

  run_case good pass "$dir/good.jsonl" "$dir/good.reply"
  run_case bad fail "$dir/bad.jsonl" "$dir/bad.reply"
  rm -rf "$root"

  if [ "$bad" -eq 0 ]; then printf 'selftest: ok (%s)\n' "$ok"; return 0; fi
  printf 'selftest: %s 件失敗\n' "$bad"; return 1
}

case "${1:-}" in
  --selftest) selftest;;
  *) main "$@";;
esac
