# Opening a PR

他プレイブックの終端で呼ばれる共通手順。

**ワークツリー。** main から git worktree を切って作業する。サブエージェントはそれを引き継ぐ。

**コミット。** こまめにコミットし、PR を開く前に小さく順序だったコミットへ rebase する。各コミットは将来の PR 単位（着地可能で、ストーリーが伝わる順）。修正が直前のコミットに属するなら amend、分離できるなら新コミット。コミット本文は件名を繰り返さない。

**タイトル。** Conventional Commits `type(scope): subject`。末尾ピリオドなし。type は feat / fix / docs / refactor / test / chore / perf など。scope は対象領域。subject は短く命令形。

**本文。** 差分を持つレビュアー向けの、1 分で読める briefing。なぜ存在するか・何を外したか・何を壊しうるか・どう証明したかを書く。短い平文。squash コミット本文になるので 40 行以内。`##` 見出しをこの順で使い、書くことが無い節は省く:

- `## Why`: 問題と方針、1〜3 文。
- `## What changed`: 1〜3 の短い bullet。
- `## Scope`: 必ず。対象と、意図的に外したものを 1〜3 項目。
- `## Tradeoffs`: レビュアーが聞きそうな、棄却した代替案のみ。
- `## Blast Radius`: 誰に・何に触れるか、なぜ安全か 1〜2 文。
- `## Verification`: 実際の実行経路と結果を 1〜3 bullet。

**forge。** PR 操作は `gh` を使う。

**サイズとスタック。** 大きい PR 1 本より狭い PR 5 本を優先。スタックは base-branch チェーン（子ブランチは親の tip に rebase、PR は親ブランチを base にする）。独立した作業は trunk から切る。

**readiness。** 常に ready で開く。draft にしない。

**babysit。** PR を開いても babysit は始めない。URL を貼ってビルドを続ける。ユーザーが明示的に頼んだときだけ別途行う。
