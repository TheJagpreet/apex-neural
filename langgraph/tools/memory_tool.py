"""Apex Neural Memory Tool — Python implementation.

A direct port of the TypeScript ``MemoryTool`` class from the
``apex-neural-memory`` VS Code extension.  Memories are stored as
Markdown files with YAML frontmatter under a configurable workspace
directory (default: ``<cwd>/.github/memory/``).

The three public functions — ``memory_store``, ``memory_recall``, and
``memory_list`` — are registered as LangChain tools so that LangGraph
agents can call them during execution.
"""

from __future__ import annotations

import os
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

import yaml
from langchain_core.tools import tool
from pydantic import BaseModel, Field


# ── Data model ──────────────────────────────────────────────────────────

class ParsedMemory(BaseModel):
    """A single parsed memory entry."""

    agent: str = ""
    date: str = ""
    task: str = ""
    tags: list[str] = Field(default_factory=list)
    outcome: str = ""
    content: str = ""
    relative_path: str = ""


# ── Helpers (mirroring the TS helpers) ──────────────────────────────────

_MEMORY_ROOT_ENV = "APEX_MEMORY_ROOT"
"""Environment variable that overrides the default memory root."""


def _get_memory_root() -> Path:
    """Return the memory root directory.

    Resolution order:
    1. ``APEX_MEMORY_ROOT`` environment variable
    2. ``<cwd>/.github/memory``
    """
    env = os.getenv(_MEMORY_ROOT_ENV)
    if env:
        return Path(env)
    return Path.cwd() / ".github" / "memory"


def _sanitize_name(name: str) -> str:
    """Sanitize an agent name to prevent directory traversal."""
    cleaned = re.sub(r"[^a-z0-9-]", "", name.lower())[:30]
    return cleaned or "shared"


def _sanitize_tag(tag: str) -> str:
    """Sanitize a tag value."""
    return re.sub(r"[^a-z0-9-]", "", tag.lower())[:30]


def _slugify(text: str) -> str:
    """Convert a task description to a kebab-case slug."""
    slug = text.lower()
    slug = re.sub(r"[^a-z0-9\s-]", "", slug)
    slug = re.sub(r"\s+", "-", slug)
    slug = re.sub(r"-+", "-", slug)
    slug = slug.strip("-")
    return slug[:50]


def _format_timestamp(dt: datetime) -> str:
    """Format a datetime as ``YYYYMMDD-HHMMSS``."""
    return dt.strftime("%Y%m%d-%H%M%S")


def _escape_yaml(text: str) -> str:
    """Escape a string for safe YAML inclusion in double quotes."""
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


# ── Frontmatter parsing ────────────────────────────────────────────────

def _parse_frontmatter(raw: str, fallback_agent: str) -> ParsedMemory:
    """Parse YAML frontmatter from a markdown memory file."""
    mem = ParsedMemory(agent=fallback_agent)
    lines = raw.split("\n")

    if not lines or lines[0].strip() != "---":
        mem.content = raw
        return mem

    end_idx = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break

    if end_idx == -1:
        mem.content = raw
        return mem

    # Parse the YAML block
    fm_text = "\n".join(lines[1:end_idx])
    try:
        fm = yaml.safe_load(fm_text) or {}
    except yaml.YAMLError:
        fm = {}

    mem.agent = str(fm.get("agent", fallback_agent))
    mem.date = str(fm.get("date", ""))
    mem.task = str(fm.get("task", ""))
    mem.outcome = str(fm.get("outcome", ""))

    raw_tags = fm.get("tags", [])
    if isinstance(raw_tags, list):
        mem.tags = [str(t) for t in raw_tags]
    elif isinstance(raw_tags, str):
        mem.tags = [t.strip() for t in raw_tags.split(",") if t.strip()]

    # Everything after frontmatter is content
    mem.content = "\n".join(lines[end_idx + 1 :]).strip()
    return mem


def _scan_memories(
    memory_root: Path,
    agent_filter: str | None = None,
) -> list[ParsedMemory]:
    """Scan memory directories and parse all ``.md`` files."""
    results: list[ParsedMemory] = []

    if not memory_root.is_dir():
        return results

    if agent_filter:
        agent_dir = memory_root / agent_filter
        dirs = [agent_dir] if agent_dir.is_dir() else []
    else:
        dirs = [d for d in memory_root.iterdir() if d.is_dir()]

    for d in dirs:
        agent_name = d.name
        for md_file in sorted(d.glob("*.md")):
            if md_file.name in ("TEMPLATE.md", "README.md"):
                continue
            raw = md_file.read_text(encoding="utf-8")
            parsed = _parse_frontmatter(raw, agent_name)
            try:
                parsed.relative_path = str(
                    md_file.relative_to(memory_root.parent.parent)
                )
            except ValueError:
                parsed.relative_path = str(md_file)
            results.append(parsed)

    return results


# ── Public LangChain tools ──────────────────────────────────────────────


@tool
def memory_store(
    agent: str = "shared",
    task: str = "Untitled memory",
    tags: Sequence[str] = (),
    content: str = "",
    outcome: str = "completed",
) -> str:
    """Store a new memory as a Markdown file with YAML frontmatter.

    Args:
        agent: Agent name for scoping (e.g. planner, architect, shared).
        task: Brief task description used in the filename and frontmatter.
        tags: Categorisation tags (e.g. ["api", "validation"]).
        content: Markdown body of the memory.
        outcome: Task outcome — completed, approved, rejected, failed,
                 partial, or blocked.

    Returns:
        Confirmation message with the file path.
    """
    memory_root = _get_memory_root()
    safe_agent = _sanitize_name(agent)
    safe_tags = [_sanitize_tag(t) for t in tags]

    agent_dir = memory_root / safe_agent
    agent_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    timestamp = _format_timestamp(now)
    slug = _slugify(task)
    filename = f"{slug}-{timestamp}.md"
    file_path = agent_dir / filename

    iso_date = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    tags_yaml = f"[{', '.join(safe_tags)}]" if safe_tags else "[]"

    file_content = "\n".join(
        [
            "---",
            f"agent: {safe_agent}",
            f'date: "{iso_date}"',
            f'task: "{_escape_yaml(task)}"',
            f"tags: {tags_yaml}",
            f"outcome: {outcome}",
            "---",
            "",
            content,
            "",
        ]
    )

    file_path.write_text(file_content, encoding="utf-8")

    try:
        rel = file_path.relative_to(Path.cwd())
    except ValueError:
        rel = file_path

    return (
        f"Memory stored successfully.\n"
        f"  File: {rel}\n"
        f"  Agent: {safe_agent}\n"
        f"  Task: {task}\n"
        f"  Tags: {', '.join(safe_tags) or '(none)'}\n"
        f"  Outcome: {outcome}"
    )


@tool
def memory_recall(
    query: str = "",
    agent: str | None = None,
) -> str:
    """Search stored memories by query string.

    The query is matched (case-insensitive) against memory tags, task
    descriptions, content, and agent names.  Returns the 10 most recent
    matches.

    Args:
        query: Free-text search query.
        agent: Optional agent name filter.

    Returns:
        Formatted list of matching memories.
    """
    memory_root = _get_memory_root()

    if not memory_root.is_dir():
        return "No memories found. The memory directory does not exist yet."

    agent_filter = _sanitize_name(agent) if agent else None
    memories = _scan_memories(memory_root, agent_filter)

    if not memories:
        suffix = f' for agent "{agent_filter}"' if agent_filter else ""
        return f"No memories found{suffix}."

    q = query.lower()
    if q:
        matches = [
            m
            for m in memories
            if q in m.task.lower()
            or any(q in t.lower() for t in m.tags)
            or q in m.content.lower()
            or q in m.agent.lower()
        ]
    else:
        matches = memories

    if not matches:
        return f'No memories match query "{query}".'

    # Sort newest first
    matches.sort(key=lambda m: m.date, reverse=True)
    limited = matches[:10]

    parts: list[str] = [
        f"Found {len(matches)} matching "
        f"{'memory' if len(matches) == 1 else 'memories'}"
        f"{' (showing 10 most recent)' if len(matches) > 10 else ''}:",
        "",
    ]

    for mem in limited:
        parts.extend(
            [
                f"### {mem.relative_path}",
                f"- **Agent**: {mem.agent}",
                f"- **Date**: {mem.date}",
                f"- **Task**: {mem.task}",
                f"- **Tags**: {', '.join(mem.tags) or '(none)'}",
                f"- **Outcome**: {mem.outcome}",
                "",
                mem.content[:500]
                + ("\n...(truncated)" if len(mem.content) > 500 else ""),
                "",
                "---",
                "",
            ]
        )

    return "\n".join(parts)


@tool
def memory_list(agent: str | None = None) -> str:
    """List all stored memories, optionally filtered by agent.

    Args:
        agent: Optional agent name filter.

    Returns:
        Formatted listing grouped by agent.
    """
    memory_root = _get_memory_root()

    if not memory_root.is_dir():
        return "No memories found. The memory directory does not exist yet."

    agent_filter = _sanitize_name(agent) if agent else None
    memories = _scan_memories(memory_root, agent_filter)

    if not memories:
        suffix = f' for agent "{agent_filter}"' if agent_filter else ""
        return f"No memories found{suffix}."

    # Sort newest first
    memories.sort(key=lambda m: m.date, reverse=True)

    # Group by agent
    by_agent: dict[str, list[ParsedMemory]] = {}
    for mem in memories:
        by_agent.setdefault(mem.agent, []).append(mem)

    parts: list[str] = [f"Total memories: {len(memories)}", ""]

    for agent_name, agent_mems in by_agent.items():
        parts.append(f"## {agent_name} ({len(agent_mems)})")
        for mem in agent_mems:
            tags_str = ", ".join(mem.tags) or "(none)"
            parts.append(
                f"- **{mem.relative_path}** — {mem.task} [{tags_str}] "
                f"({mem.outcome}, {mem.date})"
            )
        parts.append("")

    return "\n".join(parts)
