# Model Build Pipeline

## 1. 設計目的

oniwaban の本体は「特定の派生モデル」ではなく **「任意の base モデルから派生スタックを再現可能に生成する宣言的パイプライン」** である。

LLM の世代交代速度（数ヶ月単位）に対し、特定 base に密結合したシステムは数ヶ月で陳腐化する。逆に、base 差替を first-class で扱う pipeline は、世代が進むごとに「より強い base 上に同じ recipe を適用する」だけで自動的に強化されていく。これが Sakana AI 的な「効率的なモデル進化」の個人スケール実装である。

## 2. パイプラインの構造

```
   ┌─────────────────────┐  ┌──────────────────────┐
   │ manifests/bases/    │  │ recipes/             │
   │ ├ qwen2.5-coder.yaml│  │ ├ abliteration/      │
   │ ├ qwen3-coder.yaml  │  │ ├ merge/             │
   │ ├ deepseek-v2.yaml  │  │ └ lora/{lang}.yaml   │
   │ └ current.yaml      │  └──────────┬───────────┘
   └──────────┬──────────┘             │
              │                         │
              ▼                         ▼
         ┌────────────────────────────────────┐
         │   Pipeline Orchestrator             │
         │   src/oniwaban/pipeline/             │
         │                                     │
         │   load_base() ──→ pull from HF Hub  │
         │   apply_abliteration() ──→ artifact │
         │   apply_merge() ──→ artifact        │
         │   train_lora(lang) ──→ artifact     │
         │   eval(api_surface) ──→ scores      │
         │   publish() ──→ push to HF Hub      │
         └──────────────┬─────────────────────┘
                        │
                        ▼
            artifacts/<base-id>/<recipe-set-id>/
              ├ abliterated.safetensors
              ├ merged.safetensors
              ├ lora-python-django-wagtail.safetensors
              ├ lora-typescript-react.safetensors
              ├ ... (各言語LoRA)
              └ eval-results.json
```

## 3. Manifest スキーマ

### 3.1 `manifests/bases/<base-id>.yaml`

```yaml
# 例: manifests/bases/qwen2.5-coder-7b.yaml
id: qwen2.5-coder-7b
hf_repo: Qwen/Qwen2.5-Coder-7B-Instruct
revision: main          # または specific commit SHA でピン
architecture: qwen2     # transformers の model_type と一致
tokenizer:
  type: tiktoken-compat
  vocab_size: 152064
context_length: 32768
license:
  spdx: Apache-2.0
  url: https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct/blob/main/LICENSE
capabilities:
  tool_use: true
  function_calling: openai-compatible
  multilingual_code: true
hardware:
  min_vram_gb: 12       # QLoRA 訓練時の必要 VRAM
  inference_dtypes: [fp16, int8, int4]
notes:
  - "Apache-2.0、コード性能 (HumanEval ~80%)、多言語 92 言語対応"
```

### 3.2 `manifests/current.yaml`

```yaml
# 現在採用中の base
base_id: qwen2.5-coder-7b
pinned_revision: <commit-sha>   # bake-off で確定した時点の revision
selected_at: 2026-04-30
selected_by: phase-0-bake-off
eval_baseline: eval_results/bake-off/2026-04-30.json
```

切替は PR で行う。`base_id` の変更を含む PR は `just full-rebuild` で全派生再生成 + eval 比較を要求される。

### 3.3 `recipes/abliteration/<recipe-id>.yaml`

```yaml
id: default
description: "Default refusal direction projection (Failspy method)"
method: refusal-direction-projection
hyperparameters:
  layer_target: middle-third  # どの層から direction 抽出するか
  num_harmless_prompts: 100
  num_harmful_prompts: 100
  intervention: weight-orthogonalization  # or runtime-projection
applies_to_architecture:
  - qwen2
  - qwen3
  - llama
  - gemma
  - deepseek
  # 他 architecture family 対応時に追記
```

### 3.4 `recipes/merge/<recipe-id>.yaml`

mergekit のフォーマットに準拠（透過配置）。oniwaban 固有のメタデータをヘッダに追加：

```yaml
id: security-blend
description: "Base + 派生モデルのブレンド"
mergekit:
  merge_method: dare_ties
  base_model: ${current.base_id}    # 動的に置換
  models:
    - model: <derivative-model-id>
      parameters:
        density: 0.5
        weight: 0.7
  parameters:
    int8_mask: true
  dtype: bfloat16
```

`${current.base_id}` のような変数展開は orchestrator が解決する。

### 3.5 `recipes/lora/<lang>.yaml`

axolotl のフォーマットに準拠（透過配置）。

```yaml
id: python-django-wagtail
description: "Python ecosystem (incl. Django, Wagtail)"
axolotl:
  base_model: ${current.base_id}
  load_in_4bit: true
  adapter: qlora
  lora_r: 32
  lora_alpha: 64
  lora_target_modules: [q_proj, k_proj, v_proj, o_proj]
  datasets:
    - path: data/python-django-wagtail.jsonl
      type: alpaca
  num_epochs: 3
  micro_batch_size: 1
  gradient_accumulation_steps: 16
  learning_rate: 1e-4
```

## 4. Orchestrator のサブコマンド

`justfile` 経由で公開する一次インターフェース：

| コマンド | 用途 |
|---|---|
| `just full-rebuild` | `current.yaml` の base に全 recipe を順次適用、最終 artifact + eval 結果を出力 |
| `just lora-only LANG` | 既存 base/abliterated/merged は再利用し、指定言語の LoRA のみ再訓練 |
| `just eval` | 現在 deploy 中の派生スタックに対して eval pipeline を実行 |
| `just compare BASE_A BASE_B` | 2つの base を全 recipe で再生成し eval スコアを並べる |
| `just promote BASE_ID` | bake-off 結果から `current.yaml` を更新（PR 自動生成） |

## 5. Base 切替の運用フロー

新 base モデルがリリースされた時の標準動作：

1. 開発者が `manifests/bases/<new-base>.yaml` を追加して PR
2. CI が `just compare current new-base` を実行（数時間〜十数時間）
3. eval スコア差分を PR コメントに自動投稿
4. レビュアーが結果を確認
5. 新 base が勝てば `just promote new-base` で `current.yaml` を更新する PR を生成
6. マージ後、推論サーバーが自動で新スタックを load

新 base が「劣る」場合も価値がある：
- 新世代の評価データとして `eval_results/base-comparison/` に蓄積
- 「Qwen3 が Qwen2.5 より N% 改善」のようなナラティブ素材になる

## 6. 実装範囲（Phase ごと）

| Phase | 実装範囲 |
|---|---|
| Phase 0 | manifest / recipe schema 設計、pydantic バリデーション、`just full-rebuild` の骨格（実際にはまだ各ステップが空実装でも可） |
| Phase 1 | abliteration / merge ステップを実装、初回 base に対して end-to-end 動作 |
| Phase 2 | lora ステップを実装、各言語 LoRA を順次追加 |
| Phase 3 | 自己改善ループを recipe として表現、`just lora-only --auto` で運用ログ → 再学習を自動化 |
| Phase 4 | tool use 訓練ステップ追加 |
| Phase 5 | `just compare` の自動 CI 化、新 base 自動追従 |

## 7. 関連設計判断

- **artifact のバージョニング**: `<base-id>/<recipe-set-hash>/<artifact-name>` の3段階で識別。recipe を変更すると hash が変わり別 artifact 扱い。
- **HF Hub への push 戦略**: Phase 5 まで private repo に push、公開判断は別途。
- **DVC / MLflow 等の採用判断**: 個人スケールでは不要。`justfile` + Python + JSON で十分。Phase 5 で複雑度が増したら検討。
- **recipe の DRY 化**: 言語 LoRA は共通テンプレ + パラメータ差分で表現したくなるが、最初は各 yaml をフルコピーで保つ（YAGNI、抽象化は3個目以降に）。

## 8. リスクと対策

| リスク | 対策 |
|---|---|
| Base ごとに architecture が違って abliteration が壊れる | `applies_to_architecture` 制約を recipe に明記、未対応 family は orchestrator が早期 fail |
| LoRA が base 間で互換でない | 当然壊れるので「base 切替時は全 LoRA 再学習」を前提とする。LoRA は base に強く結合する |
| 新 base のライセンスが商用不可 | manifest の `license` フィールドで明示、CI で warning |
| HF Hub の容量超過 | Phase 5 までは少数 base のみ管理、過去世代は archive 用 cold storage |
