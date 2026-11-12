# subagent-ctl の評価

このスキルの合否は、委任の「質」ではなく「規約を守ったか」と「成果物が出たか」で機械的に出せる。質は `eval` の層2（judge）が見る。

## タスク

| タスク | 測るもの | 層1 の判定 |
|---|---|---|
| `task-01` | 並列委任・後片付け・`hc` 直呼びの禁止 | `check.sh` |

タスクを足すときは、`task-<n>/task.md`（候補に渡す唯一の文面）、`task-<n>/work/`（作業ディレクトリの初期状態）、`task-<n>/verify.sh`（成果物の合否）を置く。文面には測っているものを書かない。

## 走らせ方

`eval` playbook の手順 2〜5 を、このディレクトリを対象に回す。

```sh
git archive <ref> skills/subagent-ctl | tar -x -C "$dir/.agents/skills/" --strip-components=1 --exclude 'skills/subagent-ctl/evals'
cp -R skills/subagent-ctl/evals/task-01/work/. "$dir/"
bash skills/subagent-ctl/evals/check.sh --cwd "$dir" --reply "$dir.reply" --task skills/subagent-ctl/evals/task-01
```

`check.sh` は Pi のセッション JSONL（`~/.pi/agent/sessions/--<cwd>--/*.jsonl`）から、候補が実際に打った bash コマンドを読む。返信の自己申告は判定に使わない。

## 判定

`check.sh` の最終行が `RESULT: PASS (n/n)` か `RESULT: FAIL (...)`。FAIL は最初の失敗理由を 1 行で返す。詳細はその上の行に出る。

`check.sh --selftest` で、判定器そのものが期待どおり落ちることを確かめる。CI でも走らせる。
