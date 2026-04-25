# Oniwaban — 全体設計とロードマップ

## 1. プロジェクトの位置づけ

**フロンティア基盤モデルの事前学習に対抗するのではなく、既存OSSモデルを派生させて個人スケールで実用品質に到達させる**プロジェクト。

[Sakana AI](https://sakana.ai/) の方法論（Evolutionary Model Merge、知識蒸留、追加学習なしのモデル改造）にインスパイアされた、**SWE の延長で実装可能な軽量モデル開発**を実践する。

## 2. ゴール

個人運用の multi-agent 開発システムにおいて、以下のロールを、ローカルで動く自作派生モデルで代替する：

- **テスト生成**ロール（多言語）
- **セキュリティレビュー**ロール（脆弱性監査）
- **コードフォーマット**ロール（差分要約・整形）

長距離推論・判断責任の重い役割（リーダー / 設計責任者 / プログラマー / 品質責任者）はフロンティアモデルを継続使用する想定。

## 3. 設計原則

| 原則 | 内容 |
|---|---|
| **Base Model Agility** | 特定 base モデルに密結合させず、宣言的 manifest と recipe で「現在の base」を差し替え可能にする。LLM の世代交代速度（数ヶ月単位）に追従できる pipeline こそが永続資産 |
| Web検索非依存 | 学習カットオフに左右される情報処理を含むタスクは対象外。コード/テスト/セキュリティ監査に集中 |
| ローカル完結 | 機密性のあるコードを外部 API に出さない |
| 自分用 only | 公開派生モデルの想定はせず、個人運用に最適化 |
| 自己改善 | 運用ログを蒸留素材として継続改善 |
| 個人スケール | コンシューマGPU（12GB VRAM 程度）+ Apple Silicon Mac で完結する範囲に収める |

### Base Model Agility の意味

oniwaban の本体は「特定の派生モデル」ではなく、以下の4つの永続資産：

1. **Model Build Pipeline**（base 非依存）— 任意の base に対して abliteration → merge → LoRA 訓練を再現可能に適用するパイプライン
2. **Eval Pipeline**（base 非依存）— OpenAI 互換 API surface 経由で評価。base が変わっても eval は不変
3. **Self-Improvement Loop**（base 非依存）— 運用ログから蒸留素材を生成し定期再学習
4. **API Surface / Agent Integration**（base 非依存）— 外部から見た contract が安定

派生モデル本体（abliterated / merged / LoRA-tuned 成果物）は base 依存で寿命が短いが、上記4資産は base 更新ごとに繰り返し利用される。新しい base モデルがリリースされれば、`manifests/bases/<new>.yaml` を1ファイル追加し `just full-rebuild` を実行することで、全世代を再生成して旧世代と比較・切替できる構造を取る。

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

### Phase 1: v0.1（Week 3-6）

**目的**: 一気通貫で動くものを最速で出す。LoRA 未投入でもこの時点で実用ライン到達。

- [ ] 選定 base に abliteration 適用
- [ ] mergekit で派生モデルをブレンド
- [ ] llama.cpp / vLLM で推論サーバー立ち上げ
- [ ] OpenAI 互換 API クライアント実装
- [ ] **v0.1 リリース**

### Phase 2: 言語特化 Multi-LoRA（Week 7-18）

**目的**: vanilla からの上積みを各言語で出す。各2週間ペースで6 LoRA。

- [ ] Week 7-8: `python+django+wagtail.lora`
- [ ] Week 9-10: `typescript+react.lora`
- [ ] Week 11-12: `rust.lora`
- [ ] Week 13-14: `go.lora`
- [ ] Week 15-16: `flutter.lora`
- [ ] Week 17-18: `security.lora`
- [ ] **v0.2 リリース**

### Phase 3: 自己改善ループ（Week 19-26）

**目的**: 「動いてるだけで賢くなる」状態にする。

- [ ] 運用ログから定期的に (prompt, 応答) ペア抽出
- [ ] 蒸留パイプライン構築（高評価ペアのみ学習素材化）
- [ ] 月次の自動 LoRA 再学習（Cron 駆動）
- [ ] catastrophic forgetting 検知 → 自動 rollback
- [ ] **v0.3 リリース**

### Phase 4: Tool Use 学習（Week 27-32）

**目的**: ローカルモデルの最大の弱点（情報鮮度）を tool use で補う。

- [ ] Web 検索 tool 連携
- [ ] コード実行 tool（sandbox）
- [ ] codebase 検索 tool
- [ ] tool use 用 SFT データで「いつ呼ぶべきか」訓練
- [ ] **v0.4 リリース**

### Phase 5: 完成形 v1.0（Week 33-40）

**目的**: 仕上げと公開判断。

- [ ] 性能総合 benchmark（vanilla 比、フロンティアモデル比のコスト・性能）
- [ ] ドキュメント整備
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
