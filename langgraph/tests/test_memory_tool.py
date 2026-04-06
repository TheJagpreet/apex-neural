"""Tests for the memory tool — Python port of the VS Code extension memory tool.

Mirrors the test coverage of
``extensions/apex-neural-memory/src/test/memoryTool.test.ts``.
"""

from __future__ import annotations

import os
import json
from pathlib import Path

import pytest

from langgraph.tools.memory_tool import (
    ParsedMemory,
    _escape_yaml,
    _format_timestamp,
    _get_memory_root,
    _parse_frontmatter,
    _sanitize_name,
    _sanitize_tag,
    _scan_memories,
    _slugify,
    memory_list,
    memory_recall,
    memory_store,
)
from datetime import datetime, timezone


# ── Helper function tests ───────────────────────────────────────────────


class TestSlugify:
    def test_basic(self):
        assert _slugify("Hello World") == "hello-world"

    def test_special_characters(self):
        assert _slugify("api: design patterns!") == "api-design-patterns"

    def test_multiple_spaces(self):
        assert _slugify("too   many   spaces") == "too-many-spaces"

    def test_truncation(self):
        long_text = "a" * 100
        assert len(_slugify(long_text)) <= 50

    def test_leading_trailing_dashes(self):
        assert _slugify("--hello--") == "hello"

    def test_empty_string(self):
        assert _slugify("") == ""


class TestSanitizeName:
    def test_basic(self):
        assert _sanitize_name("Planner") == "planner"

    def test_special_characters(self):
        assert _sanitize_name("my_agent!@#") == "myagent"

    def test_empty_returns_shared(self):
        assert _sanitize_name("") == "shared"

    def test_directory_traversal(self):
        assert _sanitize_name("../../etc") == "etc"

    def test_truncation(self):
        assert len(_sanitize_name("a" * 50)) <= 30


class TestSanitizeTag:
    def test_basic(self):
        assert _sanitize_tag("API") == "api"

    def test_special_characters(self):
        assert _sanitize_tag("bug-fix!") == "bug-fix"

    def test_truncation(self):
        assert len(_sanitize_tag("x" * 50)) <= 30


class TestFormatTimestamp:
    def test_format(self):
        dt = datetime(2026, 3, 25, 10, 30, 45, tzinfo=timezone.utc)
        assert _format_timestamp(dt) == "20260325-103045"

    def test_zero_padding(self):
        dt = datetime(2026, 1, 5, 3, 2, 1, tzinfo=timezone.utc)
        assert _format_timestamp(dt) == "20260105-030201"


class TestEscapeYaml:
    def test_quotes(self):
        assert _escape_yaml('say "hello"') == 'say \\"hello\\"'

    def test_newlines(self):
        assert _escape_yaml("line1\nline2") == "line1 line2"

    def test_backslashes(self):
        assert _escape_yaml("path\\to\\file") == "path\\\\to\\\\file"


class TestParseFrontmatter:
    def test_valid_frontmatter(self):
        raw = (
            "---\n"
            "agent: planner\n"
            'date: "2026-03-25T10:00:00Z"\n'
            'task: "Create a plan"\n'
            "tags: [api, validation]\n"
            "outcome: completed\n"
            "---\n"
            "\n"
            "Some content here."
        )
        mem = _parse_frontmatter(raw, "fallback")
        assert mem.agent == "planner"
        assert mem.date == "2026-03-25T10:00:00Z"
        assert mem.task == "Create a plan"
        assert mem.tags == ["api", "validation"]
        assert mem.outcome == "completed"
        assert "Some content here" in mem.content

    def test_no_frontmatter(self):
        raw = "Just plain content."
        mem = _parse_frontmatter(raw, "shared")
        assert mem.agent == "shared"
        assert mem.content == "Just plain content."

    def test_unclosed_frontmatter(self):
        raw = "---\nagent: planner\ntask: broken"
        mem = _parse_frontmatter(raw, "shared")
        assert mem.content == raw

    def test_empty_tags(self):
        raw = (
            "---\n"
            "agent: tester\n"
            "tags: []\n"
            "---\n"
            "Content."
        )
        mem = _parse_frontmatter(raw, "fallback")
        assert mem.tags == []


# ── Integration tests (file system) ────────────────────────────────────


@pytest.fixture()
def memory_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Create a temporary memory root and configure the env variable."""
    mem_root = tmp_path / ".github" / "memory"
    mem_root.mkdir(parents=True)
    monkeypatch.setenv("APEX_MEMORY_ROOT", str(mem_root))
    return mem_root


class TestMemoryStore:
    def test_creates_file(self, memory_root: Path):
        result = memory_store.invoke(
            {
                "agent": "planner",
                "task": "Test store",
                "tags": ["testing"],
                "content": "Some content",
                "outcome": "completed",
            }
        )
        assert "Memory stored successfully" in result

        # Verify the file exists
        agent_dir = memory_root / "planner"
        assert agent_dir.is_dir()
        files = list(agent_dir.glob("*.md"))
        assert len(files) == 1

        content = files[0].read_text()
        assert "agent: planner" in content
        assert "Some content" in content

    def test_default_agent_is_shared(self, memory_root: Path):
        result = memory_store.invoke(
            {
                "task": "Default agent test",
                "content": "Content",
            }
        )
        assert "Agent: shared" in result
        assert (memory_root / "shared").is_dir()

    def test_sanitizes_agent_name(self, memory_root: Path):
        memory_store.invoke(
            {
                "agent": "../../etc",
                "task": "Traversal test",
                "content": "Content",
            }
        )
        # Should create a safe directory name, not traverse
        assert not (memory_root / ".." / ".." / "etc").exists()
        assert (memory_root / "etc").is_dir()


class TestMemoryRecall:
    def test_recall_by_tag(self, memory_root: Path):
        memory_store.invoke(
            {
                "agent": "planner",
                "task": "API design",
                "tags": ["api", "design"],
                "content": "REST endpoint patterns",
            }
        )
        result = memory_recall.invoke({"query": "api"})
        assert "API design" in result or "api" in result.lower()

    def test_recall_empty(self, memory_root: Path):
        result = memory_recall.invoke({"query": "nonexistent"})
        assert "No memories" in result

    def test_recall_by_content(self, memory_root: Path):
        memory_store.invoke(
            {
                "agent": "architect",
                "task": "Database review",
                "tags": ["database"],
                "content": "PostgreSQL connection pooling",
            }
        )
        result = memory_recall.invoke({"query": "postgresql"})
        assert "Database review" in result or "postgresql" in result.lower()


class TestMemoryList:
    def test_list_all(self, memory_root: Path):
        memory_store.invoke(
            {"agent": "planner", "task": "Task 1", "content": "C1"}
        )
        memory_store.invoke(
            {"agent": "architect", "task": "Task 2", "content": "C2"}
        )
        result = memory_list.invoke({})
        assert "Total memories: 2" in result
        assert "planner" in result
        assert "architect" in result

    def test_list_filtered(self, memory_root: Path):
        memory_store.invoke(
            {"agent": "planner", "task": "Task 1", "content": "C1"}
        )
        memory_store.invoke(
            {"agent": "architect", "task": "Task 2", "content": "C2"}
        )
        result = memory_list.invoke({"agent": "planner"})
        assert "planner" in result
        assert "architect" not in result.lower() or "Total memories: 1" in result

    def test_list_empty(self, memory_root: Path):
        result = memory_list.invoke({})
        assert "No memories found" in result

    def test_no_directory(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("APEX_MEMORY_ROOT", str(tmp_path / "nonexistent"))
        result = memory_list.invoke({})
        assert "No memories found" in result


class TestScanMemories:
    def test_scan_with_filter(self, memory_root: Path):
        (memory_root / "planner").mkdir()
        (memory_root / "planner" / "test-20260325-100000.md").write_text(
            "---\nagent: planner\ntask: Test\ntags: []\noutcome: completed\n---\nContent"
        )
        results = _scan_memories(memory_root, "planner")
        assert len(results) == 1
        assert results[0].agent == "planner"

    def test_scan_skips_template(self, memory_root: Path):
        (memory_root / "shared").mkdir()
        (memory_root / "shared" / "TEMPLATE.md").write_text("Template")
        (memory_root / "shared" / "README.md").write_text("Readme")
        results = _scan_memories(memory_root, "shared")
        assert len(results) == 0

    def test_scan_nonexistent_dir(self, tmp_path: Path):
        results = _scan_memories(tmp_path / "nope")
        assert results == []
