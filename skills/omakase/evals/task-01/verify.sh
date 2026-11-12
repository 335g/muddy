#!/usr/bin/env bash
# 層1: スキルが選ばれないとき、ルーティングを決める description を直したか。
# 「変わった中身が良いか」は見ない（層2 か人が見る）。
set -uo pipefail

ORIGINAL="PDF を扱うスキル。"

dir="$1"
file="$dir/skills/pdf-tools/SKILL.md"

if [ ! -f "$file" ]; then
  echo "FAIL SKILL.md が無い: $file"
  exit 1
fi

desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$file")
if [ -z "$desc" ]; then
  echo "FAIL description が無い"
  exit 1
fi
if [ "$desc" = "$ORIGINAL" ]; then
  echo "FAIL description が変わっていない（本文だけを直した）"
  exit 1
fi

echo "ok description が変わった: $desc"
exit 0
