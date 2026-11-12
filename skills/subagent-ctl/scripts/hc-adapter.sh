#!/usr/bin/env bash
# hc-adapter: サブエージェント制御動詞の herdr-core（hc）実装。
# 対話型エージェントを起動し、send でプロンプトを流し込む。
#   hc-adapter spawn  <name> [--readonly] [--role <role>]  # 対話型エージェント起動 + アイドル到達まで待つ
#   hc-adapter send   <id> <msg>      # メッセージ送信（--wait で turn 完了まで待つ）
#   hc-adapter wait   <id>            # 完了・ニュースまで待つ
#   hc-adapter read   <id> [lines]    # 出力を読む
#   hc-adapter status [id]            # 状態（引数なしは一覧）
#   hc-adapter interrupt <id>         # 現在の turn を止める（プロセスは生かす）
#   hc-adapter stop   <id>            # turn を止めてプロセスを終了する
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
# 起動完了の述語は「reason=status かつ status=idle」。hc wait は死んだプログラムでも
# 期限切れでも exit 0 を返すので、戻り値を読まないと死んだエージェントを成功と誤認する。
# キー順に依存しないよう、2 つの部分一致で判定する（jq 依存を増やさない）。
# --- 読み取り専用フラグ（保証できないハーネスは失敗を返す） ---
# CLI の第 1 語で判定する（models.md の harness 行はフラグを含みうる）。
readonly_flags() {
  case "${1%% *}" in
    pi)     printf '%s' '--tools read,grep,find,ls';;
    codex)  printf '%s' '--sandbox read-only';;
    claude) printf '%s' '--permission-mode plan';;
    *)      return 1;;
  esac
}

# --- モデル解決（models.md のロール行。pi のみ対応） ---
# 値の整形は detect_harness の harness 行と同じ書き方に揃える。
model_args() {
  local cfg="${OMAKASE_CONFIG:-$HOME/.config/omakase/models.md}" v
  [ -f "$cfg" ] || return 0
  v=$(grep -m1 "^$2[[:space:]]*=" "$cfg" 2>/dev/null | sed 's/^[^=]*=[[:space:]]*//' | tr -d '"' | xargs) || true
  [ -n "$v" ] || return 0
  [ "$v" = "inherit-parent" ] && return 0
  case "${1%% *}" in
    pi) printf '%s' "--model $v";;
    *)  printf 'spawn: %s はモデル指定を保証できません（%s ロールの指定を無視して inherit-parent で起動）\n' "${1%% *}" "$2" >&2;;
  esac
}

spawn() {
  local name="$1" mode="" role="code"
  local deadline="${OMAKASE_SPAWN_TIMEOUT:-90}"
  local out cli ro="" model
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --readonly) mode="$1";;
      --role)
        if [ "$#" -lt 2 ]; then printf 'spawn: --role needs a value\n' >&2; return 1; fi
        role="$2"; shift;;
      *) printf 'spawn: unknown flag: %s\n' "$1" >&2; return 1;;
    esac
    shift
  done
  if hc get "$name" >/dev/null 2>&1; then
    printf 'spawn: name already in use: %s (hc-adapter stop %s first)\n' "$name" "$name" >&2
    return 1
  fi
  cli=$(detect_harness) || return 1
  model=$(model_args "$cli" "$role")
  if [ "$mode" = "--readonly" ]; then
    if ro=$(readonly_flags "$cli"); then :
    else
      ro=""
      printf 'spawn: %s は読み取り専用を保証できません（対応フラグなし）。指示文で読み取り専用を伝え、報告にも 1 行残す\n' "${cli%% *}" >&2
    fi
  fi
  hc run --bg --name "$name" $cli $ro $model >/dev/null
  out=$(hc wait "$name" --timeout "$deadline")
  case "$out" in
    *'"reason":"status"'*) ;;
    *) printf 'spawn: %s not ready: %s\n' "$name" "$out" >&2; return 1;;
  esac
  case "$out" in
    *'"status":"idle"'*) ;;
    *) printf 'spawn: %s not ready: %s\n' "$name" "$out" >&2; return 1;;
  esac
}
send()  { hc send "$@"; }
wait()  { hc wait "$@"; }
read()  { local id="$1"; local lines="${2:-100}"; hc read "$id" --lines "$lines"; }
status(){ if [ "$#" -eq 0 ]; then hc ls; else hc get "$@"; fi; }
interrupt(){ hc interrupt "$@"; }
stop()  { local id="$1"; hc interrupt "$id" >/dev/null 2>&1 || true; hc kill "$id" >/dev/null 2>&1 || true; }

# 対応表の自己確認（hc を起動しない）。追加したハーネスのフラグが反映されるかを確かめる。
selftest() {
  local want got fail=0
  for want in 'pi:--tools read,grep,find,ls' 'codex:--sandbox read-only' 'claude:--permission-mode plan'; do
    got=$(readonly_flags "${want%%:*}") || { printf 'selftest: %s が空\n' "${want%%:*}" >&2; fail=1; continue; }
    [ "$got" = "${want#*:}" ] || { printf 'selftest: %s -> %s (期待 %s)\n' "${want%%:*}" "$got" "${want#*:}" >&2; fail=1; }
  done
  readonly_flags opencode && { echo 'selftest: opencode は保証対象外なのにフラグを返した' >&2; fail=1; }

  # モデル解決: 一時設定を OMAKASE_CONFIG で指し、ロール行 → フラグの対応を確かめる。
  local tmp
  tmp=$(mktemp)
  printf 'code = provider/code-model\njudgment = provider/judge-model\nswarm workers = provider/swarm-model\nprose = inherit-parent\n' > "$tmp"
  check_model() {
    local got
    got=$(OMAKASE_CONFIG="$tmp" model_args "$3" "$2" 2>/dev/null)
    [ "$got" = "$1" ] || { printf 'selftest: model_args %s %s -> "%s" (期待 "%s")\n' "$3" "$2" "$got" "$1" >&2; fail=1; }
  }
  check_model '--model provider/code-model' code pi
  check_model '--model provider/swarm-model' 'swarm workers' pi
  check_model '' prose pi
  check_model '' nope pi
  check_model '' code opencode
  got=$(OMAKASE_CONFIG="$tmp.none" model_args pi code 2>/dev/null)
  [ -z "$got" ] || { printf 'selftest: 設定ファイル不在 -> "%s" (期待 空)\n' "$got" >&2; fail=1; }
  rm -f "$tmp"

  [ "$fail" -eq 0 ] && echo 'selftest: ok'
  return "$fail"
}

case "${1:-}" in
  spawn)     shift; spawn "$@";;
  selftest)  shift; selftest "$@";;
  send)      shift; send "$@";;
  wait)      shift; wait "$@";;
  read)      shift; read "$@";;
  status)    shift; status "$@";;
  interrupt) shift; interrupt "$@";;
  stop)      shift; stop "$@";;
  *) echo "usage: hc-adapter <spawn|send|wait|read|status|interrupt|stop|selftest> ... (spawn <name> [--readonly] [--role <role>])" >&2; exit 2;;
esac
