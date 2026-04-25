# Oniwaban — 全体設計とロードマップ

## 1. プロジェクトの位置づけ

**multi-agent システムで使う「ロール特化モデル」を個人スケールで育成するためのキット**。

[Sakana AI](https://sakana.ai/) の方法論（Evolutionary Model Merge、知識蒸留、追加学習なしのモデル改造）にインスパイアされた、**SWE の延長で実装可能な軽量モデル開発キット**として位置づける。フロンティア基盤モデルの事前学習に対抗するのではなく、既存OSSモデルを派生させて特定ロールに特化させる手法をパイプライン化する。

oniwaban の本体は **特定の派生モデル** ではなく **キット** である。利用者は：

- 同梱の reference roles（tester / formatter / security-reviewer 等）を自分のシステムにそのまま組み込む
- 同形式で独自ロールを定義し、自分の用途に合わせたモデルを育成する
- 新世代 base がリリースされれば 1 コマンドで全派生を再生成し追従する

## 2. ゴール

### 2.1 直接目標

- **キット本体**（manifest / recipe / orchestrator / eval / 自己改善ループ）を OSS として完成させる
- **reference role の派生モデル群**を Phase 5 までに実用品質で公開する
- 実運用での導入例として、開発者自身の multi-agent システムでこれら派生モデルを稼働させる

### 2.2 ロールの時代変化への対応

「どのロールが個人スケールのローカル LLM で実現可能か」は、ベースモデルの能力向上と共に拡張していく：

| 時期 | 射程内のロール |
|---|---|
| **現在** | フォーマッター、テスター、セキュリティレビュアー（パターン認識・構造化タスク中心） |
| **近未来（〜2年）** | コーダー（実装ロール）、ドキュメンタリスト |
| **遠い将来（楽観）** | 設計責任者、テクニカルリーダー |

長距離推論・判断責任の重い役割（リーダー / 設計責任者）はフロンティアモデルが優位な状況が続く想定。oniwaban のスコープは **「現時点でローカル実現可能なロール」を発見し、それらを再現可能に育成する** こと。ロール定義そのものが時代と共に進化する前提で設計する。

## 3. 設計原則

| 原則 | 内容 |
|---|---|
| **Role as First-Class** | 「フォーマッター」「テスター」等のロールを first-class 概念として扱い、責務 / 入出力 / 評価基準 / 訓練データ仕様を YAML で宣言。利用者は同形式で独自ロールを追加できる |
| **Base Model Agility** | 特定 base モデルに密結合させず、宣言的 manifest と recipe で「現在の base」を差し替え可能にする。LLM の世代交代速度（数ヶ月単位）に追従できる pipeline こそが永続資産 |
| **Pipeline as Code** | abliteration / merge / LoRA訓練 / eval / deploy をすべて宣言的 recipe + justfile で記述。手順書ではなく実行可能成果物 |
| Web検索非依存 | 学習カットオフに左右される情報処理を含むタスクは対象外。パターン認識・構造化タスクに集中 |
| ローカル完結 | 機密性のあるコードを外部 API に出さない |
| 自己改善 | 運用ログを蒸留素材として継続改善 |
| 個人スケール | コンシューマGPU（12GB VRAM 程度）+ Apple Silicon Mac で完結する範囲に収める |

### 永続資産

oniwaban の本体は「特定の派生モデル」ではなく、以下の5つの永続資産：

1. **Role 定義集**（base 非依存）— 各ロールの責務 / 評価基準 / 訓練データ仕様を YAML で記述。reference roles を同梱、利用者が独自ロールを追加可能
2. **Model Build Pipeline**（base 非依存）— 任意の base に対して abliteration → merge → role-specific LoRA 訓練を再現可能に適用するパイプライン
3. **Eval Pipeline**（base 非依存）— OpenAI 互換 API surface 経由で評価。base が変わっても eval は不変
4. **Self-Improvement Loop**（base 非依存）— 運用ログから蒸留素材を生成し定期再学習
5. **API Surface / Agent Integration**（base 非依存）— 外部から見た contract が安定

派生モデル本体（abliterated / merged / LoRA-tuned 成果物）は base 依存で寿命が短いが、上記5資産は base 更新ごとに繰り返し利用される。新しい base モデルがリリースされれば、`manifests/bases/<new>.yaml` を1ファイル追加し `just full-rebuild` を実行することで、全 role × base の派生を再生成して旧世代と比較・切替できる構造を取る。

## 4. アーキテクチャ概念図

### 4.1 ランタイム構成

```
        Multi-Agent Orchestration System
                       │
       ┌───────────────┴───────────────┐
       │                                │
   フロンティアモデル                oniwaban-server
   (Leader / Designer /          (OpenAI互換 API surface — base 非依存)
    Programmer / Quality)              │
                                       │
                    ┌──────────────────▼──────────────────┐
                    │      推論サーバー (Local GPU)         │
                    │                                      │
                    │  ┌────────────────────────────────┐  │
                    │  │ Base ← manifests/current.yaml   │  │  ← 差替可
                    │  │  + Abliteration（recipe適用済）  │  │
                    │  │  + 派生マージ（recipe適用済）    │  │
                    │  └──────────────┬─────────────────┘  │
                    │                 │                    │
                    │  ┌──────────────▼─────────────────┐  │
                    │  │ LoRA Hot-Swap Router           │  │
                    │  │  ├ python+django+wagtail        │  │
                    │  │  ├ typescript+react             │  │
                    │  │  ├ rust                         │  │
                    │  │  ├ go                           │  │
                    │  │  ├ flutter                      │  │
                    │  │  └ security                     │  │
                    │  └────────────────────────────────┘  │
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────▼───────────────────┐
                    │        自己改善ループ                 │
                    │                                      │
                    │  - 運用ログから (prompt, 応答) 抽出   │
                    │  - 高評価ペアを学習素材として蒸留      │
                    │  - 月次で LoRA 再学習                 │
                    │  - eval 通過時のみ採用、失敗時 rollback│
                    └──────────────────────────────────────┘
```

### 4.2 Build-time 構成（Model Build Pipeline）

```
   manifests/bases/                    recipes/
   ├ qwen2.5-coder-7b.yaml             ├ abliteration/default.yaml
   ├ qwen3-coder-7b.yaml               ├ merge/security-blend.yaml
   ├ deepseek-coder-v2-lite.yaml       └ lora/{python,ts,rust,go,flutter,security}.yaml
   ├ ...
   └ current.yaml ────────┐
                          │
                          ▼
                ┌─────────────────────────────────┐
                │   Pipeline Orchestrator          │
                │   (just + Python)                │
                │                                  │
                │   1. Load current base manifest  │
                │   2. Apply abliteration recipe   │
                │   3. Apply merge recipe          │
                │   4. Train each LoRA recipe      │
                │   5. Eval → tag artifacts        │
                │   6. Push to HF Hub              │
                └──────────────┬──────────────────┘
                               │
                               ▼
            artifacts/<base-id>/<recipe-id>/<artifact>
```

**新世代 base 登場時のフロー**:

1. `manifests/bases/<new-model>.yaml` を1ファイル追加
2. `manifests/current.yaml` の base ポインタを書き換える PR を立てる
3. CI（or `just full-rebuild`）が全 recipe を新 base 上で再適用
4. eval pipeline が旧世代 vs 新世代を数値比較
5. 新世代が勝てば PR をマージ → 本番切替

これにより oniwaban は **「Qwen-Coder-7B 専用システム」ではなく「現在の最良 OSS コードモデルに自動追従するパイプライン」** として運用される。

## 5. ハードウェア前提

| 項目 | 想定スペック |
|---|---|
| GPU | コンシューマグレード GPU（12GB VRAM 程度を想定） |
| RAM | 32GB 以上推奨（前処理・データセット扱い向上） |
| OS | Linux（Ubuntu LTS 等）/ Apple Silicon macOS |
| Python | 3.12 + uv |
| Toolchain | axolotl / unsloth / mlx-lm / mergekit / llama.cpp / ollama |

## 6. 初期 base 候補プール

Base swappability を前提とするため、以下は「**Phase 0 時点の初期評価候補**」であり固定ではない。新規 OSS モデルがリリースされ次第、`manifests/bases/<new>.yaml` を追加し既存 recipe で評価する。

| 候補 | 役割 | 評価軸 |
|---|---|---|
| Qwen2.5-Coder-7B-Instruct | 第一候補 | 多言語コード性能、Apache-2.0、tool use |
| Qwen3-Coder-7B（リリース済みなら） | 最新候補 | Qwen2.5 の後継 |
| DeepSeek-Coder-V2-Lite-Instruct | MoE代表 | 16B/2.4B active、コード性能 |
| Llama-3.1-Swallow-8B-Instruct | 日本語コントロール | 日本語強化された Llama 系派生 |
| Gemma 2 9B-it / CodeGemma | Google系コントロール | 比較ベースライン |

詳細な base 切替方針は [model-build-pipeline.md](model-build-pipeline.md) を参照。

### 6.1 Reference Role と関連ドキュメント

- reference role の定義方針および独自ロール追加方法は [role-abstraction.md](role-abstraction.md) を参照
- 外部システム（multi-agent / IDE / CLI / Bot 等）からの統合方法は [integration-patterns.md](integration-patterns.md) を参照

## 7. Phase ロードマップ

### Phase 0: 基盤構築（Week 0-3）

**目的**: 評価できる土台 + base 差替可能なパイプライン骨格を最初に作る。

- [ ] **Manifest schema 設計**:
  - `manifests/bases/<base-id>.yaml` のスキーマ（HF repo、architecture family、tokenizer、context length、license、tool-use サポート、等）
  - `manifests/current.yaml` の指す形式（pointer + version pin）
  - `recipes/{abliteration,merge,lora}/<recipe-id>.yaml` のスキーマ
- [ ] **Pipeline orchestrator skeleton**:
  - `just full-rebuild` / `just lora-only` / `just eval` の入り口
  - 各ステップを Python サブモジュールとして実装、manifest を pydantic でバリデート
- [ ] **Base Bake-off**（初期候補プールの評価）:
  - 全候補を 8言語×コード生成プロンプトで比較
  - 数値結果は `eval_results/bake-off/<date>.json` に保存
- [ ] **Eval Harness 構築（base 非依存）**:
  - L1（コード正当性）: 各言語の test runner 統合実行
  - L2（応答性測定）: 監査系プロンプトに対する応答率
  - L3（運用タスク再現）: ログ replay 採点
  - 全 eval は **OpenAI 互換 API surface 経由**で実行（base が変わっても eval コードは不変）
- [ ] **Abliteration tooling 実装**:
  - 任意の decoder transformer に適用可能な汎用実装
  - architecture family ごとの hook ポイント差異を recipe 側で吸収

### Phase 1: v0.1 — Formatter role を最初に完成（Week 3-6）

**目的**: 一気通貫で動く end-to-end を最速で出す。reference role として **`formatter`** を最初に完成させる（タスク境界が狭く、評価が単純で、訓練データを集めやすい）。

- [ ] 選定 base に abliteration 適用
- [ ] mergekit で派生モデルをブレンド
- [ ] llama.cpp / vLLM で推論サーバー立ち上げ
- [ ] OpenAI 互換 API client + role routing
- [ ] **`formatter` role の reference 実装**（manifest + LoRA + eval）
- [ ] **v0.1 リリース**（formatter role が完成、他 role は未訓練）

### Phase 2: Tester / Security-Reviewer role の多言語展開（Week 7-18）

**目的**: 主力 role を多言語で完成させる。Role × Language の直積で LoRA を生成。

- [ ] Week 7-8: `tester-python`（Django/Wagtail 含む）
- [ ] Week 9-10: `tester-typescript`（React 含む）
- [ ] Week 11-12: `tester-rust`
- [ ] Week 13-14: `tester-go`
- [ ] Week 15-16: `tester-flutter`
- [ ] Week 17-18: `security-reviewer`（言語横断 + 言語別パターン）
- [ ] **v0.2 リリース**

### Phase 3: 自己改善ループ（Week 19-26）

**目的**: 「動いてるだけで賢くなる」状態にする。Role 単位での改善を自動化。

- [ ] 運用ログから定期的に (prompt, 応答) ペア抽出
- [ ] 蒸留パイプライン構築（高評価ペアのみ学習素材化）
- [ ] 月次の自動 LoRA 再学習（Cron 駆動、role 別）
- [ ] catastrophic forgetting 検知 → 自動 rollback
- [ ] **v0.3 リリース**

### Phase 4: Tool Use 学習 + `coder` role 実験（Week 27-32）

**目的**: ローカルモデルの最大の弱点（情報鮮度）を tool use で補う。同時に実験 role としての `coder` に着手。

- [ ] Web 検索 / コード実行 / codebase 検索 tool 連携
- [ ] tool use 用 SFT データで「いつ呼ぶべきか」訓練
- [ ] **`coder` role の実験的実装**（タスク境界の狭い「指定関数の単体実装」から開始）
- [ ] **v0.4 リリース**

### Phase 5: キット完成形 v1.0（Week 33-40）

**目的**: キットとしての完成度を仕上げる。

- [ ] 性能総合 benchmark（vanilla 比、フロンティアモデル比のコスト・性能）
- [ ] **独自ロール追加方法のドキュメント整備**（Tutorial + テンプレート）
- [ ] reference roles の v1.0 確定
- [ ] キット利用の登壇 / ブログ記事
- [ ] **v1.0 リリース**

## 8. 完走確率の見積もり

| マイルストーン | 確率 |
|---|---|
| v0.1 到達（Phase 1 完了） | 90%+ |
| Phase 2 完了（multi-LoRA 6本） | 70% |
| Phase 3 完了（自己改善ループ稼働） | 50% |
| Phase 4 完了（tool use 学習成功） | 30% |
| v1.0 到達 | 40% |

Phase 2 完了時点（6ヶ月後目安）で実用ライン到達。Phase 3 以降はストレッチ目標。

## 9. 公開ポリシー

| カテゴリ | ポリシー |
|---|---|
| 訓練/推論コード | Public（Apache-2.0） |
| Eval pipeline | Public（Apache-2.0） |
| Abliteration 実装 | Public（Apache-2.0） |
| 設計ドキュメント | Public |
| 派生モデル本体 | 公開判断は Phase 5 で確定 |
| 運用ログ生データ | 非公開 |
| API キー / トークン類 | コミット禁止（gitignore + secret scanning） |

## 10. 参考資料

- Sakana AI 関連:
  - [Evolutionary Optimization of Model Merging Recipes](https://sakana.ai/evolutionary-model-merge/)
  - [TAID / TinySwallow](https://sakana.ai/taid-jp/)
  - [Darwin Gödel Machine](https://sakana.ai/dgm/)
- Tools:
  - [mergekit](https://github.com/arcee-ai/mergekit)
  - [axolotl](https://github.com/axolotl-ai-cloud/axolotl)
  - [unsloth](https://github.com/unslothai/unsloth)
  - [lm-evaluation-harness](https://github.com/EleutherAI/lm-evaluation-harness)
