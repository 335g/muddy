# muddy

Human out of the loop —— 人による補助なしで自律的に開発が進む状態を実現するための、エージェントスキル集です。Pi をハーネスに、サブエージェント基盤には herdr-core を使います。pstack（Cursor のエージェントスタイル集）の仕組みを、ハーネス非依存・日本語・OSS 配布を前提に再実装したものです。

## 特徴

- **入口ルーター `omakase`** — タスクを 9 種類のプレイブックへ振り分け、原則・自律許可・委任規則を適用する。
- **自律許可の明文化** — 「進めてよいこと」と「常に止まること」（force-push / deploy / データ削除 / 外部発信）を明示。
- **サブエージェント制御 `subagent-ctl`** — 生成・送信・待受・読取・状態・中断の 6 動詞に集約。herdr-core 上で対話型エージェントを起動し、`hc send` でプロンプトを流し込む。
- **決定ログ `show-me-your-work`** — 1 決定 1 行の TSV。人が離れた後でも監査できる。
- **並列検証 `swarm`** — N ワーカーを張って回収し、PASS/ISSUES/BLOCKED + 証拠で報告させる。
- **継続改善 `reflect` / `correct`** — 会話から学びを採掘し、繰り返すミスを構造で不可能にする。

## 要件

- [Pi](https://pi.dev)（エージェントハーネス）
- [herdr-core](https://herdr.dev/core/)（`hc`。サブエージェントの永続端末ランタイム）
- [`gh`](https://cli.github.com/)（GitHub の PR 操作）/ [`tea`](https://gitea.com/gitea/tea)（Gitea の PR 操作。オンプレの場合）

## インストール

Pi パッケージとしてインストールします:

```sh
pi install git:github.com/335g/muddy
# またはローカルパス
pi install ./muddy
```

インストール後、`/reload` でスキルが読み込まれます。

## 使い方

タスクの最初に `/omakase` を付け、**目標と完了条件**を伝えるだけです。

```text
/omakase この PR にスクロールが毎 750ms ずれるバグがある。repro してから直して検証して。
```

```text
/omakase 寝てくる。このスタックを全部マージして。CI が flake っても進めて。
```

```text
/omakase calc に multiply 関数とテストを追加して。完了条件は python3 test_calc.py が OK を出力すること。
```

omakase がタスクをプレイブックへ振り分け、todo にステップを展開し、必要なスキルを呼びます。

## 構成

```
skills/
├── omakase/                入口ルーター
│   └── playbooks/          プレイブック 9 種
│       ├── feature.md      新規実装・挙動変更
│       ├── bug-fix.md      バグ修正（repro が先）
│       ├── refactoring.md  構造変更（挙動は変えない）
│       ├── opening-a-pr.md 他プレイブックの終端（PR を開く）
│       ├── pause-safely.md 中断して再開可能にする
│       ├── session-pickup.md 前回の続きを再開する
│       ├── autonomous-run.md 完了条件まで回し続ける
│       ├── orchestrate.md  複数 PR・複数日を 1 コーディネータで
│       └── autopilot-stack.md 自動 build+verify、merge は人手
├── subagent-ctl/           サブエージェント制御（6 動詞 + hc-adapter.sh）
├── show-me-your-work/      決定ログ（TSV + log.sh）
├── swarm/                  並列検証
├── figure-it-out/          型に合わない仕事を自前プレイブック化
├── reflect/                会話から学びをスキル編集へ
├── correct/                繰り返すミスを構造で不可能に
└── principle-* × 6         判断の原則
```

## アーキテクチャ

### サブエージェント制御（subagent-ctl）

サブエージェントは herdr-core の永続端末で**対話型**に起動し、`hc send` でプロンプトを流し込みます。非対話フラグ（`pi -p` 等）は使いません。

| 動詞 | 意味 |
|------|------|
| `spawn(name)` | 対話型エージェントを起動して起動完了まで待つ |
| `send(id, msg)` | メッセージ（初回タスク含む）を送る |
| `wait(id)` | 完了・ニュースまで待つ |
| `read(id, lines)` | 出力を読む |
| `status(id?)` | 状態を取得 |
| `interrupt(id)` | 現在の turn を止める（pause のトリガー） |

ハーネス CLI は環境変数マーカーで自動検出します（Pi / OpenCode / Codex / Claude Code）。実行基盤を herdr-core から別のものに替えても、この 6 動詞を実装し直すだけで呼び出し側は変わりません。

### モデルロール

スキル本文に具体モデル名を書きません。ロール（`code` / `judgment` / `prose` / `swarm workers`）だけを参照し、環境ごとの上書きファイルで解決します。既定値は inherit-parent（親チャットのモデル）。判定・検証（`judgment`）は code と別ファミリーにするのが設計原則です。

## 設定

`~/.config/omakase/models.md`（未コミットのユーザー環境ファイル）:

```markdown
# harness（任意。無ければ自動検出）
harness = "pi"

# forge（任意。無ければ git remote のホストから自動検出）
forge = "github"  # または "gitea"

# roles（1 行 1 ロール。無ければ inherit-parent）
code = inherit-parent
judgment = <code と別ファミリーのモデル識別子>
prose = inherit-parent
swarm workers = inherit-parent
```

## ライセンス

[MIT](./LICENSE)
