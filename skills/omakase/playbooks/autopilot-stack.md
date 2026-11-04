# Autopilot-stack

**ビルドと検証は自動、merge は人手。** 独立 PR のキューを build + verify し、検証済みの PR をオペレータに渡す。merge はしない。

※ このプレイブックは Pi の `fleet_*`（検証ゲート付き merge フロー）に依存する。他ハーネスへの移植は後で検討。

1. **オペレータのゲートが先。** 許可はキューの項目だけ。オペレータが「自分のもの」と名指した項目や、キュー外の PR は merge-ready で止める。
2. **PR ごとにオーナーを 1 人立てる。** オーナーは `fleet_fork`（ワークツリー + セッション）で起動し、build → PR を開く → 実物で検証 → 緑まで babysit → merge-ready まで運ぶ。PR は早めに開き、CI と bot が並走するようにする。
3. **オーナーは trunk から並列に走らせ、スタックしない。** 各 PR は自分で着地する。スタックは、ある PR が別の PR の上に積むときだけ（親ブランチを base にする）。
4. **検証は作者と別のセッションで。** 検証は `fleet_review`（read-only、別モデルファミリー）→ `fleet_verdict`（approve / request-changes）。新しい挙動・再設計・大きな新規 diff は `swarm` で並列検証する。rebase・マージ衝突解消・小修正は新 head で単一検証、文言だけの変更は不要。判定は 1 つの head SHA をカバーする。
5. **merge しない。** 各 PR が現在の head で検証済み・緑になったら止め、PR をオペレータに渡す。引き渡し後は、オペレータの go なしに誰も push しない。
6. **下の PR の head が変わったら restack する。** `git patch-id` が変わらない PR は判定を維持する。

**返信:** 各 PR を判定付きで列挙する（merge したものの代わりに）。
