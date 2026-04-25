# Oniwaban

> 個人専用 polyglot コードアシスタント

複数プログラミング言語のテスト生成に特化したカスタム LLM プロジェクト。
[Sakana AI](https://sakana.ai/) の効率的モデル開発思想にインスパイアされ、フロンティア基盤モデルの事前学習に対抗するのではなく、既存OSSモデルを **abliteration / mergekit / multi-LoRA hot-swap** で派生させて作る。

**設計の中核は「特定 base モデルへの依存をなくす」こと**。LLM の世代交代速度（数ヶ月単位）に追従するため、宣言的 manifest と recipe で base を差替可能にする。**永続資産は派生モデル本体ではなく Model Build Pipeline / Eval Pipeline / Self-Improvement Loop / API Surface の4つ**で、新世代 base がリリースされれば 1 コマンドで全派生を再生成して切り替える。

個人スケールのコンシューマGPU で完結し、運用ログから自己改善するループを構築する。

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

## カバー対象

**プログラミング言語/フレームワーク**: Python, Django, Wagtail, TypeScript, React, Rust, Go, Flutter (Dart)

**役割**:
- テスト生成（多言語）
- セキュリティレビュー（脆弱性監査）
- コードフォーマット・差分要約

## 技術スタック

| 区分 | 採用 |
|---|---|
| Base model 候補 | Qwen2.5-Coder-7B-Instruct（第一候補、Phase 0 の bake-off で確定） |
| 訓練手法 | LoRA / QLoRA, model merging (mergekit), abliteration |
| 訓練フレームワーク | axolotl / unsloth / mlx-lm |
| 推論 | llama.cpp / ollama / vLLM |
| Eval | lm-evaluation-harness + 自作 multi-language harness |
| 言語 | Python 3.12（uv 管理） |

## 設計ドキュメント

詳細は [docs/architecture/overview.md](docs/architecture/overview.md) を参照。

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
