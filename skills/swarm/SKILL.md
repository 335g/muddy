---
name: swarm
description: N 個の並列ワーカーを張って回収し、1 つのレポートにまとめる。並列カバレッジ・レース・ガントレット・探索の分割に使う。ワーカーは PASS/ISSUES/BLOCKED + 証拠で報告する。
---

# Swarm（並列検証）

## Start

開始前に、フェーズごとに 1 項目の todolist を開く。

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. 完了述語と、swarm が返すべき artifact・レポートを宣言する。
2. 形を選ぶ。スライスに分割 / 同一 brief で N ワーカーを競わせる / 混合。競わせる場合は `first pass` / `rank all` / `best-of` を先に宣言する。
3. ワーカーのモデルは `swarm workers` ロール（`docs/model-roles.md`）。
4. 各ワーカーに、書くときは自分の書き込み先を与える。コミットを検証・計測する場合、brief は正確な SHA を名指しする。計測 brief は方法（サンプル数・1 サンプルとは何か・順序）も名指す。ワーカーは結果に両方を記録する。

## Phase B: Fan out

N ワーカーを並列に起動する（`subagent-ctl` の `spawn` を N 回。モデルは `swarm workers` ロール）。隔離が必要な書き込みは `fleet_fork`（Pi のワークツリー）か、ワーカーごとの別 cwd で行う。読み取り専用の検証なら同一 cwd の別出力先でよい。

各 brief は自立していること。目標・範囲・正確なスライスまたはレース腕・検証方法・報告内容を含める。報告は `PASS` / `ISSUES` / `BLOCKED` + 証拠。欠陥を証明できたワーカーは `ISSUES` を報告し、最初の 1 件だけでなく証明できる全件を列挙する。

ワーカーが落ちたら N-1 で進み、その旨を記す。

## Phase C: Aggregate

終端の結果を読む。brief が名指した SHA と方法を記録しない結果は捨て、そのワーカーを 1 回だけ再起動する。2 回目も欠けたらギャップとして記録する。ギャップは合格に数えない。カバレッジでは、必要な全スライスに結果が要る。レースでは、先に宣言した規則（first pass / rank all / best-of）を適用する。生のワーカー出力を貼り付けない。

## Phase D: Report

1 つの統合レポートを返す。結果表、問題の 1 行要約、ギャップ・脱落、レース規則（使った場合）。
