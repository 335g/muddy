---
name: subagent-ctl
description: サブエージェントの制御（生成・送信・待受・読取・状態・中断）を薄い動詞セットに集約したインターフェース。実行基盤は herdr-core（hc）。エージェントは対話型で起動し、send でプロンプトを流し込む。スキル/プレイブックはこの動詞だけを呼ぶ。
---

# サブエージェント制御（subagent-ctl）

サブエージェントの制御は、この 6 動詞だけを使う。実行基盤は herdr-core（`hc`）。`hc` を直接呼ばない。実行基盤を替えるとき（herdr-core → Rex 等）は、このスキルの動詞の実装だけを書き換える。

## 動詞

| 動詞 | 意味 | hc での実装 |
|------|------|------------|
| `spawn(name)` | 対話型エージェントを起動して起動完了まで待つ | `hc run --bg --name <name> <harness-cli>` → `hc wait <name>` |
| `send(id, msg)` | 実行中のエージェントにメッセージ（初回タスク含む）を送る | `hc send <id> "<msg>"`（turn 完了まで待つなら `--wait`） |
| `wait(id)` | 完了・ニュースまで待つ | `hc wait <id>` / `hc wait --children any\|all` |
| `read(id, lines)` | 出力を読む | `hc read <id> --lines <lines>` |
| `status(id?)` | 状態を取得（引数なしは一覧） | `hc get <id>` / `hc ls` |
| `interrupt(id)` | 現在の turn を止める（プロセスは生かす。pause のトリガー） | `hc interrupt <id>` |

補助: `scripts/hc-adapter.sh` がこの動詞を薄く包む。

## spawn の手順（対話型）

1. `spawn(name)` はタスクを渡さず、**対話型**エージェントを起動する（非対話フラグを付けない）。
2. 起動直後の `send` は落ちることがあるので、`hc wait <name>` で起動完了（trust ダイアログ等）を待つ。
3. 初回タスクは `send(id, task)` で投入する。以降の指示・ステアリングも `send`。
4. turn を止めたいときは `interrupt(id)`。プロセスは生きているので、`send` で再開・指示できる。

## ハーネス CLI 検出（3 段）

`spawn` の `<harness-cli>` を次の順で決める。**対話型で起動する**。

1. `~/.config/omakase/models.md` の `# harness` に明示があれば最優先。
2. 無ければ、いま自分を起動しているハーネスを環境変数マーカーで自動検出。
3. 検出不能なら PATH にあるハーネス CLI を順に探索。それも無ければ 1 回だけ人に聞く（`contact_supervisor`）。

## 検出テーブル（保守用。ハーネス追加は 1 行）

| マーカー | ハーネス | 起動コマンド（対話型） |
|----------|----------|------------------------|
| `PI_*` | Pi | `pi` |
| `OPENCODE_*` | OpenCode | `opencode` |
| `CODEX_*` | Codex | `codex` |
| `CLAUDE_*` / `ANTHROPIC_*` | Claude Code | `claude` |

モデル指定フラグ（`pi --provider <p> --model <m> --thinking <level>` 等）は、導入時に実機確認して `spawn` へ渡せるようにする。

## ルール

- スキル・プレイブックはこの 6 動詞だけを呼び、`hc` を直接呼ばない（差し替え耐性）。
- サブエージェントにはこのスキルを読ませ、委任・報告・後片付けの手順を共有する。
- 実行基盤を替える場合は、このスキルと `scripts/hc-adapter.sh` だけを書き換える。呼び出し側は変えない。
