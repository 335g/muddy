# omakase の評価

プレイブックの合否は、成果物の形で機械的に出せるものだけを層1 にする。「良い文章か」は層2（judge）か人が見る。

## タスク

| タスク | 測るもの | 層1 の判定 |
|---|---|---|
| `task-01` | スキルが選ばれないとき、`description` を直すか | `check.sh` |

## 走らせ方

`eval` playbook の手順 2〜5 を、このディレクトリを対象に回す。**スキルを候補に渡すときは `evals/` を除く**（タスク文と判定器が見えると評価が壊れる）。

```sh
git archive <ref> skills/omakase | tar -x -C "$dir/.agents/skills" --strip-components=1 --exclude 'skills/omakase/evals'
cp -R skills/omakase/evals/task-01/work/. "$dir/"
bash skills/omakase/evals/check.sh --cwd "$dir" --reply "$dir.reply" --task skills/omakase/evals/task-01
```

## 判定

最終行が `RESULT: PASS (n/n)` か `RESULT: FAIL (理由)`。`check.sh --selftest` で判定器自体を確かめる。

層1 は「`description` 行が変わったか」だけを見る。**変わった中身が良いかは見ない。** それは層2 か人が見る。この 1 ビットで足りるのは、直すべき場所を取り違えるかどうかが今回の争点だからで、文章の質を測るタスクを足すときは層2 を用意する。
