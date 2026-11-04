#!/usr/bin/env bash
# hc-adapter: サブエージェント制御動詞の herdr-core（hc）実装。
# 対話型エージェントを起動し、send でプロンプトを流し込む。
#   hc-adapter spawn  <name>          # 対話型エージェント起動 + 起動完了待ち
#   hc-adapter send   <id> <msg>      # メッセージ送信（--wait で turn 完了まで待つ）
#   hc-adapter wait   <id>            # 完了・ニュースまで待つ
#   hc-adapter read   <id> [lines]    # 出力を読む
#   hc-adapter status [id]            # 状態（引数なしは一覧）
#   hc-adapter interrupt <id>         # 現在の turn を止める（プロセスは生かす）
set -euo pipefail

# --- ハーネス CLI 検出（3 段） ---
detect_harness() {
  local cfg="${OMAKASE_CONFIG:-$HOME/.config/omakase/models.md}"
  if [ -f "$cfg" ]; then
    local h
    h=$(grep -m1 '^harness' "$cfg" 2>/dev/null | sed 's/^harness *= *//' | tr -d '"' | xargs)
    [ -n "$h" ] && { echo "$h"; return 0; }
  fi
  if env | grep -q '^PI_';                then echo "pi";       return 0; fi
  if env | grep -q '^OPENCODE_';          then echo "opencode"; return 0; fi
  if env | grep -q '^CODEX_';             then echo "codex";    return 0; fi
  if env | grep -qE '^(CLAUDE_|ANTHROPIC_)'; then echo "claude"; return 0; fi
  for c in pi opencode codex claude; do
    if command -v "$c" >/dev/null 2>&1; then echo "$c"; return 0; fi
  done
  echo "error: ハーネス CLI を検出できません。models.md に harness を指定してください" >&2
  return 1
}

# --- 動詞 ---
# shellcheck disable=SC2046  # harness CLI（フラグ含む）の意図的な単語分割
spawn() { local name="$1"; hc run --bg --name "$name" $(detect_harness); hc wait "$name"; }
send()  { hc send "$@"; }
wait()  { hc wait "$@"; }
read()  { local id="$1"; local lines="${2:-100}"; hc read "$id" --lines "$lines"; }
status(){ if [ "$#" -eq 0 ]; then hc ls; else hc get "$@"; fi; }
interrupt(){ hc interrupt "$@"; }

case "${1:-}" in
  spawn)     shift; spawn "$@";;
  send)      shift; send "$@";;
  wait)      shift; wait "$@";;
  read)      shift; read "$@";;
  status)    shift; status "$@";;
  interrupt) shift; interrupt "$@";;
  *) echo "usage: hc-adapter <spawn|send|wait|read|status|interrupt> ..." >&2; exit 2;;
esac
