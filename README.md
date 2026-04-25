# Oniwaban

> 個人専用 polyglot コードアシスタント

8言語のテスト生成と offensive security を両刀でこなすカスタム LLM プロジェクト。
[Sakana AI](https://sakana.ai/) の効率的モデル開発思想にインスパイアされ、フロンティアモデルの事前学習に対抗するのではなく、既存OSSモデルを **abliteration / mergekit / multi-LoRA hot-swap** で派生させて作る。

個人スケール（RTX 4070 Ti 12GB）で完結し、[ai-team](https://github.com/kkm-horikawa/ai-team) multi-agent システムに統合して運用ログから自己改善する。

## ステータス

🚧 **Phase 0（基盤構築） — 2026-04-25 開始**

| Phase | 期間 | 内容 | 状態 |
|---|---|---|---|
| 0 | Week 0-2 | bake-off / eval harness / abliteration tooling | 進行中 |
| 1 | Week 3-6 | oniwaban v0.1（abliteration + mergekit、ai-team統合） | 未着手 |
| 2 | Week 7-18 | Multi-LoRA 訓練（6言語/バンドル） | 未着手 |
| 3 | Week 19-26 | 自己改善ループ | 未着手 |
| 4 | Week 27-32 | Tool use 学習 | 未着手 |
| 5 | Week 33-40 | v1.0 仕上げ・公開判断 | 未着手 |

## カバー範囲

**プログラミング言語/フレームワーク**: Python, Django, Wagtail, TypeScript, React, Rust, Go, Flutter (Dart)

**役割**:
- ai-team Tester ロール（多言語テスト生成）
- ai-team Security Reviewer ロール（脆弱性監査・exploit写経）
- ai-team Formatter ロール（コードフォーマット・差分要約）

## アーキテクチャ概要

```
ai-team (Discord)
    │
    ├── Leader/Designer/Programmer ── Claude Sonnet/Opus（フロンティア残存）
    │
    └── Tester/SecReviewer/Formatter ── oniwaban (Local)
                                             │
                                       4070 Ti / 12GB
                                             │
                                  Qwen-Coder-7B (abliterated)
                                  + WhiteRabbitNeo merge
                                  + LoRA Hot-Swap Router
                                       ├── python+django+wagtail
                                       ├── typescript+react
                                       ├── rust
                                       ├── go
                                       ├── flutter
                                       └── security+exploit
```

詳細は [docs/architecture/overview.md](docs/architecture/overview.md) を参照。

## 開発環境

| 項目 | 値 |
|---|---|
| GPU | NVIDIA RTX 4070 Ti 12GB |
| RAM | 80GB |
| OS | Ubuntu 24.04 LTS（dual-boot with Windows 11） |
| Python | 3.12 + uv |
| Toolchain | axolotl / unsloth / mergekit / llama.cpp / ollama |

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

学習に用いる派生モデルは base model のライセンスに従う（Qwen2.5-Coder-7B は Apache-2.0、WhiteRabbitNeo は独自ライセンス、それぞれ MODEL_CARD.md で個別記載）。

## 関連プロジェクト

- [ai-team](https://github.com/kkm-horikawa/ai-team) — Discord ベース multi-agent 開発システム（統合先）
- [shikomi](https://github.com/shikomi-dev/shikomi) — Rust 製プロジェクト（テスト生成のターゲット）
