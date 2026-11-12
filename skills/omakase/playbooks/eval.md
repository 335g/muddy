# Eval

**実験の設計は自分が持つ。計画し、ブラインドし、走らせ、統合する。**

評価は「良くなったか」を測る。マージするかは別の判断で、最後は人が決める。

## ブラインドの非交渉事項

- 候補が見るディレクトリ・ファイル・プロンプトに、`eval` / `test` / `judge` / `experiment` / `rubric` / `score` / `compare` / `benchmark` / `candidate` / `arena` を入れない。`test` はタスク自体がテストを走らせる場合だけ許す。
- 候補へのプロンプトは、普通のユーザー依頼の形にする。目標を書き、測っているものを書かない。
- 適用したスキルや原則を列挙させない。読み取ったファイルと成果物の形から判定する。
- ディレクトリ名・スラッグは、利用者が付けそうなプロジェクト名にする。
- 他の候補の存在を伝えない。候補は同時に走らせない。
- judge は判定していると知ってよい。見るのは匿名ラベルだけで、モデル名も variant 名も見せない。
- 2 つの variant を比べるときは、judge 1 体が両方を同じ尺度で 1 回で採点する。

## 固定タスクセット

毎回タスクを作らない。`skills/<skill>/evals/` にタスクを置き、variant 間で同じタスクを使う。前回と同じタスクで比べられることが、drift を検出する唯一の手段になる。

タスクを変えるときは、理由を TSV に 1 行残し、baseline を取り直す。`skills/subagent-ctl/evals/` が最初の例。

## 手順

1. **Frame。** variant を 2 つ決める（A = 基準の ref、B = 変更の ref）。初回は B が無いので A だけ走らせ、その結果を baseline として TSV に残す。成功の定義を rubric 3〜6 項目で書く。rubric は judge にだけ渡す。
2. **環境。** 候補ごとに作業ディレクトリを作る。スキルとタスクを ref から展開する:

   ```sh
   git archive <ref> skills/<skill> | tar -x -C <dir>/.agents/skills/ --strip-components=1 --exclude 'skills/<skill>/evals'
   cp -R skills/<skill>/evals/<task>/work/. <dir>/
   ```

   `evals/` を除く。タスク文と判定器が候補に見えると、評価そのものが壊れる。

3. **プロンプト。** `evals/<task>/task.md` の文面をそのまま使う。質問を足さない。
4. **走らせる。** `subagent-ctl` で variant ごとに 1 体。モデルは `code` ロール。1 体ずつ、別のディレクトリで。`disable-model-invocation: true` のスキル（`omakase` など）は自動で選ばれないので、`/skill:<name> <依頼>` の形で送る。初回起動は信頼の確認で止まるので、`spawn` が `reason: timeout` で返ったら `hc read <id>` で画面を見て `hc keys <id> enter` を送る。
5. **層1 機械判定。** `skills/<skill>/evals/check.sh --cwd <dir> --reply <返信>` を各候補に走らせる。規約の遵守と成果物の合否は、ここで機械的に出る。
6. **層2 判定。** `judgment` ロール（`code` とは別ファミリー）の judge 1 体。ラベル A / B で匿名化し、rubric・層1 の結果・候補の返信・成果物の diff を渡す。返信だけでは委任の質は測れない。別ファミリーを用意できないときは、独立性を主張せず、その旨を報告に 1 行書く。
7. **自分で全出力を読む。** judge と食い違ったら、判定をやり直さない。`inconclusive` と書いて人に渡す。
8. **記録。** `show-me-your-work` の TSV に `phase = eval` で 1 行。evidence は候補ディレクトリ、check.sh の出力、judge の verdict。

## 決定規則

人が読む前に、AI が機械的に出せる部分を先に出す。

- 全タスクで層1 pass、層2 が A 以上、かつ 1 つ以上のタスクで改善 → **promote 推奨**
- 層1 fail が 1 つでもある、または層2 が A より悪い → **revert 推奨**
- judge が A / B を判別できない、rubric を変えた、層1 で測れない種類の変更 → **inconclusive**（人が決める）
- 成果物が同一で、差が手順にだけ出たときは、層2 は判別できない。層1 で決め、判定に「層2 は判別不能」と書く
- A と B が同じ判定（両方 pass / 両方 fail）のとき、変更が効かないのか 1 回のばらつきなのかは区別できない。promote の根拠にするのは、層1 が A で fail、B で pass に反転したときだけにする

適用は `reflect` と同じく明示承認を待つ。自動適用しない。

## コスト

1 回 = 候補 2 体 × タスク数 + judge 1 体。タスク 1 本なら 20〜40 分。タスクを増やす前に、1 本で回ることを確かめる。

**返信**: variant、rubric、候補ごとの層1 の結果、judge の verdict、自分の統合、promote / revert / inconclusive の推奨、TSV のパス。
