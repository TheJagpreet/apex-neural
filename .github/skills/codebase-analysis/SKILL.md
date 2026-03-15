---
name: codebase-analysis
description: "Analyzes codebase structure, patterns, conventions, and dependencies. Use when exploring a project for the first time or before making architectural decisions."
---

# Codebase Analysis Skill

When asked to analyze a codebase or understand project structure, follow these steps systematically.

## Step 1: Project Identification
- Read the root directory to find configuration files (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `pom.xml`, etc.)
- Identify the primary language and framework
- Read the main config file to understand dependencies and scripts

## Step 2: Directory Structure Mapping
- List top-level directories
- Identify the source code directory (`src/`, `lib/`, `app/`, etc.)
- Identify the test directory (`tests/`, `__tests__/`, `test/`, etc.)
- Identify configuration directories (`.github/`, `.vscode/`, `config/`, etc.)
- Map the module/package hierarchy

## Step 3: Pattern Recognition
Search for and document these patterns:

### Architecture Pattern
- Monolith vs microservices
- Layered (controllers → services → repositories)
- Feature-based (feature folders with all layers)
- Hexagonal / Clean Architecture

### Code Patterns
- Dependency injection approach
- Error handling strategy (exceptions, Result types, error codes)
- Logging approach
- Configuration management (env vars, config files, secrets management)
- API style (REST, GraphQL, gRPC)

### Naming Conventions
- File naming: camelCase, kebab-case, snake_case, PascalCase
- Variable naming conventions
- Function/method naming patterns
- Class/type naming patterns

## Step 4: Dependency Analysis
- List external dependencies and their purposes
- Identify core vs dev dependencies
- Note any deprecated or vulnerable packages
- Map internal module dependencies

## Step 5: Build & Run
- Identify build commands
- Identify test commands
- Identify lint/format commands
- Note any required environment setup

## Output Format
Present findings in a structured format:
```
## Codebase Profile: [Project Name]
Language: [lang] | Framework: [framework] | Architecture: [pattern]
Entry point: [file]
Build: [command] | Test: [command] | Lint: [command]

### Module Map
[tree structure of key directories]

### Key Patterns
[list of identified patterns with file references]

### Dependencies
[categorized dependency list]
```
