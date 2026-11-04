#!/usr/bin/env bash
# hc-adapter: サブエージェント制御 5 動詞の herdr-core（hc）実装
#   hc-adapter spawn  <name> <task>
#   hc-adapter send   <id> <msg>
#   hc-adapter wait   <id>
#   hc-adapter read   <id> [lines]
#   hc-adapter status [id]
set -euo pipefail

# --- ハーネス CLI 検出（3 段） ---
detect_harness() {
  local cfg="${OMAKASE_CONFIG:-$HOME/.config/omakase/models.md}"
  if [ -f "$cfg" ]; then
    local h
    h=$(grep -m1 '^harness' "$cfg" 2>/dev/null | sed 's/^harness *= *//' | tr -d '"' | xargs)
    [ -n "$h" ] && { echo "$h"; return 0; }
  fi
  if env | grep -q '^PI_';              then echo "pi -ne";       return 0; fi
  if env | grep -q '^OPENCODE_';        then echo "opencode run"; return 0; fi
  if env | grep -q '^CODEX_';           then echo "codex exec";   return 0; fi
  if env | grep -qE '^(CLAUDE_|ANTHROPIC_)'; then echo "claude -p"; return 0; fi
  for c in pi opencode codex claude; do
    if command -v "$c" >/dev/null 2>&1; then
      case "$c" in
        pi)       echo "pi -ne";;
        opencode) echo "opencode run";;
        codex)    echo "codex exec";;
        claude)   echo "claude -p";;
      esac
      return 0
    fi
  done
  echo "error: ハーネス CLI を検出できません。models.md に harness を指定してください" >&2
  return 1
}

# --- 5 動詞 ---
# shellcheck disable=SC2046  # harness CLI の意図的な単語分割
spawn() { local name="$1"; shift; hc run --bg --name "$name" $(detect_harness) "$@"; }
send()  { hc send "$@"; }
wait()  { hc wait "$@"; }
read()  { local id="$1"; local lines="${2:-100}"; hc read "$id" --lines "$lines"; }
status(){ if [ "$#" -eq 0 ]; then hc ls; else hc get "$@"; fi; }

case "${1:-}" in
  spawn)  shift; spawn  "$@";;
  send)   shift; send   "$@";;
  wait)   shift; wait   "$@";;
  read)   shift; read   "$@";;
  status) shift; status "$@";;
  *) echo "usage: hc-adapter <spawn|send|wait|read|status> ..." >&2; exit 2;;
esac
