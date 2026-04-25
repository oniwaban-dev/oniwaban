# Role Abstraction

## 1. 設計目的

oniwaban の中心概念は **Role（ロール）** である。multi-agent システムにおける役割分担を、特定実装に依存せず宣言的に表現する。

「ロールが first-class」とは、コードベース上で：

- ロールごとに責務 / 入出力 / 評価基準 / 訓練データ仕様を YAML で宣言
- 各ロールに対して base × 言語の組み合わせで派生モデルを生成
- 利用者は独自ロールを追加することで自分の用途に合わせた育成が可能

を意味する。これは Sakana AI の Evolutionary Model Merge が「マージレシピ」を first-class にしたのと同じ思想で、**「役割」を OSS 共有可能な単位** に押し上げる。

## 2. Role の構成要素

各ロールは以下の要素で定義される：

| 要素 | 内容 |
|---|---|
| **責務 (Responsibility)** | このロールが何をするか、自然言語で記述 |
| **入出力契約 (I/O Contract)** | system prompt template / 期待される入力形式 / 期待される出力形式 |
| **評価基準 (Evaluation Criteria)** | このロールの性能を測る客観指標。L1（自動）/ L2（LLM-as-judge）/ L3（人手）の3層 |
| **訓練データ仕様 (Training Data Spec)** | (instruction, output) ペアの収集方法・品質基準・量の目安 |
| **言語適用 (Language Applicability)** | このロールが言語非依存か、特定言語で個別 LoRA を作るか |
| **既知の限界 (Known Limitations)** | このロールの能力が及ばない領域。利用者の期待値調整用 |

## 3. Role Schema (`manifests/roles/<role-id>.yaml`)

```yaml
# 例: manifests/roles/tester.yaml
id: tester
display_name: "Test Generator"
description: |
  与えられたコードに対して単体テストおよび結合テストを生成する。
  仕様の記述からテストを作成することもできる。

io_contract:
  system_prompt_template: |
    You are a test generator. Given source code or specifications,
    produce comprehensive unit/integration tests in {language}.
    Cover: happy path, edge cases (null, empty, boundary), error handling.
  input_format: source_code | specification
  output_format: test_code

evaluation:
  l1_automatic:
    - name: compiles
      type: binary
      runner: language_specific_compiler
    - name: runs
      type: binary
      runner: language_specific_test_runner
    - name: pass_rate_on_correct_code
      type: percentage
    - name: mutation_kill_rate
      type: percentage
      runner: cargo-mutants | mutmut | stryker | gremlins
  l2_llm_judge:
    - name: test_quality
      criteria: "Are edge cases adequately covered? Are tests focused and readable?"
      judge_model: claude-sonnet  # or any frontier judge
  l3_human:
    - cadence: monthly
      sample_size: 10

training_data_spec:
  source_types:
    - existing_test_corpora    # public OSS の test/ 配下
    - llm_synthesized          # フロンティアで生成
    - operational_logs         # 運用ログから抽出
  quality_filters:
    - tests_must_compile
    - tests_must_run
    - mutation_score_above: 0.7
  minimum_pairs_per_language: 500
  recommended_pairs_per_language: 2000

language_applicability:
  per_language_lora: true      # 言語別に独立 LoRA を作る
  supported_languages:
    - python
    - typescript
    - rust
    - go
    - flutter
    # frameworks があれば言語に bundle
  language_bundles:
    python: [django, wagtail]
    typescript: [react]

known_limitations:
  - "テスト対象コードが大きい場合（>500行）品質低下"
  - "プロパティベーステスト（QuickCheck系）は苦手"
  - "外部APIを叩くテストの mock 構築は不安定"
```

## 4. Reference Roles（同梱予定）

キットの動作確認用および「典型例」として、以下の reference role を Phase ごとに整備する：

### 4.1 `tester`（Phase 1〜2 で実装）

- 責務: コードに対する単体・結合テスト生成
- 評価: 客観指標が豊富、最初に取り組むに最適
- 言語別 LoRA: あり（言語ごとのテスト作法が異なるため）

### 4.2 `formatter`（Phase 1 で実装）

- 責務: 差分要約 / コード整形 / コミットメッセージ生成
- 評価: 比較的単純（規則順守チェック）
- 言語別 LoRA: 弱め（ロジック自体は言語非依存に近い）

### 4.3 `security-reviewer`（Phase 2 で実装）

- 責務: コード脆弱性監査・改善提案
- 評価: 既知 CVE パターン検出率、偽陽性率
- 言語別 LoRA: あり（脆弱性パターンが言語固有）

### 4.4 `coder`（Phase 4〜5 で実験的に実装）

- 責務: 仕様からの実装
- 評価: 仕様充足率、テスト通過率
- 注: 現時点（2026年）ではローカル7Bでフロンティアに対抗するのは難しい。Phase 4 以降の base 進化次第で実用ライン到達を狙う実験ロール

### 4.5 拡張候補（将来）

| 候補 | 射程入りの目安 |
|---|---|
| `documenter`（API ドキュメント生成） | 近未来 |
| `refactorer`（リファクタリング提案） | 近未来 |
| `migration-assistant`（バージョン移行支援） | 近未来 |
| `architect`（設計判断） | 遠い将来 |
| `reviewer`（PR レビュー） | base 性能依存 |

## 5. Role × Base × Language の三次元

派生モデル artifact は3次元の直積で識別される：

```
artifacts/<base-id>/<role-id>[-<lang-id>]/lora.safetensors

例:
  artifacts/qwen2.5-coder-7b/tester-python/lora.safetensors
  artifacts/qwen2.5-coder-7b/tester-typescript/lora.safetensors
  artifacts/qwen2.5-coder-7b/formatter/lora.safetensors  ← 言語非依存
  artifacts/qwen3-coder-7b/tester-python/lora.safetensors  ← 新世代 base 上の同 role
```

base 切替時は **全 role × 全言語 LoRA を再生成** する必要がある。これは費用だが、避けられないコストとして受け入れる（LoRA は base に強く結合するため）。

## 6. 独自ロールの定義方法

利用者が自分の用途に合わせたロールを追加する手順：

1. `manifests/roles/<my-role>.yaml` を新規作成（schema は §3 参照）
2. `data/<my-role>/<lang>.jsonl` に訓練データを準備
3. `recipes/training/<my-role>-<lang>.yaml` で訓練設定を記述（既存 recipe をテンプレートにできる）
4. `just train ROLE=<my-role> LANG=<lang>` で訓練実行
5. `just eval ROLE=<my-role>` で評価
6. eval pass すれば deploy

reference roles と同じ仕組みで動作するため、利用者は oniwaban のコア実装を読まなくてもロール追加が可能。

## 7. Role 設計の判断基準

新しいロールを定義する前に確認すべきこと：

| 確認項目 | 望ましい状態 |
|---|---|
| **タスク境界が明確か** | 入出力契約が1段落で書ける |
| **客観評価が可能か** | L1（自動）の指標が少なくとも1つ存在する |
| **教師データが集まるか** | 500件以上の (input, output) ペアを集める手段がある |
| **Web 検索依存度が低いか** | リアルタイム情報なしで概ね応答できる |
| **base 性能が現時点で十分か** | vanilla base に system prompt だけ与えて 50% 以上の品質が出る |

これらが満たせないロールは、ロール定義として未成熟で、無理に育成しても eval が安定しない。**未成熟と判断したら定義を保留して時を待つ** のも正しい判断。

## 8. ロールと multi-agent システムの関係

oniwaban は特定の multi-agent システム（Discord ベース、API ベース、CLI ベース等）に依存しない。各ロールは **OpenAI 互換 API endpoint** として deploy されるため：

- Discord ボット: `/api/role/tester` を呼ぶ
- VS Code 拡張: 同上
- CLI ツール: 同上
- 独自フレームワーク: 同上

利用者側のシステムが何であれ、oniwaban が育成した派生モデルを HTTP で呼び出すだけで組み込める。

## 9. 実装範囲（Phase ごと）

| Phase | 実装範囲 |
|---|---|
| Phase 0 | role schema 設計、pydantic バリデーション、reference role の YAML 草稿 |
| Phase 1 | `formatter` reference role の end-to-end 実装、`tester` の準備 |
| Phase 2 | `tester` を全言語で実装、`security-reviewer` 着手 |
| Phase 3 | 自己改善ループを role-aware に拡張 |
| Phase 4 | `coder` を実験的に実装 |
| Phase 5 | 全 reference role の v1.0、独自ロール追加方法のドキュメント化 |
