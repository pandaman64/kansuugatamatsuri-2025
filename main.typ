#import "@preview/touying:0.6.1": *
#import themes.metropolis: *
#import "@preview/cetz:0.3.4"
#import "@preview/fletcher:0.5.8" as fletcher: node, edge

#let cetz-canvas = touying-reducer.with(reduce: cetz.canvas, cover: cetz.draw.hide.with(bounds: true))
#let fletcher-diagram = touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)


#set text(font: "Noto Serif CJK JP")
#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Leanで正規表現エンジンをつくる],
    subtitle: [そして正しさを証明する],
    author: [井山梃子歴史館 (pandaman64)],
    date: datetime(year: 2025, month: 6, day: 15),
  ),
)

#let styledLink(href, content) = {
  link(href)[#text(fill: blue)[#underline[#content]]]
}

// #show: touying-set-config.with(config-colors(
//   primary: black,
// ))
#show strong: set text(weight: "bold")

#title-slide()

== 発表の目的

- 内容
  - Leanとは？
  - なぜLeanで定理を証明するのか？
  - プログラムの正しさを証明するとは？
- 仲間を探しに来た
  - みんなも定理証明、やろう！
  - #text(size: 0.75em)[（あわよくば）]#styledLink("https://github.com/pandaman64/lean-regex")[lean-regex]にコントリビュート、しよう！
  
= Leanとは？

== Leanとは何か

- Leanの二面性
  - 純粋関数プログラミング言語
    - 依存型: 型の中に値が含められる
    - モナドを使った手続き型プログラミング
    - 自由なマクロシステム
      - #styledLink("https://github.com/pandaman64/lean-regex/blob/a78f86844b4878421b0b9181c095f449f61c0720/regex/Regex/Regex/Elab.lean#L89-L90")[正規表現]、#styledLink("https://github.com/leanprover/verso/blob/50be939050ddca47648ea7acd3eac60798f9ecea/examples/website/DemoSiteMain.lean")[HTML]、#styledLink("https://github.com/FWuermse/lean-postgres/blob/e3e19e4eee439932b2b5429cfe810a234f7aa453/examples/query/Main.lean")[SQL]
  - 定理証明支援系
    - 数学の定理やプログラムの性質、それらの証明を記述する言語
    - Leanの*カーネル*が証明が成立することを厳密にチェックする

== Leanのコード例

#grid(
  columns: (1fr, 1fr),
  rows: (1fr, 1fr),
  figure(
    caption: text(size: 0.75em)[プログラムの例],
    supplement: none,
  )[
  ```lean
  def fib (n : Nat) : Nat :=
    match n with
    | 0 | 1 => 1
    | n + 2 => fib n + fib (n + 1)
  def main : IO Unit := do
    IO.println s!"fib 10 = {fib 10}"
  ```
  ],
  figure(
    caption: text(size: 0.75em)[証明の例],
    supplement: none
  )[
  ```lean
  theorem reverse_reverse (xs : List α) :
    xs.reverse.reverse = xs := by
    induction xs with
    | nil => rfl
    | cons x xs ih =>
      simp [ih]
  ```  
  ],
  grid.cell(
    colspan: 2, 
    figure(
      caption: text(size: 0.75em)[証明を使うプログラムの例],
      supplement: none
    )[
      ```lean
      def sumAt {n} (xs ys : Vector Nat n) (i : Nat) : Option Nat :=
        -- `h` is a proof that `i < n` holds
        if h : i < n then
          some (xs[i]'h + ys[i]'h)
        else
          none
      ```
    ]
  )
)

== Leanで正規表現を実装する

- #styledLink("https://github.com/pandaman64/lean-regex")[lean-regex]: 自作の正規表現ライブラリ
  - 正規表現をオートマトンにコンパイルして実行
  - Lean上で実装の正しいことを検証済み
- 「実装が正しい」とは？
  - 正規表現のマッチ結果を厳密に定義する
    - ```lean inductive Captures : Iterator → Iterator → CaptureGroups → Expr → Prop ```
  - 検索関数```lean def Regex.find : Iterator → Regex → Option CaptureGroups ```について
    - ✅ #styledLink("https://github.com/pandaman64/lean-regex/blob/a78f86844b4878421b0b9181c095f449f61c0720/correctness/RegexCorrectness/Regex/Basic.lean#L72")[健全性]: 見つかったマッチは`Captures`を必ず満たす
    - ✅ #styledLink("https://github.com/pandaman64/lean-regex/blob/a78f86844b4878421b0b9181c095f449f61c0720/correctness/RegexCorrectness/Regex/Basic.lean#L93")[完全性]: `Captures`を満たすマッチが存在するなら必ずマッチを見つける
    - これらを示すLeanの証明を書いた

== なぜ正規表現？

+ 正規表現は広く使われている
  - テキスト処理の場面でよく出てくる
  - 実用的なプログラミング言語には正規表現実装がつきもの
+ 仕様・実装がほどよく複雑
  - 検索関数の正しさを数学的に明確に定式化できる（けど、細部は微妙）
  - 実装はオートマトンへのコンパイルや探索など、そこそこ複雑
  - エッジケースも含めて定理証明支援系で厳密に表現・検証する価値あり
+ パフォーマンスが重要
  - 大量のテキストを効率よく処理したい
  - Leanの最適化の出番！

== Leanの最適化

- 2つの実行モデル
  + カーネルによるインタプリタ: 証明の検証・エディタでの実行など
  + Cへのコンパイル: LeanをC言語に変換してネイティブコードを生成
- Cへのコンパイル時はオブジェクトを参照カウンタで保持
  - 正格な純粋関数型言語なので（基本的には）参照サイクルが発生しない
- 参照カウンタを見るとデータ構造の更新を*破壊的変更*に最適化できる
  - 例: ```lean let xs' := Array.set xs i v``` のような操作が実質O(1)で実行
    - 証明の検証時は`xs`と`xs'`の両方が同時に存在するかのように扱える
  - オートマトンベースの正規表現エンジンに最適

= なぜ定理証明するのか？
  
== なぜ定理証明するのか？

- 定理証明は苦しい...
  - 証明のコード量は実装の2〜20倍
  - 定理証明支援系のご機嫌取りでボイラープレートが増える
    - #image("never_theorem_prover.png", width: 450pt)
- それでもなぜやるのか？
  - 信頼性の保証: 暗号処理など、信頼性が要求される領域で確実な保証を得る
  - 実装の品質向上: 証明過程でバグを発見
  - パズル的な面白さ: 証明が通った瞬間の達成感は中毒性がある
  - *深い理解*が得られる: これが最も重要！

== 定理証明で得られる「深い理解」とは

- 証明を書くには*なぜ定理が成立するか*を理解しなければならない
  - 書いたプログラムがなぜ正しく動くのか？を深く理解する必要がある
- プログラムはなぜ正しく動くのか？ = *よい不変条件*が成立しているから
  - 不変条件: プログラムの各ステップ前後で常に成立している性質
  - プログラムの性質を証明するには
    + 不変条件を見つける
    + 各処理が見つけた不変条件を*保存*することを示す
    + 見つけた不変条件が所望の性質を*導く*ことを示す
  - どうやって不変条件を見つけるの？
    - #strike[頑張る💪]
    - 具体例を計算したり欲しい性質から逆算したりする

== 例: DFSで到達可能性を計算する

#let main-graph-node-text-size = 2em
#let main-graph-node-stroke = .1em
#let main-graph-node(pos, n, visited: false, current: false, dashed: false) = {
  let stroke = stroke(
    paint: if (visited) { red } else { black },
    thickness: if (current) { main-graph-node-stroke * 2 } else { main-graph-node-stroke },
    dash: if (dashed) { "dashed" } else { "solid" },
  )
  
  node(
    pos,
    text(size: main-graph-node-text-size)[#raw(str(n))],
    name: label("n" + str(n)),
    stroke: stroke
  )
}
#let main-graph-state-defaults = (false, false, false, false, false)
#let main-graph(visited: main-graph-state-defaults, current: -1) = {
  let nodes-data = (
    // coordinate, label
    ((0, 0), 0),
    ((4, -1), 1),
    ((4, 1), 2),
    ((8, 0), 3),
    ((0, 2), 4),
  )
  figure(
    fletcher-diagram(
      debug: 0,
      node-stroke: .1em,
      mark-scale: 100%,
      spacing: .5em,
      cell-size: 1em,
      // ..nodes,
      for (i, (pos, label)) in nodes-data.enumerate() {
        main-graph-node(
          pos,
          label,
          visited: visited.at(i, default: false),
          current: i == current,
        )
      },
      edge(<n0>, <n1>, "-|>"),
      edge(<n0>, <n2>, "-|>"),
      edge(<n1>, <n3>, "-|>"),
      edge(<n2>, <n3>, "-|>"),
      edge(<n4>, <n3>, "-|>", bend: -35deg),
    ),
    caption: text(size: 0.75em)[グラフの例。探索した頂点を赤く塗っている],
    supplement: none,
  )
}

#let main-stack(xs) = {
  let visible-nodes = xs.map(it => it + (true,))
  let nodes = if (visible-nodes.len() < 3) {
    let ys = visible-nodes.rev()
    while (ys.len() < 3) {
      ys.push((0, false, false))
    }
    ys.rev()
  } else {
    visible-nodes.slice(0, 3)
  }
  let nodes2 = ()
  for (i, red, visible) in nodes {
    let diagram = fletcher-diagram(
      debug: 0,
      node-stroke: main-graph-node-stroke,
      main-graph-node((0, 0), i, visited: red)
    )

    if (visible) {
      nodes2.push(diagram)
    } else {
      nodes2.push(hide(diagram))
    }
  }
  figure(
    stack(
      dir: ttb,
      spacing: 1.0em,
      ..nodes2,
      line(length: 100%)
    ),
    caption: text(size: 0.75em)[これから探索する頂点のスタック],
    supplement: none,
  )
}

#let main-diagram(visited: main-graph-state-defaults, current: -1, stack: ()) = {
  grid(
    columns: (1fr, 1fr),
    align: center,
    main-graph(visited: visited, current: current),
    main-stack(stack),
  )
}

#let invariant(color: black, label: none) = {
  align(center)[
    #grid(
      columns: 5,
      gutter: 0.5em,
      align: center,
      fletcher-diagram(
        node-stroke: .075em,
        node((0, 0), $v$, name: <v1>, width: 1.5em, height: 1.5em, shape: circle, stroke: red),
        node((1, 0), $v'$, name: <v2>, width: 1.5em, height: 1.5em, shape: circle, stroke: (dash: "dashed")),
        edge(<v1>, <v2>, "-|>", label: label)
      ),
      [ならば],
      fletcher-diagram(
        node-stroke: .075em,
        node((0, 0), $v'$, name: <v1>, width: 1.5em, height: 1.5em, shape: circle, stroke: red)
      ),
      text(fill: color)[または],
      box[
        #stack(
          spacing: 0.5em,
          fletcher-diagram(
            node-stroke: .075em,
            node((0, 0), text(fill: color)[$v'$], name: <v1>, width: 1.5em, height: 1.5em, shape: circle, stroke: color)
          ),
          line(length: 2em, stroke: color)
        )
      ]
    )
  ]
}

#main-diagram(stack: ((0, false),))

- グラフの到達可能性: 頂点`0`から到達できる頂点の集合は？
  -  正規表現のマッチ #sym.eq.dots.down 正規表現をコンパイルしたオートマトンの到達可能性
- DFS（深さ優先探索）で到達可能性の判定ができる。なぜ？
  - DFSが*よい不変条件*を満たすから

== DFSの不変条件

#main-diagram(stack: ((0, false),))

- *不変条件*: 探索済みの頂点から1ステップ先の頂点は既に探索済みorスタック上

#invariant()

// - DFSアルゴリズムが保持する状態
//   - 訪問済み頂点の集合`visited: HashSet Node`
//   - これから訪問する頂点のスタック`stack: Stack Node`
// - 不変条件: $forall v in "visited", v arrow.r.long v' arrow.r.double v' in "visited" or v' in "stack"$
  // - 頂点$v$が訪問済みならば、$v$から1ステップで到達可能な頂点$v'$は
  //   - 既に訪問済み($v' in "visited"$)、
  //   - もしくは、これから訪問する頂点のスタックに含まれる($v' in "stack"$)

#let invariant-diagrams = (
  main-diagram(stack: ((0, false),)),
  main-diagram(stack: ((0, true),)),
  main-diagram(visited: (true,), stack: ()),
  main-diagram(visited: (true,), stack: ((1, false), (2, false),)),
  main-diagram(visited: (true,), stack: ((1, true), (2, false),)),
  main-diagram(visited: (true, true), stack: ((2, false),)),
  main-diagram(visited: (true, true), stack: ((3, false), (2, false),)),
  main-diagram(visited: (true, true), stack: ((3, true), (2, false),)),
  main-diagram(visited: (true, true, false, true), stack: ((2, false),)),
  main-diagram(visited: (true, true, false, true), stack: ((2, true),)),
  main-diagram(visited: (true, true, true, true), stack: ()),
  main-diagram(visited: (true, true, true, true), stack: ((3, false),)),
  main-diagram(visited: (true, true, true, true), stack: ((3, true),)),
  main-diagram(visited: (true, true, true, true), stack: ()),
)

== 不変条件の保存

#slide(repeat: invariant-diagrams.len(), self => [
  #let (uncover, only, alternatives) = utils.methods(self)

  #alternatives(..invariant-diagrams)

  - *不変条件*: 探索済みの頂点から1ステップ先の頂点は既に探索済みorスタック上
    - DFSの各ステップが不変条件を*保存*する
    
  #invariant()
])

== 不変条件が到達可能性を導く

#slide(repeat: 3, self => [
  #let (uncover, only, alternatives) = utils.methods(self)
  
  #main-diagram(visited: (true, true, true, true), stack: ())

  - スタックが空になったら計算が完了
  - *不変条件*: 探索済みの頂点から#alternatives[1][1][*N*]ステップ先の頂点は既に探索済み#alternatives(repeat-last: true)[orスタック上][#text(fill: gray)[orスタック上]]

  #alternatives(
    repeat-last: true,
    invariant(),
    invariant(color: gray),
    invariant(color: gray, label: [*N*]),
  )
])

== 不変条件が到達可能性を導く

#main-diagram(visited: (true, true, true, true), stack: ())

- *不変条件*: 探索済みの頂点から1ステップ先の頂点は既に探索済み#text(fill: gray)[orスタック上]
  - よって、Nステップ先の頂点(= 到達可能な頂点)は全て探索済み
- 逆に、別の不変条件を使うと到達可能な頂点だけ探索することが分かる
- したがって、到達可能性を計算するにはDFSでグラフを探索すればよい 🎉
  - *よい不変条件がDFSの正しさを導いた*

== なぜ定理証明するのか？のまとめ

- 定理証明はたいへん苦しい
- 定理証明は定理の*深い理解*をもたらす
  - プログラムの深い理解 = *よい不変条件*を見つけること
- 定理証明はとても*やりがいがある*
  - 全てが繋がった瞬間の気持ちよさはとんでもない

= 証明をエンジニアリングする
  
== 証明をエンジニアリングする

- 定理証明の苦しみを軽減する
  - 問題を分割することで一度に扱う複雑さを低減する
    - 証明の一部分を補題として切り出して再利用する
  - コードを再利用してボイラープレートを減らす
    - 定理証明パターンがありそう
    - 例: #styledLink("https://zenn.dev/pandaman64/articles/lean-proof-data-ja")[ProofDataで中間的な定義や証明を整理する]
- ソフトウェア開発と同じ！！
- Lean特有の苦しみ
  - `do`構文は糖衣構文
    - 証明時は脱糖後の式について証明を書くことになる
  - *依存型*は用法用量にお気をつけて

== 依存型は諸刃の剣

- 依存型: 型の中に値を含められる
  - ```lean let i : Fin 5```のとき、`i`は`5`未満の自然数
- メリット:
  - 型の表現力が上がる
  - パフォーマンス向上
    - ```lean def Array.get : (xs : Array α) → Fin xs.size → α```は境界チェックしない
- デメリット:
  - 型チェックが複雑になる（値の等しさもチェックしないといけないため）
    - 明示的なキャストが必要な場合はコードが冗長になる
    - ```lean ((x : Fin (n + 1)).cast (...n + 1 = 1 + nの証明...)) : Fin (1 + n)```
  - 実質的に「等しい」値でも型システム的に等しくならないことがある
    - 例: ```lean (3 : Fin 5) ≠ (3 : Fin 10)```

== 依存型の利用戦略

- 使うのは控えめに
  - #emoji.person.ok 型に登場する値が変わらないとき（キャストが必要無いとき）
  - #emoji.person.ok パフォーマンスが重要なとき
  - #emoji.person.no 型に登場する値が変わるとき（キャストが必要なとき）
- 値と一緒に命題を渡すほうが問題が起きないがち
  - #emoji.quest ```lean def Array.get : (xs : Array α) → (i : Fin xs.size) : α```
  - #emoji.thumb ```lean def Array.get' : (xs : Array α) → (i : Nat) → (lt : i < xs.size) : α```
  - `i`が単なる自然数なのでキャストの問題が起きない

== まとめ

- Leanは純粋関数プログラミング言語であり定理証明支援系でもある
  - Leanで記述したプログラムの性質をLean内で証明できる
- Leanで正規表現ライブラリ`lean-regex`を作っている
  - しかも、`lean-regex`の正しさをLeanの定理として証明した
- プログラムの性質の証明は対象のプログラムの深い理解をもたらす
  - 定理証明は苦しいが、とってもやりがいがある
- *みんなも定理証明、やろう！*

== 定理証明がやりたくなったら

- #styledLink("https://adam.math.hhu.de/#/")[Natural Numbers Game]: Leanの楽しいチュートリアル
- #styledLink("https://lean-lang.org/functional_programming_in_lean/")[Functional Programming in Lean]: Leanでのプログラムの書き方と検証
- #styledLink("https://leanprover-community.github.io/mathematics_in_lean/index.html")[Mathematics in Lean]: Leanで数学を表現する方法 (Mathlibの紹介)
- #styledLink("https://leanprover.zulipchat.com/")[Lean Zulip]: 親切なコミュニティ

== おわり

#align(center)[
  #text(size: 3em)[みんなも定理証明、やろう！]

  #styledLink("https://github.com/pandaman64/lean-regex")[lean-regex]はいつでもコントリビュータ募集中！
]
