"""Tests for the Ollama LLM configuration."""

from __future__ import annotations

import os

import pytest

from apex_neural.config import get_llm


class TestGetLlm:
    def test_default_model(self):
        llm = get_llm()
        assert llm.model == "llama3.1"

    def test_explicit_model(self):
        llm = get_llm(model="codellama")
        assert llm.model == "codellama"

    def test_env_override(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("OLLAMA_MODEL", "mistral")
        llm = get_llm()
        assert llm.model == "mistral"

    def test_explicit_beats_env(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("OLLAMA_MODEL", "mistral")
        llm = get_llm(model="codellama")
        assert llm.model == "codellama"

    def test_default_temperature(self):
        llm = get_llm()
        assert llm.temperature == pytest.approx(0.2)

    def test_explicit_temperature(self):
        llm = get_llm(temperature=0.8)
        assert llm.temperature == pytest.approx(0.8)

    def test_default_base_url(self):
        llm = get_llm()
        assert llm.base_url == "http://localhost:11434"

    def test_env_base_url(self, monkeypatch: pytest.MonkeyPatch):
        monkeypatch.setenv("OLLAMA_BASE_URL", "http://remote:11434")
        llm = get_llm()
        assert llm.base_url == "http://remote:11434"
