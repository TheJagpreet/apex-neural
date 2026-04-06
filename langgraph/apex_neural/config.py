"""Ollama LLM configuration for the SDLC workflow.

Uses ``langchain-ollama`` to provide a local LLM via the Ollama REST API.
The model and base-URL are configurable through environment variables so
that CI and local development can use different setups.

Environment variables
---------------------
OLLAMA_MODEL      Model name (default: ``llama3.1``)
OLLAMA_BASE_URL   Ollama server URL (default: ``http://localhost:11434``)
OLLAMA_TEMPERATURE  Sampling temperature (default: ``0.2``)
"""

from __future__ import annotations

import os

from langchain_ollama import ChatOllama


def get_llm(
    *,
    model: str | None = None,
    temperature: float | None = None,
    base_url: str | None = None,
) -> ChatOllama:
    """Return a configured ``ChatOllama`` instance.

    Parameters are resolved in order: explicit argument → environment
    variable → built-in default.
    """
    resolved_model = model or os.getenv("OLLAMA_MODEL", "llama3.1")
    resolved_temp = (
        temperature
        if temperature is not None
        else float(os.getenv("OLLAMA_TEMPERATURE", "0.2"))
    )
    resolved_url = base_url or os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

    return ChatOllama(
        model=resolved_model,
        temperature=resolved_temp,
        base_url=resolved_url,
    )
