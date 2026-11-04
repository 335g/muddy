---
name: subagent-ctl
description: サブエージェントの制御（生成・送信・待受・読取・状態）を 5 動詞に集約した薄いインターフェース。実行基盤は herdr-core（hc）、ハーネス CLI は自動検出。スキル/プレイブックはこの 5 動詞だけを呼ぶ。
---

# サブエージェント制御（subagent-ctl）

サブエージェントの制御は、この 5 動詞だけを使う。実行基盤は herdr-core（`hc`）。`hc` を直接呼ばない。実行基盤を替えるとき（herdr-core → Rex 等）は、このスキルの 5 動詞の実装だけを書き換える。

## 5 動詞

| 動詞 | 意味 | hc での実装 |
|------|------|------------|
| `spawn(name, task)` | バックグラウンドでサブエージェントを起動 | `hc run --bg --name <name> <harness-cli> "<task>"` |
| `send(id, msg)` | 実行中のサブエージェントに指示を送る | `hc send <id> "<msg>"` |
| `wait(id)` | 完了まで待つ（子全部なら `--children all`） | `hc wait <id>` |
| `read(id, lines)` | 出力を読む | `hc read <id> --lines <lines>` |
| `status(id?)` | 状態を取得（引数なしは一覧） | `hc get <id>` / `hc ls` |

補助: `scripts/hc-adapter.sh` がこの 5 動詞を薄く包む。`scripts/hc-adapter.sh spawn <name> <task>` のように使う。

## spawn のハーネス CLI 検出（3 段）

`spawn` は `<harness-cli>` を次の順で決める。

1. `~/.config/omakase/models.md` の `# harness` に明示があれば最優先。
2. 無ければ、いま自分を起動しているハーネスを環境変数マーカーで自動検出。
3. 検出不能なら PATH にあるハーネス CLI を順に探索。それも無ければ 1 回だけ人に聞く（`contact_supervisor`）。

## 検出テーブル（保守用。ハーネス追加は 1 行）

| マーカー | ハーネス | spawn で実行する CLI |
|----------|----------|---------------------|
| `PI_*` | Pi | `pi -ne` |
| `OPENCODE_*` | OpenCode | `opencode run` |
| `CODEX_*` | Codex | `codex exec` |
| `CLAUDE_*` / `ANTHROPIC_*` | Claude Code | `claude -p` |

各 CLI の非対話呼び出し形は、導入時に実機で確認してこの表を更新する（例: `pi -ne` が `pi run` かは環境次第）。

## ルール

- スキル・プレイブックはこの 5 動詞だけを呼び、`hc` を直接呼ばない（差し替え耐性）。
- サブエージェントにはこのスキルを読ませ、委任・報告・後片付けの手順を共有する。
- 実行基盤を替える場合は、このスキルの「5 動詞の実装」と `scripts/hc-adapter.sh` だけを書き換える。呼び出し側は変えない。
