# Oniwaban — 全体設計とロードマップ

## 1. プロジェクトの位置づけ

**フロンティア基盤モデルの事前学習に対抗するのではなく、既存OSSモデルを派生させて個人スケールで実用品質に到達させる**プロジェクト。

[Sakana AI](https://sakana.ai/) の方法論（Evolutionary Model Merge、知識蒸留、追加学習なしのモデル改造）にインスパイアされた、**SWEの延長で実装可能な軽量モデル開発**を実践する。

## 2. ゴール

[ai-team](https://github.com/kkm-horikawa/ai-team) の以下のロールを、ローカルで動く自作派生モデルで代替する：

- **Tester** ロール（多言語テスト生成）
- **Security Reviewer** ロール（脆弱性監査・exploit写経）  ※新設
- **Formatter** ロール（コードフォーマット・差分要約）

リーダー / 設計責任者 / プログラマー / 品質責任者 は Claude Sonnet/Opus を継続使用（長距離推論・判断責任の重い役割は frontier の価値が出る領域）。

## 3. 設計原則

| 原則 | 内容 |
|---|---|
| Web検索非依存 | 学習カットオフに左右される情報処理を含むタスクは対象外。コード/テスト/security 監査に集中 |
| ローカル完結 | 機密性のあるコード（shikomi, ai-team内部, kkm-mako.com 運用情報）を外に出さない |
| 自分用 only | abliteration 適用前提。個人開発・学習・自己研鑽用途、商用提供せず |
| 自己改善 | ai-team の運用ログを蒸留素材として継続改善 |
| 個人スケール | RTX 4070 Ti 12GB + M3 MacBook で完結。Cloud GPU バーストは年数万円規模に抑える |

## 4. アーキテクチャ

```
                    ai-team (Discord)
                         │
         ┌───────────────┴────────────────┐
         │                                 │
   Sonnet/Opus                       oniwaban-server
   (Leader, Designer,                (OpenAI互換 API)
    Programmer, Quality)                   │
                                           │
                          ┌────────────────▼─────────────────┐
                          │   推論サーバー (4070 Ti / 12GB)   │
                          │                                  │
                          │  ┌────────────────────────────┐  │
                          │  │ Base: Qwen2.5-Coder-7B     │  │
                          │  │  + Abliteration             │  │
                          │  │  + WhiteRabbitNeo merge     │  │
                          │  └──────────────┬─────────────┘  │
                          │                 │                │
                          │  ┌──────────────▼─────────────┐  │
                          │  │ LoRA Hot-Swap Router       │  │
                          │  │  ├ python+django+wagtail    │  │
                          │  │  ├ typescript+react         │  │
                          │  │  ├ rust                     │  │
                          │  │  ├ go                       │  │
                          │  │  ├ flutter                  │  │
                          │  │  └ security+exploit         │  │
                          │  └────────────────────────────┘  │
                          └────────────────┬─────────────────┘
                                           │
                          ┌────────────────▼─────────────────┐
                          │       自己改善ループ              │
                          │                                  │
                          │  ai-team Discord履歴             │
                          │    ─→ (prompt, Claude応答) 蒸留素材│
                          │                                  │
                          │  shikomi/wagtail OSS開発ログ      │
                          │    ─→ SFT データ                  │
                          │                                  │
                          │  CTF / exploit写経                │
                          │    ─→ security データ             │
                          │                                  │
                          │  毎月: 新データでLoRA再学習        │
                          │    ─→ eval 通過なら採用、失敗ならrollback │
                          └──────────────────────────────────┘
```

## 5. ハードウェア

| 項目 | スペック |
|---|---|
| GPU | NVIDIA RTX 4070 Ti（12GB VRAM） |
| RAM | 80GB |
| ストレージ | SSD1 1TB（Windows 11）/ SSD2 1TB（Ubuntu 24.04 LTS） |
| OS | Ubuntu 24.04 LTS（メイン）/ Windows 11（保険） |
| 補助マシン | Apple M3 MacBook（Phase 0-1 のメイン作業マシン、Phase 2以降はリモートクライアント） |

## 6. ベースモデル候補（Phase 0 の bake-off で確定）

| 候補 | 役割 | 評価軸 |
|---|---|---|
| Qwen2.5-Coder-7B-Instruct | 第一候補 | 多言語コード性能、Apache-2.0、tool use |
| Qwen3-Coder-7B（リリース済みなら） | 最新候補 | Qwen2.5の後継 |
| WhiteRabbitNeo-7B/13B | セキュリティ特化候補 | offensive security 学習済み |
| DeepSeek-Coder-V2-Lite-Instruct | MoE代表 | 16B/2.4B active、コード性能 |
| Llama-3.1-Swallow-8B-Instruct | 日本語コントロール | 日本語強化された Llama 系派生 |
| Gemma 2 9B-it / CodeGemma | Google系コントロール | 比較ベースライン |

## 7. Phase ロードマップ

### Phase 0: 基盤構築（Week 0-2）

**目的**: 評価できる土台を最初に作る。

- [ ] Base Bake-off: 全候補を 8言語×コード生成 + セキュリティ系プロンプトで比較
- [ ] Eval Harness 構築:
  - L1（コード正当性）: cargo test / pytest / jest / go test の統合実行
  - L2（セキュリティ）: refusal率、CTF解答率、exploit script 動作率
  - L3（ai-team タスク再現）: 過去 Discord ログを replay して採点
- [ ] Abliteration tooling 実装（refusal direction 抽出 → projection）
- [ ] M3 MacBook で全部完結（4070 Ti は Phase 2 開始までに準備すれば良い）

### Phase 1: oniwaban v0.1（Week 3-6）

**目的**: 一気通貫で動くものを最速で出す。LoRA未投入でもこの時点で実用ライン到達。

- [ ] 選定 base に abliteration 適用
- [ ] mergekit で security 成分（WhiteRabbitNeo or Dolphin）をブレンド
- [ ] llama.cpp / vLLM で推論サーバー立ち上げ
- [ ] ai-team に `oniwaban_client.py` 追加（OpenAI互換）
- [ ] ai-team Tester 3名 + 新設 Security Reviewer 役を oniwaban に割当
- [ ] **v0.1 リリース**（HuggingFace に push）

### Phase 2: 言語特化 Multi-LoRA（Week 7-18）

**目的**: vanilla からの上積みを各言語で出す。各2週間ペースで6 LoRA。

- [ ] Week 7-8: `python+django+wagtail.lora`（教師: ai-team Python ログ + wagtail OSS test/ + Claude Opus 合成）
- [ ] Week 9-10: `typescript+react.lora`
- [ ] Week 11-12: `rust.lora`（shikomi で実投入）
- [ ] Week 13-14: `go.lora`
- [ ] Week 15-16: `flutter.lora`
- [ ] Week 17-18: `security+exploit.lora`（CVE writeup、CTF writeup、ペンテスト用 script パターン）
- [ ] **v0.2 リリース**

### Phase 3: 自己改善ループ（Week 19-26）

**目的**: 「動いてるだけで賢くなる」状態にする。

- [ ] ai-team Discord 履歴を毎週 dump → (prompt, Claude応答) ペア化
- [ ] 蒸留パイプライン構築: 高評価ペアだけを学習素材に（Claude を judge）
- [ ] shikomi / wagtail OSS のコミット履歴から差分テスト生成 SFT素材生成
- [ ] 月次の自動 LoRA 再学習 cron（4070 Ti が一晩走る）
- [ ] catastrophic forgetting 検知 → 自動 rollback
- [ ] **v0.3 リリース**

### Phase 4: Tool Use 学習（Week 27-32）

**目的**: ローカルモデルの最大の弱点（情報鮮度）を tool use で補う。

- [ ] Web 検索 tool（local DuckDuckGo / SearXNG 経由）
- [ ] コード実行 tool（sandbox）
- [ ] codebase grep tool
- [ ] tool use 用 SFT データで「いつ呼ぶべきか」訓練
- [ ] **v0.4 リリース**

### Phase 5: 完成形 v1.0（Week 33-40）

**目的**: 仕上げと公開判断。

- [ ] 性能総合 benchmark（vanilla比、Sonnet比のコスト・性能）
- [ ] ドキュメント整備
- [ ] 公開戦略の決定（generic 版を public 公開 vs 完全 private 維持）
- [ ] kkm-mako.com 連載完結篇 + 登壇 1〜2本
- [ ] **v1.0 リリース**

## 8. 完走確率の honest な見積もり

| マイルストーン | 確率 |
|---|---|
| v0.1 到達（Phase 1 完了） | 90%+ |
| Phase 2 完了（multi-LoRA 6本） | 70% |
| Phase 3 完了（自己改善ループ稼働） | 50% |
| Phase 4 完了（tool use 学習成功） | 30% |
| v1.0 公開判断まで到達 | 40% |

Phase 2 完了時点（6ヶ月後）でフリーランス市場に出せる実績ラインに到達。Phase 3 以降はボーナス。

## 9. 公開ポリシー

| カテゴリ | ポリシー |
|---|---|
| 訓練/推論コード | Public（Apache-2.0） |
| Eval pipeline | Public（Apache-2.0） |
| Abliteration 実装 | Public（Apache-2.0） |
| 設計ドキュメント | Public |
| Generic 派生モデル | 公開判断は Phase 5 で確定 |
| 個人特化派生モデル（kkm-mako.com 等の固有データ含む） | Private 維持 |
| ai-team Discord ログ生データ | Private 維持 |
| API キー / Discord webhook 等 | コミット禁止（gitignore + secret scanning） |

## 10. 関連リソース

- [ai-team](https://github.com/kkm-horikawa/ai-team) — 統合先 multi-agent システム
- [shikomi](https://github.com/shikomi-dev/shikomi) — Rust LoRA の実投入対象
- Sakana AI 関連論文・ブログ:
  - [Evolutionary Optimization of Model Merging Recipes](https://sakana.ai/evolutionary-model-merge/)
  - [TinySwallow](https://sakana.ai/taid-jp/)
  - [Darwin Gödel Machine](https://sakana.ai/dgm/)
