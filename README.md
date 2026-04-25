# Oniwaban

> ロール特化 LLM 育成キット

multi-agent システムで使う **「ロール特化モデル」を個人スケールで育成するためのキット**。
[Sakana AI](https://sakana.ai/) の効率的モデル開発思想にインスパイアされ、フロンティア基盤モデルの事前学習に対抗するのではなく、既存OSSモデルを **abliteration / mergekit / multi-LoRA hot-swap** で派生させて、特定ロール（フォーマッター・テスター・セキュリティレビュアー等）に特化させる手法をパイプライン化する。

## キットの3層構造

1. **Role 抽象**: 「フォーマッター」「テスター」のような **ロールを first-class** で扱う。各ロールは責務 / 入出力 / 評価基準 / 訓練データ仕様を YAML で宣言
2. **Base Agility**: 特定 base モデルに密結合せず、宣言的 manifest と recipe で base を差替可能。LLM の世代交代に追従する
3. **Pipeline as Code**: abliteration → merge → role-specific LoRA → eval → deploy を justfile + 宣言的 recipe で記述。1コマンドで全派生を再生成

**永続資産は派生モデル本体ではなく Pipeline / Role 定義 / Eval / Loop / API Surface**。新世代 base がリリースされれば 1 コマンドで全派生を再生成して切り替える。

## 「ロール」の時代変化への対応

「どのロールが個人スケールのローカル LLM で実現可能か」は、ベースモデルの能力向上と共に拡張していく：

| 時期 | 射程内のロール |
|---|---|
| **現在** | フォーマッター、テスター、セキュリティレビュアー（パターン認識・構造化タスク中心） |
| **近未来（〜2年）** | コーダー（実装ロール）、ドキュメンタリスト |
| **遠い将来（楽観）** | 設計責任者、テクニカルリーダー |

oniwaban のスコープは **「現時点でローカル実現可能なロール」を発見し、それらを再現可能に育成する** こと。ロール定義そのものが時代と共に進化する前提で設計する。

## ステータス

🚧 **Phase 0（基盤構築）— 進行中**

| Phase | 期間目安 | 内容 |
|---|---|---|
| 0 | Week 0-2 | bake-off / eval harness / abliteration tooling |
| 1 | Week 3-6 | v0.1（abliteration + mergekit、multi-agent system 統合） |
| 2 | Week 7-18 | Multi-LoRA 訓練（言語特化バンドル） |
| 3 | Week 19-26 | 自己改善ループ |
| 4 | Week 27-32 | Tool use 学習 |
| 5 | Week 33-40 | v1.0 仕上げ |

## 同梱する Reference Roles（初期実装スコープ）

キットの動作確認用に以下の reference role 定義を同梱予定。利用者は同形式で独自ロールを追加できる。

| Role | 責務 | 評価軸 |
|---|---|---|
| `tester` | コードに対する単体・結合テスト生成 | コンパイル成功率 / テスト実行成功率 / mutation kill rate |
| `formatter` | 差分要約・コード整形・コミットメッセージ生成 | フォーマット規則順守率 / 意味保存率 |
| `security-reviewer` | コード脆弱性監査・改善提案 | 既知 CVE パターン検出率 / 偽陽性率 |
| `coder`（実験段階） | 実装タスクの遂行 | 仕様充足率 / テスト通過率 |

**カバー対象言語/フレームワーク**: Python, Django, Wagtail, TypeScript, React, Rust, Go, Flutter (Dart)

各 role × 言語の組み合わせを LoRA として育成する（独立 LoRA + hot-swap）。

## 技術スタック

| 区分 | 採用 |
|---|---|
| Base model 候補 | Qwen2.5-Coder-7B-Instruct（第一候補、Phase 0 の bake-off で確定） |
| 訓練手法 | LoRA / QLoRA, model merging (mergekit), abliteration |
| 訓練フレームワーク | axolotl / unsloth / mlx-lm |
| 推論 | llama.cpp / ollama / vLLM |
| Eval | lm-evaluation-harness + 自作 multi-language harness |
| 言語 | Python 3.12（uv 管理） |

## 統合パターン

oniwaban は **OpenAI 互換 HTTP API** を contract として持つため、特定のシステムに依存しない。想定される統合パターン：

| 利用シーン | 統合コスト |
|---|---|
| Discord ベース multi-agent システム | adapter 1ファイル（既存の Provider 切替機構に乗る） |
| IDE 拡張（Continue.dev / Cursor 等） | 設定欄に base URL 入れるだけ |
| OSS CLI（aider / cline / open-interpreter 等） | `OPENAI_API_BASE` 環境変数のみ |
| GitHub Actions 自動化 | curl で叩くだけ |
| 任意の OpenAI SDK 利用コード | base URL 1行変更 |

詳細な統合手順は [integration-patterns.md](docs/architecture/integration-patterns.md) を参照。

## 学習用 Wiki

AI 開発の前提知識から oniwaban の設計思想まで、**高校生でも読める語り口** で解説した学習用 Wiki を別途用意：

📚 **[Wiki トップ →](https://github.com/oniwaban-dev/oniwaban/wiki)**

カテゴリ：基礎（Transformer / 量子化 / MoE）、学習手法（LoRA / 蒸留 / マージ / abliteration）、ツール（ollama / vLLM / axolotl / mergekit）、設計思想、運用インフラ、会話メモ — 全 35 記事。

## 設計ドキュメント

| ドキュメント | 内容 |
|---|---|
| [overview.md](docs/architecture/overview.md) | 全体設計とロードマップ |
| [model-build-pipeline.md](docs/architecture/model-build-pipeline.md) | base 差替可能な model build pipeline 仕様 |
| [role-abstraction.md](docs/architecture/role-abstraction.md) | Role 抽象と reference roles |
| [integration-patterns.md](docs/architecture/integration-patterns.md) | 外部システムからの統合パターン |

## 開発フロー

```bash
# 環境構築
just sync

# 品質チェック
just lint
just typecheck
just test

# 全部まとめて
just check
```

## ライセンス

[Apache-2.0](LICENSE)

派生モデルは base model のライセンスに従う（各モデルのリリース時に MODEL_CARD.md で個別記載予定）。

## 関連

- [shikomi](https://github.com/shikomi-dev/shikomi) — Rust 製プロジェクト（Rust LoRA の検証対象）
