# Integration Patterns

oniwaban は **OpenAI 互換 HTTP API** を contract として持ち、特定の multi-agent システムや特定のクライアントには依存しない。本ドキュメントでは想定される統合パターンを整理する。

## 1. 普遍的な contract

oniwaban が外部に提供するのは以下のみ：

```
POST <base-url>/v1/chat/completions
POST <base-url>/v1/completions
GET  <base-url>/v1/models
```

OpenAI / Anthropic / Google が事実上の標準としているメッセージフォーマットを踏襲する。これにより、**OpenAI API を消費するあらゆるツールがそのまま利用可能** になる。

### 1.1 Role / Language の指定方法

`model` フィールドで `<role>[-<language>]` を指定する。

| 指定 | 動作 |
|---|---|
| `oniwaban-tester-python` | tester role × Python の LoRA を適用 |
| `oniwaban-tester-typescript` | tester role × TypeScript |
| `oniwaban-formatter` | formatter role（言語非依存） |
| `oniwaban-security-reviewer-rust` | security-reviewer × Rust |
| `oniwaban-auto` | 入力内容から role / language を自動判定（Phase 5 以降） |

サーバー側の解決ロジック：
1. `model` を `<role>-<lang>` に分解
2. `manifests/roles/<role>.yaml` で role 定義をロード
3. `current.yaml` で指す base + abliterated + merged を準備
4. 該当 LoRA を hot-swap で適用
5. role の `system_prompt_template` を `system` メッセージに合成
6. 推論 → OpenAI 形式で返却

### 1.2 オプション機能の degradation

| 機能 | 対応 Phase | 未対応時の挙動 |
|---|---|---|
| Streaming（SSE） | Phase 1〜 | クライアントが streaming 要求 → 全文返却で degrade |
| Tool calling | Phase 4〜 | クライアントが tools 指定 → 警告ログ + tools 無視で応答 |
| 多ターン会話（messages 配列） | Phase 1〜 | 標準対応 |
| Session ID 管理 | 未対応（OpenAI 標準も未対応） | クライアントが messages 配列で履歴管理 |

## 2. 統合パターン

### 2.1 ai-team（Discord ベース multi-agent）

ai-team は LLMClient Protocol を持ち、provider 切替が YAML で可能な構造のため、**adapter 1ファイル追加**で oniwaban に接続できる。

**ai-team 側**:

```python
# src/llm/oniwaban_client.py
class OniwabanClient(LLMClient):
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url

    async def chat(
        self, messages, system, *,
        use_tools=False, agent_name="", session_id=None,
    ) -> ChatResult:
        payload = {
            "model": self._resolve_model(agent_name),
            "messages": [{"role": "system", "content": system}, *messages],
            "stream": False,
        }
        async with httpx.AsyncClient() as client:
            r = await client.post(f"{self.base_url}/v1/chat/completions", json=payload)
        text = r.json()["choices"][0]["message"]["content"]
        return ChatResult(response=text, session_id=None)
```

**ai-team `config/agents.yaml`**:

```yaml
agents:
  - name: ジェフ                    # Tester（Room1）
    provider: oniwaban
    model: oniwaban-tester-python   # Python タスクが多いコンテキスト

  - name: ヤン・ルカン               # Tester（Room2）
    provider: oniwaban
    model: oniwaban-tester-typescript

  - name: スティーブ                # Quality（Sonnet継続、対象外）
    provider: claude_code
    model: opus
```

**統合コスト**: 半日程度。`oniwaban_client.py` 実装 + agents.yaml 編集 + 動作確認。

### 2.2 IDE 拡張（Continue.dev / Cursor / etc.）

OpenAI 互換 API を設定する欄に oniwaban の base URL を入れるだけ。

**Continue.dev `~/.continue/config.json`**:

```json
{
  "models": [
    {
      "title": "oniwaban-coder",
      "provider": "openai",
      "model": "oniwaban-coder-python",
      "apiBase": "http://localhost:8000/v1"
    }
  ]
}
```

**統合コスト**: 数分。

### 2.3 OSS CLI ツール（aider / cline / open-interpreter / etc.）

これらは多くが OpenAI 互換 API をサポートしている。環境変数で base URL と model を切り替える。

```bash
export OPENAI_API_BASE=http://localhost:8000/v1
export OPENAI_API_KEY=dummy   # ローカルなので任意の値
aider --model oniwaban-tester-python
```

**統合コスト**: 数分。

### 2.4 GitHub Actions（PR レビュー自動化）

oniwaban をローカルマシンで起動 + Tailscale で外部到達可能にして curl で叩く。あるいは Self-hosted runner 上で起動する。

```yaml
# .github/workflows/auto-review.yml
- name: Generate test stubs for changed files
  run: |
    curl -X POST $ONIWABAN_URL/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "oniwaban-tester-python",
        "messages": [
          {"role": "user", "content": "Generate tests for: $CHANGED_FILE_CONTENT"}
        ]
      }'
```

**統合コスト**: 1〜2時間（runner 設定込み）。

### 2.5 Slack / Discord ボット（汎用）

ai-team と異なる multi-agent 設計でも、ボット側で oniwaban の HTTP API を叩くだけ。

```python
# 任意の Discord/Slack ボット
@bot.command()
async def review(ctx, *, code: str):
    response = await oniwaban_client.chat(
        model="oniwaban-security-reviewer",
        messages=[{"role": "user", "content": code}]
    )
    await ctx.send(response)
```

**統合コスト**: 数時間。

### 2.6 任意の OpenAI API 呼び出しコード

すべての OpenAI Python SDK / Node SDK / curl 呼び出しは、base URL の差し替えだけで oniwaban を呼べる。

```python
import openai
openai.api_base = "http://localhost:8000/v1"
openai.api_key = "dummy"

resp = openai.ChatCompletion.create(
    model="oniwaban-formatter",
    messages=[{"role": "user", "content": "..."}]
)
```

**統合コスト**: 1行変更。

## 3. 認証・公開範囲

oniwaban はローカルファースト。デフォルトでは認証なしで `localhost:8000` のみで listen する。外部から到達させたい場合：

| シナリオ | 推奨方法 |
|---|---|
| 同一マシン内（同じデスクトップ） | デフォルト設定のまま |
| 同一 LAN 内（自宅 NAS / 別マシン） | bind 0.0.0.0 + ファイアウォール設定 |
| 外部から（出先のラップトップ等） | **Tailscale 経由**（推奨） + ローカル認証トークン |
| インターネット公開 | 想定外（個人利用範囲） |

## 4. 拡張ポイント

### 4.1 独自 Role の追加

`manifests/roles/<my-role>.yaml` を追加し、訓練データを準備して `just train ROLE=<my-role>` を実行する。詳細は [role-abstraction.md §6](role-abstraction.md) 参照。

### 4.2 独自統合 adapter の作成

このドキュメントで触れていない multi-agent システム / IDE / フレームワークから接続したい場合：

1. **OpenAI 互換 API を叩くだけ**: 既存の OpenAI SDK 系ライブラリで base URL を差し替え（推奨、最速）
2. **ネイティブ adapter を書く**: 対象システムが独自プロトコルを持つ場合のみ。ai-team の `oniwaban_client.py` をテンプレートにできる

## 5. 想定外の使い方

oniwaban のスコープに含まれないため、推奨しない使い方：

- **インターネット公開（無認証）**: ローカルファースト前提のため、認証機構が薄い
- **商用 SaaS の組み込み**: 派生モデルのライセンス / abliteration の利用範囲が個人用想定
- **学習データの集積場として使う**: oniwaban は推論サーバーであり、データ収集基盤ではない

これらの用途には oniwaban ではなく、商用 LLM API か別の OSS プロジェクトを推奨する。
