#!/usr/bin/env bash
# show-me-your-work 決定ログ（TSV）へ整った行を追記する。
# 使い方: log.sh <logfile> <phase> <decision> <why> <evidence> <result>
set -euo pipefail

if [ "$#" -ne 6 ]; then
	printf 'usage: log.sh <logfile> <phase> <decision> <why> <evidence> <result>\n' >&2
	exit 1
fi

logfile="$1"
shift

logdir="$(dirname "$logfile")"
if [ -n "$logdir" ] && [ "$logdir" != "." ] && [ ! -d "$logdir" ]; then
	mkdir -p "$logdir"
fi

# ここは必ず >> で追記する。> にしてはいけない。ネットワークマウントでは
# 存在チェックが誤判定しうる。そのときの代償はヘッダ 1 行の重複であり、行の消失ではない。
if [ ! -s "$logfile" ]; then
	printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' >> "$logfile"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# タブ・改行・CR を除去してセルを単一行に保ち、スプレッドシートが数式として解釈しうる
# 先頭文字（= + - @）にはシングルクォートを前置する。レビュー担当者がファイルを開いたとき、
# 攻撃者が仕込める文字列（PR タイトル、ファイル名、生成テキスト）が数式実行にならないための処置。
clean() {
	local v
	v=$(printf '%s' "$1" | tr '\t\n\r' '   ')
	case "$v" in
		=*|+*|-*|@*) printf "'%s" "$v" ;;
		*) printf '%s' "$v" ;;
	esac
}
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
	"$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" \
	>> "$logfile"
