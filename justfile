default:
    @just --list

# 依存解決
sync:
    uv sync --all-extras

# Lint
lint:
    uv run ruff check .

# Format
format:
    uv run ruff format .

# 型チェック
typecheck:
    uv run mypy src

# テスト
test:
    uv run pytest

# 一括チェック (CI と同等)
check: lint typecheck test
