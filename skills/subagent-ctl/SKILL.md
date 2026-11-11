---
name: subagent-ctl
description: サブエージェントの制御（生成・送信・待受・読取・状態・中断・終了）を薄い動詞セットに集約したインターフェース。実行基盤は herdr-core（hc）。エージェントは対話型で起動し、send でプロンプトを流し込む。スキル/プレイブックはこの動詞だけを呼ぶ。
---

# サブエージェント制御（subagent-ctl）

サブエージェントの制御は、この 7 動詞だけを使う。実行基盤は herdr-core（`hc`）。`hc` を直接呼ばない。実行基盤を替えるとき（herdr-core → Rex 等）は、このスキルの動詞の実装だけを書き換える。

## 動詞

| 動詞 | 意味 | hc での実装 |
|------|------|------------|
| `spawn(name, readonly?, role?)` | 対話型エージェントを起動し、アイドル到達まで待つ。既存名は失敗。`readonly` を付けると読み取り専用で起動する。`role` の既定は `code` | `hc run --bg --name <name> <harness-cli> [読み取り専用フラグ] [モデルフラグ]` → `hc wait <name> --timeout <N>` |
| `send(id, msg)` | 実行中のエージェントにメッセージ（初回タスク含む）を送る | `hc send <id> "<msg>"`（turn 完了まで待つなら `--wait`） |
| `wait(id)` | ターン終了・期限・脱落まで待つ。戻りの `reason` で分岐する（`status` / `timeout` / `exit` / `error` / `blocked`）。`--children` は hc の端末の中からのみ | `hc wait <id> --timeout <N>` / `hc wait --children any\|all` |
| `read(id, lines)` | 画面を読む（長い報告はファイルに書かせて読む） | `hc read <id> --lines <lines>` |
| `status(id?)` | 状態を取得（引数なしは一覧） | `hc get <id>` / `hc ls` |
| `interrupt(id)` | 現在の turn を止める（プロセスは生かす。pause のトリガー） | `hc interrupt <id>` |
| `stop(id)` | turn を止めてプロセスを終了する（後片付け） | `hc interrupt <id>` → `hc kill <id>` |

補助: `scripts/hc-adapter.sh` がこの動詞を薄く包む。待ちの既定は 90 秒（`OMAKASE_SPAWN_TIMEOUT` で変更）。読み取り専用フラグとモデル解決の対応表は `hc-adapter.sh selftest` で確かめられる。

## spawn の手順（対話型）

1. `spawn(name)` はタスクを渡さず、**対話型**エージェントを起動する（非対話フラグを付けない）。
2. **起動完了の述語は `reason=status` かつ `status=idle`。** `hc wait` は死んだプログラムでも
   期限切れでも exit 0 を返すので、戻り値を読まずに成功とみなしてはいけない。戻りが
   `exit` / `error` / `blocked` / `timeout` なら spawn の失敗として扱い、`hc get <name>` の
   状態を添えて報告する。
3. **名前は端末の id。** 既存名を渡すと `spawn` は失敗する（同名の端末が 2 つできると
   `send` の宛先が決まらない）。同じ名前を使い直したいときは先に `stop` する。
4. 初回タスクは `send(id, task)` で投入する。以降の指示・ステアリングも `send`。
5. turn を止めたいときは `interrupt(id)`。プロセスは生きているので、`send` で再開・指示できる。
6. 仕事が終わったら `stop(id)` でプロセスを終了する。`interrupt` だけではリソースが残る。

## ハーネス CLI 検出（3 段）

`spawn` の `<harness-cli>` を次の順で決める。**対話型で起動する**。

1. `~/.config/omakase/models.md` の `# harness` に明示があれば最優先。
2. 無ければ、いま自分を起動しているハーネスを環境変数マーカーで自動検出。
3. 検出不能なら PATH にあるハーネス CLI を順に探索。それも無ければ 1 回だけ人に聞く（`contact_supervisor`）。

## 検出テーブル（保守用。ハーネス追加は 1 行）

| マーカー | ハーネス | 起動コマンド（対話型） | 読み取り専用フラグ |
|----------|----------|------------------------|--------------------|
| `PI_*` | Pi | `pi` | `--tools read,grep,find,ls` |
| `OPENCODE_*` | OpenCode | `opencode` | なし（保証しない） |
| `CODEX_*` | Codex | `codex` | `--sandbox read-only` |
| `CLAUDE_*` / `ANTHROPIC_*` | Claude Code | `claude` | `--permission-mode plan` |

Pi 以外のフラグは実機で未検証。読み取り専用フラグが無いハーネスでは、`spawn --readonly` は警告を出して通常起動に落ちる（保証しない）。その場合は指示文で読み取り専用を伝え、報告に「読み取り専用は未保証」と 1 行残す。

モデルの指定は `spawn --role <role>` で行う。ロールの値は `~/.config/omakase/models.md` の同名の行を読む（`code` / `judgment` / `prose` / `swarm workers`）。既定のロールは `code`。行が無い、値が空、値が `inherit-parent` のときはモデルを指定せず、親チャットのモデルを継承する。

モデルフラグを渡せるのは `pi` だけ（`pi --model <provider/id>`）。pi 以外のハーネスはモデル指定が実機未検証なので、`spawn` は警告を 1 行出して指定を無視する（親のモデルで起動する）。

## ルール

- スキル・プレイブックはこの 7 動詞だけを呼び、`hc` を直接呼ばない（差し替え耐性）。
- サブエージェントにはこのスキルを読ませ、委任・報告・後片付けの手順を共有する。
- 実行基盤を替える場合は、このスキルと `scripts/hc-adapter.sh` だけを書き換える。呼び出し側は変えない。
