#!/usr/bin/env bash
# 成果物の合否: 候補の作業ディレクトリで run.sh が通るか。
cd "$1" && sh run.sh >/dev/null 2>&1
