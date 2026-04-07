# The Apex Ecosystem: A Unified Platform for Structured, Observable, and Sandboxed AI-Assisted Development

**How Four Composable Systems Turn Probabilistic AI into a Reproducible Engineering Workflow**

| | |
|---|---|
| **Version** | 1.0 |
| **Date** | April 7, 2026 |
| **Author** | Jagpreet Singh Sasan |
| **Organization** | TheJagpreet / Apex Project |
| **License** | MIT |
| **Classification** | Public |

---

## Executive Summary

The promise of AI-assisted software development is enormous. The reality is messier. Models hallucinate APIs. Agents drift off-scope. Execution environments are untrusted. Observability disappears the moment code leaves the editor. Teams adopting AI coding tools often find themselves trading one category of toil for another — instead of writing boilerplate, they're auditing AI output, debugging phantom imports, and wondering what the agent actually did inside their environment.

The Apex ecosystem is a direct response to these practical failures. It is composed of four repositories — **Apex Neural**, **Apex Venv**, **Apex Dashboard**, and **Apex Trace** — each solving a specific and well-bounded problem, designed to compose cleanly with the others.

**Apex Neural** imposes structure. It decomposes every coding task into four phase-gated stages — Planning, Architecture, Solutioning, and Testing — each handled by a specialized agent with restricted tools, explicit input requirements, and validated outputs. The result is a deterministic workflow layer that converts a probabilistic LLM session into something that behaves more like a CI/CD pipeline.

**Apex Venv** provides safety. It wraps Podman containers into a clean Go SDK and REST API, giving any system in the ecosystem a place to execute arbitrary code without touching the host environment. Agents can run tests, install dependencies, and clone repositories inside isolated, resource-limited sandboxes that disappear cleanly when they're done.

**Apex Dashboard** makes it visible. It is a React and TypeScript frontend that connects directly to the Apex Venv API, giving engineers a real-time window into active sandboxes, execution history, streaming output, and system health — no terminal hunting required.

**Apex Trace** keeps it honest. It implements OpenTelemetry-based distributed tracing across both the Go and TypeScript parts of the ecosystem, propagating trace context through HTTP headers, environment variables, and in-process maps so that a single logical workflow can be followed from the agent's first decision to the container's last shell command.

Together, these four systems form a platform that addresses what individual tools cannot: the end-to-end reliability of an AI-assisted development workflow, from the idea in the editor to the code running in a controlled environment, with full observability throughout.

This whitepaper is intended for software engineers, engineering leads, and DevOps practitioners who are moving beyond experimentation with AI coding tools and need to understand how to build something production-worthy on top of them.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Problem Statement](#problem-statement)
3. [The Apex Ecosystem: A Bird's-Eye View](#the-apex-ecosystem-a-birds-eye-view)
4. [Apex Neural — Structured Agent Workflows](#apex-neural--structured-agent-workflows)
5. [Apex Venv — Secure Sandbox Infrastructure](#apex-venv--secure-sandbox-infrastructure)
6. [Apex Dashboard — Operational Visibility](#apex-dashboard--operational-visibility)
7. [Apex Trace — Distributed Observability](#apex-trace--distributed-observability)
8. [How the Four Systems Work Together](#how-the-four-systems-work-together)
9. [Use Cases and Applications](#use-cases-and-applications)
10. [Comparative Analysis](#comparative-analysis)
11. [Security and Compliance](#security-and-compliance)
12. [Roadmap and Future Work](#roadmap-and-future-work)
13. [Conclusion](#conclusion)
14. [Appendices](#appendices)

---

## Introduction

AI-assisted software development has crossed the threshold from novelty to norm. GitHub Copilot, Claude Code, Cursor, and a growing ecosystem of agent frameworks have made it possible for a developer to describe a feature in natural language and receive a working implementation in seconds. The global market for AI in software development, valued at roughly $674 million in 2024, is projected to reach $15.7 billion by 2033, driven by teams reporting 15% or more velocity improvement from AI tool adoption.

But velocity is not reliability. And the teams who have moved beyond the honeymoon phase of AI adoption are discovering that the tools which are remarkable for isolated tasks become brittle at the boundaries: between agents, between environments, between systems, and between the editor and the runtime. A model that writes excellent code in isolation can still produce a pull request that silently breaks a downstream service, runs untested code in a shared environment, or leaves no trace of what it actually did.

These are not model-quality problems. They are systems-design problems. And they require systems-design solutions.

The Apex ecosystem was built from that premise. Each of its four components attacks a different failure mode that emerges when AI coding tools are used in real engineering workflows:

- **Neural** attacks *structural chaos* — the tendency of unconstrained AI sessions to drift, hallucinate, and lose context over long tasks.
- **Venv** attacks *environmental risk* — the problem of running agent-generated code somewhere safe without contaminating production or developer machines.
- **Dashboard** attacks *operational opacity* — the difficulty of knowing what sandboxes are running, what they're doing, and whether the infrastructure is healthy.
- **Trace** attacks *observability gaps* — the loss of a unified execution thread as work flows between UI, API, containers, and agents.

None of these components requires the others to function. But they are designed to fit together, and the combination is meaningfully greater than the sum of its parts.

---

## Problem Statement

### The Four Failure Modes of AI-Assisted Development at Scale

Adopting a single AI coding tool is relatively straightforward. Adopting a coherent AI-assisted development workflow — one that is reproducible, auditable, and safe enough for a team to stake production quality on — is a different challenge entirely. Four distinct failure modes emerge at this layer.

#### 1. Structural Chaos in Long-Running Agent Sessions

LLM conversations degrade over time. As context accumulates — tool call results, intermediate reasoning, code snippets, revision history — the model's attention gets distributed across an increasingly noisy signal. It starts contradicting decisions it made earlier. It re-analyzes files it already read. It expands scope because nothing explicitly prevents it from doing so.

This is not a bug in any specific model. It is an architectural property of running a generative model as a single, long-running session. The fix is not better prompting; it is structural decomposition. Tasks need to be broken into phases, and phases need to be isolated from each other so that each agent receives exactly the context it needs — no more, no less.

#### 2. Untrusted Execution Environments

When an AI agent needs to run code — to verify its implementation, execute tests, or validate an install — it needs somewhere to do that. The options available to most teams are: the developer's local machine, a shared staging environment, or a CI runner.

None of these is ideal. The developer's machine is a snowflake; results are non-reproducible and the environment can be corrupted. Staging is a shared resource; an agent that installs a bad dependency or runs a runaway process affects everyone. CI is clean but slow, and requires a commit before anything can execute.

What is needed is an on-demand, isolated execution environment that can be created in seconds, given a defined image and resource limits, and destroyed when the task completes. This is a solved problem in the infrastructure world; it just hasn't been wired into the AI development workflow.

#### 3. Invisible Infrastructure

Container-based sandboxes are powerful, but they are also opaque. Without a management interface, engineers have no visibility into which sandboxes are running, how long they've been alive, what commands have been executed, whether output indicates a problem, or whether the sandbox service itself is healthy. This opacity creates a class of operational failure that is entirely avoidable with a simple, purpose-built frontend.

#### 4. Trace Discontinuity

A modern AI-assisted development workflow is not a single process. It involves a UI that triggers an API call, which launches a container, which runs a shell command, which produces output that flows back through the API to the UI. Each of these hops is a potential observability gap. If something goes wrong anywhere in the chain, reconstructing the execution path from logs scattered across four different components is tedious and error-prone.

Distributed tracing was invented to solve exactly this problem for microservices. Applying the same approach to the AI development workflow — propagating a trace context from the UI through the API into the container environment — gives every system in the ecosystem a shared execution identifier and a common observability substrate.

### The Cost of Addressing These Problems in Isolation

Each of these four problems has available solutions. Prompt engineering can partially address structural chaos. Docker can provide isolated environments. A few curl commands can reveal sandbox status. Log aggregation can approximate distributed tracing. But stitching these point solutions together for every project, every team, and every agent framework is exactly the kind of infrastructure toil that consumes engineering capacity without delivering product value.

The Apex ecosystem exists to absorb that toil into a reusable, composable platform so that teams can focus on what they're actually trying to build.

---

## The Apex Ecosystem: A Bird's-Eye View

Before diving into each component, it helps to see the whole picture.

```
  Developer / VS Code
        |
        | (task description, natural language)
        v
+---------------------------+
|      APEX NEURAL          |  <-- Structured agent orchestration
|  Phase-gated workflow     |      (Planning --> Architecture --> Solutioning --> Testing)
|  Memory handoffs          |      VS Code Copilot Chat agents
|  Tool-level access ctrl   |
+---------------------------+
        |
        | (when agent needs to execute code or run tests)
        v
+---------------------------+     +---------------------------+
|      APEX VENV            | --> |    APEX DASHBOARD         |
|  REST API + Go SDK        |     |  React / TypeScript UI    |
|  Podman containers        |     |  Real-time sandbox view   |
|  Streaming exec output    |     |  Health monitoring        |
+---------------------------+     +---------------------------+
        |
        | (trace context propagated via env vars into container)
        |
+---------------------------+
|      APEX TRACE           |  <-- Distributed observability
|  OpenTelemetry (Go + TS)  |      Spans flow from UI --> API --> container
|  OTLP to Jaeger / Tempo   |      Unified execution thread across all hops
+---------------------------+
```

Each box is an independently deployable system. Apex Neural runs entirely inside VS Code; it needs no external infrastructure. Apex Venv is a Go binary that can run on any machine with Podman installed. Apex Dashboard is a static React app that can be served anywhere. Apex Trace is a library included in each system, not a server to deploy.

The arrows in the diagram represent real integration points: HTTP calls, environment variable injection, trace context propagation. These integration points are explicit and minimal. Swapping out any one component — using a different frontend, a different sandbox technology, a different observability backend — requires changing only the boundary between components, not the internals of anything else.

---

## Apex Neural — Structured Agent Workflows

### What It Does

Apex Neural is a VS Code Copilot Chat plugin that imposes a deterministic, four-phase workflow on top of AI coding sessions. Every task — feature, bug fix, refactor, migration — goes through the same sequence: a Planner thinks through the implementation, an Architect reviews the plan and validates it against existing patterns, a Solutioner implements the approved plan, and a Tester validates the result.

What makes this different from just asking a single agent to do all of those things is that each phase runs in an isolated agent context with restricted tools, receives only the structured output of the previous phase (not the full conversation history), and produces a validated artifact that is saved to the filesystem before the next phase can begin.

### The Four-Phase Pipeline

```
User describes task
        |
        v
+----------------------+
|     ORCHESTRATOR     |  <-- Coordinator. Never writes code.
|  Manages state and   |      Enforces iteration limits.
|  memory handoffs.    |      Escalates to human when stuck.
+----------------------+
        |
        v
+----------------------+     verdict: NEEDS_REVISION
|      PLANNER         | <--------------------------+
|  (read-only tools)   |                            |
|  Reads codebase.     |                            |
|  Produces: plan.md   |                            |
+----------------------+                            |
        |                                           |
        v                                           |
+----------------------+                            |
|     ARCHITECT        | ---------------------------+
|  (read-only tools)   |  (max 3 iterations)
|  Validates patterns. |
|  Issues verdict:     |
|  APPROVED or         |
|  NEEDS_REVISION      |
+----------------------+
        |
        | verdict: APPROVED
        v
+----------------------+     test result: FAIL
|     SOLUTIONER       | <--------------------------+
|  (edit tools)        |                            |
|  Implements plan.    |                            |
|  Produces: impl.md   |                            |
+----------------------+                            |
        |                                           |
        v                                           |
+----------------------+                            |
|       TESTER         | ---------------------------+
|  (edit + run tools)  |  (max 5 iterations)
|  Runs tests.         |
|  Issues verdict:     |
|  PASS / FAIL         |
+----------------------+
        |
        | verdict: PASS
        v
   Task complete.
   All artifacts saved to .github/memory/
```

### Agent Roles and Tool Restrictions

The tool restriction model is the core enforcement mechanism of Apex Neural. It is not a convention or a guideline — it is a hard configuration boundary enforced by VS Code's Copilot Chat agent infrastructure.

| Agent | Phase | Can Read Code | Can Edit Code | Can Run Commands | Key Output |
|---|---|---|---|---|---|
| **Orchestrator** | Coordinator | Yes | No | No | Workflow state |
| **Planner** | 1 | Yes | No | No | `current-plan-<timestamp>.md` |
| **Architect** | 2 | Yes | No | No | `architecture-decision-<timestamp>.md` |
| **Solutioner** | 3 | Yes | Yes | Yes | `implementation-log-<timestamp>.md` |
| **Tester** | 4 | Yes | Yes (tests) | Yes | `test-results-<timestamp>.md` |
| **Maintenance** | On-demand | Yes | No | Yes | Health reports |

A Planner that lacks the `edit` tool cannot refactor code, regardless of what it decides to do. The model's intentions are irrelevant; the capability is simply absent. This is the structural intervention that prevents scope drift.

### The Memory System

Every artifact produced by every phase is saved to `.github/memory/` as a markdown file with YAML frontmatter. This directory lives inside the project repository, making the entire audit trail version-controlled and diff-able alongside the code it describes.

```
.github/memory/
├── base/           <-- Foundational project context (tech stack, conventions)
├── orchestrator/   <-- Workflow state snapshots
├── planner/        <-- Plan documents for each task
├── architect/      <-- Architecture decisions and verdicts
├── solutioner/     <-- Implementation logs
├── tester/         <-- Test reports and failure analyses
└── shared/         <-- Cross-agent discoveries (APIs, patterns)
```

Each memory file follows a consistent schema:

```yaml
---
agent: architect
type: decision
task: "Add rate limiting to /api/users endpoint"
timestamp: "2026-04-07T14:22:00Z"
verdict: APPROVED
---

## Architecture Decision

...structured content...
```

This schema is shared between the VS Code TypeScript implementation and an equivalent Python implementation, meaning the same memory format works whether Neural is running as a VS Code plugin or as a Python/LangGraph workflow.

### Phase Gates and Hooks

Lifecycle hooks execute at the entry and exit of each phase. They validate that required artifacts were produced, check for structural completeness, and block phase transitions if requirements are not met. An agent that tries to declare completion without saving its required output artifact will be prompted to finish the job before the Orchestrator advances the workflow.

Hooks ship as paired scripts — one in PowerShell, one in bash — dispatched at runtime by a Node.js runner that detects the host platform. This cross-platform approach ensures consistent behavior on Windows, macOS, and Linux without requiring contributors to maintain separate CI configurations.

### Python / LangGraph Variant

Beyond the VS Code plugin, Apex Neural also exposes a Python implementation built on LangGraph and LangChain. This variant targets teams who need to embed the multi-agent workflow into a broader automation pipeline — CI systems, batch processing, or custom tooling — rather than running it interactively inside an editor.

The Python variant uses Ollama for local LLM inference (default: `devstral` model), preserving the ecosystem's commitment to local-first operation without mandatory cloud API dependencies. The state machine, iteration limits, memory format, and agent roles are identical across both implementations.

---

## Apex Venv — Secure Sandbox Infrastructure

### What It Does

Apex Venv provides on-demand, isolated execution environments for running arbitrary code. It wraps Podman — a daemonless, rootless container runtime — into a clean Go SDK and REST API that any system in the ecosystem can call to create a sandbox, run commands inside it, retrieve output, copy files in or out, and destroy the environment when finished.

The design philosophy is deliberate minimalism. Apex Venv does not try to be a full container orchestration platform. It does one thing — provide clean, isolated execution environments on demand — and exposes that capability through an interface simple enough for an AI agent to use reliably.

### The Sandbox Lifecycle

```
caller                      apex-venv                     podman
  |                              |                            |
  | POST /api/sandboxes          |                            |
  | { image, timeout, repo }     |                            |
  |----------------------------->|                            |
  |                              | podman run -d --rm ...     |
  |                              |--------------------------->|
  |                              |                            | (container starts)
  |                              |<---------------------------|
  |                              | container ID               |
  |<-----------------------------|                            |
  | { id, status: "running" }    |                            |
  |                              |                            |
  | POST /api/sandboxes/{id}/exec|                            |
  | { command: "npm test" }      |                            |
  |----------------------------->|                            |
  |                              | podman exec {id} npm test  |
  |                              |--------------------------->|
  |                              |                (streaming) |
  |<-----------------------------| output lines...            |
  | SSE stream / JSON response   |                            |
  |                              |                            |
  | DELETE /api/sandboxes/{id}   |                            |
  |----------------------------->|                            |
  |                              | podman stop {id}           |
  |                              |--------------------------->|
  |                              |              (container gone)
  |<-----------------------------|                            |
  | 204 No Content               |                            |
```

### REST API Surface

The API is intentionally narrow. There are six endpoint groups:

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/sandboxes` | `POST` | Create a new sandbox |
| `/api/sandboxes` | `GET` | List all active sandboxes |
| `/api/sandboxes/{id}` | `GET` | Get status of a specific sandbox |
| `/api/sandboxes/{id}` | `DELETE` | Destroy a sandbox |
| `/api/sandboxes/{id}/exec` | `POST` | Execute a command (buffered response) |
| `/api/sandboxes/{id}/exec/stream` | `POST` | Execute a command (Server-Sent Events streaming) |
| `/api/sandboxes/{id}/copy-to` | `POST` | Copy a file from host into the sandbox |
| `/api/sandboxes/{id}/copy-from` | `POST` | Copy a file out of the sandbox to host |
| `/health` | `GET` | Service health check |

### The Go SDK

For Go callers — including tools built on top of Apex Venv — the SDK exposes a clean interface that hides the HTTP transport entirely:

```go
// Create a sandbox with a Python 3.12 image and 10-minute timeout
sandbox, err := venv.Create(ctx, CreateRequest{
    Image:   "python:3.12",
    Timeout: 10 * time.Minute,
    GitRepo: "https://github.com/org/repo",
})

// Execute a command and get the output
result, err := venv.Exec(ctx, sandbox.ID, ExecRequest{
    Command: "python -m pytest tests/",
})

// Stream output line by line for real-time display
stream, err := venv.ExecStream(ctx, sandbox.ID, ExecRequest{
    Command: "npm run build",
})
for line := range stream {
    fmt.Println(line)
}

// Copy a file into the sandbox
err = venv.CopyTo(ctx, sandbox.ID, CopyToRequest{
    HostPath:  "/tmp/config.json",
    SandboxPath: "/app/config.json",
})

// Clean up
err = venv.Destroy(ctx, sandbox.ID)
```

### MCP Server Interface

For AI agents — including those running inside Apex Neural — Apex Venv exposes an MCP (Model Context Protocol) server that registers sandbox management as tools the agent can call directly. This means a Tester agent can create a sandbox, run the test suite, retrieve results, and clean up, all within its normal tool-calling interface, without any human involvement in the infrastructure layer.

### Pre-built Images and Resource Limits

Three base images ship with Apex Venv out of the box:

| Image | Use Case |
|---|---|
| `ubuntu:22.04` | General-purpose shell environments |
| `python:3.12` | Python development, data science, ML |
| `node:20` | JavaScript/TypeScript, frontend tooling |

Each sandbox is created with configurable resource limits on CPU and memory, enforced by Podman's cgroup integration. Sandboxes that exceed their configured timeout are destroyed automatically, preventing resource leaks from forgotten or runaway agent sessions.

---

## Apex Dashboard — Operational Visibility

### What It Does

Apex Dashboard is a React and TypeScript frontend that provides a real-time management interface for Apex Venv sandboxes. It is the operational layer that makes the sandbox infrastructure observable and controllable without requiring terminal access or API knowledge.

The audience for the dashboard is the engineer who needs to know: what sandboxes are currently running, what is happening inside them, whether the venv service is healthy, and how to interact with a sandbox without writing API calls by hand.

### Application Structure

```
App (React Router)
├── /                   --> Dashboard (system overview, health status)
├── /sandboxes          --> Sandbox list (polling, status badges)
├── /sandboxes/create   --> Create sandbox form (image, timeout, git repo)
└── /sandboxes/:id      --> Sandbox detail (exec, stream output, file ops)
```

The routing is flat and purpose-driven. Each route maps to one operational concern, making it straightforward to bookmark a specific sandbox or share a link to the sandbox creation form.

### Real-time Data and Polling

The dashboard uses polling rather than WebSockets for its live data, a deliberate choice that keeps the backend simple (the venv REST API does not need to maintain persistent connections) while still providing a sufficiently responsive experience for sandbox management.

| Data | Polling Interval |
|---|---|
| Sandbox list | Every 10 seconds |
| System health | Every 15 seconds |
| Individual sandbox status | Every 5 seconds |

These intervals are configured in the hook layer (`hooks/useSandboxes.ts`) and can be adjusted without modifying component code. For sandbox execution output, the dashboard connects to the SSE (Server-Sent Events) streaming endpoint, which provides true real-time output without polling.

### Type-Safe API Client

The dashboard's API client is a typed Axios instance that shares its type definitions with the venv REST API. Every request and response shape is explicitly typed:

```typescript
// Types are shared between client and server
interface CreateSandboxRequest {
    image: string;
    timeout?: number;    // seconds
    gitRepo?: string;    // cloned at creation time
    env?: Record<string, string>;
}

interface Sandbox {
    id: string;
    image: string;
    status: "running" | "stopped" | "error";
    createdAt: string;
    expiresAt: string;
}
```

This type alignment means that API changes surface as compile errors in the dashboard rather than as runtime failures, making the interface between the two systems explicit and verifiable.

### Toast Notifications and Error Handling

The dashboard implements a global `ToastContext` for user feedback. Every API operation — creating a sandbox, executing a command, copying a file — produces a toast notification on success or failure. This makes the dashboard's operational feedback immediate and consistent without requiring the user to inspect network requests to understand what happened.

---

## Apex Trace — Distributed Observability

### What It Does

Apex Trace implements distributed tracing across the entire Apex ecosystem using OpenTelemetry. It ships as two libraries — one in Go for Apex Venv, one in TypeScript for Apex Dashboard — that together ensure a single logical workflow can be traced from the first user interaction in the browser through the API layer and into the container environment where code actually executes.

Traces are exported via OTLP (OpenTelemetry Protocol) over HTTP to any compatible backend — Jaeger, Grafana Tempo, or a cloud observability platform — giving teams a standard interface for visualization and alerting regardless of their existing tooling.

### Why This Matters

Without distributed tracing, debugging a failure in the Apex ecosystem looks like this:

```
Something went wrong.

Was it...
  - The dashboard's API call? (check browser network tab)
  - The venv service's routing? (check Go logs)
  - The container execution? (check... where exactly?)
  - The trace context propagation? (check what?)

Good luck correlating these across four different log streams.
```

With distributed tracing, it looks like this:

```
trace_id: 4bf92f3577b34da6

span: browser.CreateSandbox        duration: 245ms   status: ok
  span: api.POST /api/sandboxes    duration: 230ms   status: ok
    span: podman.run               duration: 180ms   status: ok

span: browser.ExecStream           duration: 3.2s    status: error
  span: api.POST /exec/stream      duration: 3.1s    status: error
    span: podman.exec              duration: 3.1s    status: error
      error: exit code 1, "ModuleNotFoundError: numpy"
```

One trace ID. One timeline. The failure is immediately localized to the container's Python environment.

### The Go Package

For Apex Venv (and any other Go service in the ecosystem), Apex Trace provides context propagation utilities built on the OpenTelemetry Go SDK:

```go
// Propagate trace context into a map (for HTTP headers or storage)
traceMap := apextrace.InjectToMap(ctx)

// Restore trace context from a map
ctx = apextrace.ExtractFromMap(ctx, traceMap)

// Propagate trace context into environment variables (for subprocess execution)
envVars := apextrace.InjectToEnv(ctx)
// --> { "TRACEPARENT": "00-4bf92f3577b34da6...", "TRACESTATE": "..." }

// Restore trace context from environment variables
ctx = apextrace.ExtractFromEnv(ctx, envVars)
```

The `InjectToEnv` and `ExtractFromEnv` functions are the key integration point between Apex Venv and the container environment. When a sandbox executes a command, the trace context from the API request is injected into the container's environment variables. Any observability-instrumented code running inside the container automatically participates in the parent trace.

```
HTTP request arrives at apex-venv
         |
         | (contains W3C traceparent header)
         v
  ExtractFromMap() --> context with trace
         |
         v
  InjectToEnv(ctx) --> { TRACEPARENT: "00-4bf9...", TRACESTATE: "" }
         |
         v
  podman exec --env TRACEPARENT=... --env TRACESTATE=... {id} {command}
         |
         v
  (code inside container sees trace context in os.environ)
```

### The TypeScript / React Package

For Apex Dashboard, Apex Trace provides React-friendly wrappers around the OpenTelemetry JavaScript SDK:

```typescript
// Wrap the entire app in the tracing provider
<TracingProvider serviceName="apex-dashboard" endpoint="http://localhost:4318">
  <App />
</TracingProvider>

// Add page-level spans with the hook
function SandboxDetailPage() {
  const { startSpan } = useTracing();

  const handleExec = async (command: string) => {
    const span = startSpan("sandbox.exec", { "sandbox.id": id });
    try {
      await api.exec(id, { command });
    } finally {
      span.end();
    }
  };
}

// Auto-instrument all Axios requests
const client = axios.create({ baseURL: VENV_API_URL });
createAxiosTracingInterceptor(client); // adds traceparent headers to every request
```

The `createAxiosTracingInterceptor` function is the bridge between the dashboard and the venv API. It automatically injects trace context into every outgoing HTTP request, ensuring that API-level spans are children of the browser-level span that triggered them, producing a coherent, nested trace timeline.

### Trace Propagation Through the Ecosystem

```
User clicks "Execute" in Dashboard
        |
        | span: browser.SandboxExec
        v
TracingProvider (React) --> injects traceparent header
        |
        v
Axios request --> POST /api/sandboxes/{id}/exec/stream
        |           (header: traceparent: 00-4bf92f3577b34da6-a7c3b5d2e6f8a1b0-01)
        v
apex-venv (Go) --> ExtractFromMap(ctx, requestHeaders)
        |          span: api.ExecStream
        v
InjectToEnv(ctx) --> TRACEPARENT=00-4bf92f3577b34da6-...
        |
        v
podman exec --env TRACEPARENT=... sh -c "npm test"
        |
        v
(test runner, if instrumented, continues the trace)
        |
        v
All spans exported to Jaeger/Tempo under trace_id: 4bf92f3577b34da6
```

---

## How the Four Systems Work Together

### The Integration Architecture

The four components integrate at well-defined, minimal boundaries. No component reaches into another's internals. The integration points are:

1. **Dashboard → Venv**: HTTP REST API calls. The dashboard uses Venv as its backend. Types are aligned.
2. **Venv → Trace (Go)**: The `apextrace` package is imported by Venv to propagate context into API spans and container environment variables.
3. **Dashboard → Trace (TypeScript)**: The `@apex-trace/js` package wraps the Dashboard's React app and Axios client.
4. **Neural → Venv (MCP)**: The Tester agent in Apex Neural calls Venv's MCP server to create sandboxes and run tests during the Testing phase.
5. **Neural → Trace**: Agent handoff context can carry trace headers, allowing the observability thread to extend into the agent workflow layer.

### A Complete Workflow Walkthrough

Here is what a complete Apex-assisted development task looks like from start to finish:

```
Step 1: Developer describes task in VS Code
        --> @orchestrator "Add rate limiting to the /api/users endpoint"

Step 2: Apex Neural -- Planning Phase
        Planner reads the codebase (read-only)
        Produces: .github/memory/planner/current-plan-2026-04-07T14-00.md

Step 3: Apex Neural -- Architecture Phase
        Architect reads the plan and codebase (read-only)
        Validates against existing patterns
        Produces verdict: APPROVED
        Produces: .github/memory/architect/architecture-decision-2026-04-07T14-05.md

Step 4: Apex Neural -- Solutioning Phase
        Solutioner reads approved plan and architecture decision
        Edits source files (edit tools enabled)
        Produces: .github/memory/solutioner/implementation-log-2026-04-07T14-15.md

Step 5: Apex Neural -- Testing Phase (Tester calls Apex Venv MCP)
        Tester creates sandbox via MCP: POST /api/sandboxes { image: "node:20" }
        Tester copies project files into sandbox
        Tester runs: POST /api/sandboxes/{id}/exec/stream { command: "npm test" }
        Streaming output flows back to the Tester agent in real time
        Apex Trace propagates trace_id from Neural --> Venv --> container

Step 6: Apex Dashboard (parallel, optional)
        Engineer watching dashboard sees new sandbox appear
        Sees streaming test output in sandbox detail view
        Health indicator shows venv service is responding

Step 7: Test verdict
        PASS --> Orchestrator declares task complete, writes final summary
        FAIL --> Tester sends failure analysis to Solutioner (max 5 iterations)
        Sandbox is destroyed after test run completes

Step 8: Observability
        Full trace available in Jaeger/Tempo:
        Neural agent call --> Dashboard event --> Venv API --> container exec
        All under one trace_id
```

### What Each System Contributes to the Whole

| System | Contribution to the Workflow |
|---|---|
| **Apex Neural** | Structure. Decompose the task. Validate before implementing. Test before declaring done. |
| **Apex Venv** | Safety. Run the code somewhere isolated. Reproduce the environment exactly. Clean up after. |
| **Apex Dashboard** | Visibility. See what sandboxes are running. Watch test output live. Know if the service is healthy. |
| **Apex Trace** | Continuity. Follow the execution thread across all system boundaries. Diagnose failures precisely. |

---

## Use Cases and Applications

### 1. Feature Development with Full Audit Trail

A team using Apex Neural for feature development automatically produces a complete audit trail for every task: the original plan, the architecture decision, the implementation log, and the test report. These artifacts live in `.github/memory/` and are version-controlled alongside the code. Code reviewers can read the architecture decision to understand why the implementation is structured the way it is, without asking the developer who wrote it.

### 2. Safe Dependency Installation and Migration

Dependency upgrades and migrations often require exploratory shell work — installing packages, running compatibility checks, reading output, adjusting configuration — before any application code changes. Apex Venv provides a natural home for this work: create a sandbox with the project's base image, run the migration steps inside it, verify the result, then copy the updated configuration files out and destroy the sandbox. The host environment is never touched.

### 3. CI-Adjacent Test Execution

For teams that find their CI feedback loop too slow for interactive development, Apex Venv enables a local CI-equivalent: spin up a clean container, run the test suite, get results in seconds, destroy the container. The Tester agent in Apex Neural does this automatically during the Testing phase. Engineers can also trigger it manually from the Dashboard.

### 4. Observability-First Agent Debugging

When an AI agent produces an implementation that fails in unexpected ways, distributed tracing makes the diagnosis concrete. Instead of reading through interleaved logs from four different systems, the engineer opens the trace in Jaeger, finds the failing span, reads its attributes and error message, and knows exactly where the failure occurred and what the execution context looked like at that moment.

### 5. Team-Scale AI Adoption

For engineering teams moving from individual AI tool experimentation to team-scale adoption, the Apex ecosystem provides the governance layer that individual tools lack. Apex Neural enforces a consistent workflow across all developers. Apex Venv ensures that AI-generated code is tested in a controlled environment before it affects shared infrastructure. Apex Trace ensures that when something goes wrong, the failure is diagnosable without tribal knowledge.

---

## Comparative Analysis

### Apex Neural vs. General-Purpose Agent Frameworks

| Dimension | Apex Neural | LangChain / CrewAI / AutoGen |
|---|---|---|
| **IDE integration** | Native VS Code Copilot Chat plugin | External process; split-attention workflow |
| **Phase isolation** | Hard-enforced via tool configuration | Convention-based; requires framework discipline |
| **Tool access control** | Role-based, enforced by VS Code agent infra | Configurable but advisory |
| **Artifact persistence** | Version-controlled markdown in `.github/memory/` | Framework-specific state; often ephemeral |
| **Installation** | VS Code plugin or setup script; zero external infra | Requires Python environment, dependencies, config |
| **Scope control** | Phase gates + iteration limits + tool restriction | Prompt-based; no structural enforcement |

### Apex Venv vs. Docker-Based Dev Environments

| Dimension | Apex Venv | Raw Docker / Dev Containers |
|---|---|---|
| **On-demand creation** | HTTP API call, seconds | Requires manual setup or devcontainer config |
| **AI agent integration** | MCP server; agents call it directly | Requires custom tooling |
| **Streaming output** | Built-in SSE streaming endpoint | Possible but not standard |
| **Resource limits** | Configurable per sandbox at creation time | Requires compose config or manual flags |
| **Management UI** | Apex Dashboard | Docker Desktop (not API-driven) |
| **Rootless operation** | Podman; no daemon, no root | Requires daemon; root by default |

### Apex Ecosystem vs. Single-Tool AI Development

| Workflow Property | Apex Ecosystem | Single AI Coding Tool |
|---|---|---|
| **Reproducibility** | Phase-gated workflow produces same structure every time | Depends on prompt and context state |
| **Auditability** | Full artifact trail in version control | Conversation history; not version-controlled |
| **Execution safety** | Isolated containers; host never touched | Executes in developer's environment |
| **Observability** | Distributed traces across all system hops | Ad-hoc logs; no unified execution thread |
| **Scope control** | Hard tool restrictions; iteration limits | Prompt-based; model decides when to stop |
| **Team consistency** | Shared workflow definition; same phases for everyone | Each developer's workflow is their own |

---

## Security and Compliance

### Container Isolation

Apex Venv uses Podman, which operates without a privileged daemon and supports rootless container execution. This means the sandbox process does not run as root on the host system, significantly reducing the blast radius of any malicious or runaway code executed inside a sandbox. Each sandbox operates in its own network and filesystem namespace, isolated from the host and from other sandboxes.

Resource limits (CPU, memory) are enforced via Linux cgroups through Podman's standard resource constraint flags. A sandbox that attempts to consume unbounded resources hits the configured limit and is constrained, not the host system.

### Trace Data Sensitivity

Apex Trace propagates trace context (trace ID, span ID, flags) through HTTP headers and environment variables. Trace context does not contain application data — it contains only opaque identifiers used to correlate spans. The content of spans (attributes, events, error messages) is controlled by each system's instrumentation code and subject to the standard data governance policies applicable to logs and metrics in each organization's observability stack.

### Memory System and Artifact Retention

All artifacts produced by Apex Neural are stored in `.github/memory/` within the project repository. They are subject to the same access controls, retention policies, and audit mechanisms as the rest of the repository. Teams with compliance requirements around AI-generated code can satisfy them by treating the memory directory as part of the code review and version control workflow — which it already is, structurally.

### No External Dependencies by Default

The core Apex ecosystem operates entirely locally. Apex Neural uses VS Code's built-in Copilot Chat infrastructure (or Ollama for the Python variant). Apex Venv uses Podman, which runs locally. Apex Dashboard is a static application served from a local Vite dev server. Apex Trace exports to a local Jaeger instance by default. Teams with strict data residency requirements can use the ecosystem without sending any data outside their infrastructure.

---

## Roadmap and Future Work

The Apex ecosystem is in active development. The following directions are under consideration based on the current architecture and observed usage patterns.

### Near-Term

- **Apex Neural Python variant production hardening**: The LangGraph/Ollama implementation currently targets local development. Packaging it for deployment in CI environments — with configurable model endpoints, environment variable-based secrets, and structured logging — would make it suitable for server-side automation.

- **Apex Venv image registry**: A curated set of base images tailored for Apex workflows — pre-installing common testing frameworks, build tools, and language runtimes — would reduce sandbox setup time and eliminate the "install dependencies first" step that currently adds latency to the Testing phase.

- **Dashboard sandbox exec interface**: The current dashboard provides visibility into sandbox state. A next step is adding an interactive exec terminal to the sandbox detail view, making the dashboard a full operational console rather than a read-only monitoring interface.

### Medium-Term

- **Apex Neural skill library**: The Skill Creator agent in Apex Neural can distill implementation patterns into reusable skill documents. A shared, curated library of skills — for common frameworks, patterns, and domains — would give new projects a head start on the architecture knowledge that currently has to be built up from scratch.

- **Cross-sandbox networking**: The current sandbox model is single-container. Some testing scenarios (microservice integration tests, database-backed tests) require multiple containers that can communicate with each other. Podman's pod support provides a foundation for this capability.

- **Apex Trace sampling configuration**: The current tracing implementation sends all spans to the backend. For high-frequency operations, configurable sampling rates would reduce observability overhead without sacrificing visibility into unusual execution patterns.

### Longer-Term

- **Apex Neural integration with CI/CD**: The phase-gated workflow is currently developer-facing. Integrating it into a CI pipeline — running the Architecture and Testing phases automatically on pull requests — would extend the structural guarantees of the workflow from the editor into the automated review process.

- **Multi-model support in Neural**: The current implementation targets GitHub Copilot (VS Code) and Ollama (Python). Supporting additional model backends — Anthropic Claude directly, OpenAI, Azure OpenAI — would make the Neural workflow accessible to teams with different model preferences or contractual constraints.

---

## Conclusion

The AI coding tools available today are genuinely impressive. They write code, explain systems, and accelerate individual developer productivity in ways that were not practical even two years ago. But impressive tools are not the same as reliable infrastructure. The gap between "this works on my machine in a demo" and "this is how our team ships software" is real, and closing it requires more than better models.

The Apex ecosystem addresses that gap at the systems level. Apex Neural provides the workflow structure that prevents AI sessions from becoming chaotic. Apex Venv provides the execution isolation that prevents AI-generated code from becoming a liability. Apex Dashboard provides the operational visibility that keeps the infrastructure observable. Apex Trace provides the observability continuity that makes failures diagnosable.

None of these is a revolutionary idea in isolation. Phase-gated workflows, container isolation, management UIs, and distributed tracing are established engineering practices. What the Apex ecosystem does is apply them — carefully, minimally, and composably — to the specific failure modes that emerge when AI coding tools are used in serious software engineering contexts.

The result is a platform that makes AI-assisted development something a team can actually depend on: structured enough to be reproducible, isolated enough to be safe, visible enough to be manageable, and traceable enough to be diagnosable.

---

## Appendices

### Appendix A: Component Dependency Matrix

| Component | Depends On | Optional Integration |
|---|---|---|
| **Apex Neural (VS Code)** | VS Code 1.100+, GitHub Copilot | Apex Venv (via MCP), Apex Trace |
| **Apex Neural (Python)** | Python 3.10+, LangGraph, Ollama | Apex Venv (via HTTP), Apex Trace |
| **Apex Venv** | Go 1.21+, Podman | Apex Trace |
| **Apex Dashboard** | Node.js 18+, Apex Venv API | Apex Trace |
| **Apex Trace (Go)** | Go 1.21+, OpenTelemetry Go SDK | Jaeger / Grafana Tempo |
| **Apex Trace (TS)** | Node.js 18+, OpenTelemetry JS SDK | Jaeger / Grafana Tempo |

### Appendix B: Key Configuration Reference

**Apex Neural iteration limits** (configurable in orchestrator agent definition):
```yaml
max_plan_architect_iterations: 3
max_solution_test_iterations: 5
```

**Apex Venv default resource limits** (configurable at sandbox creation):
```json
{
  "cpuLimit": "1.0",
  "memoryLimit": "512m",
  "timeout": 600
}
```

**Apex Trace OTLP endpoint** (environment variable):
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

**Apex Dashboard API base URL** (environment variable):
```bash
VITE_API_BASE_URL=http://localhost:8080
```

### Appendix C: Glossary

| Term | Definition |
|---|---|
| **Phase gate** | A lifecycle hook that validates required outputs exist before a workflow phase can complete |
| **MCP (Model Context Protocol)** | A protocol for exposing tool interfaces to AI agents, used by both VS Code Copilot and Apex Venv |
| **OTLP** | OpenTelemetry Protocol; the wire format for sending telemetry data to observability backends |
| **Podman** | A daemonless, rootless container runtime compatible with Docker images and commands |
| **Traceparent** | The W3C standard HTTP header for propagating distributed trace context |
| **SSE** | Server-Sent Events; an HTTP-based protocol for streaming real-time data from server to client |
| **LangGraph** | A Python library for building stateful, graph-based multi-agent workflows built on LangChain |
| **Verdict** | A structured output from the Architect or Tester agent indicating the outcome of their review phase |

### Appendix D: Repository Index

| Repository | Language | Purpose | Key Entry Points |
|---|---|---|---|
| `apex-neural` | TypeScript (VS Code), Python | Multi-agent workflow system | `.github/agents/`, `extensions/apex-neural-memory/`, `neural/` |
| `apex-venv` | Go | Sandbox API server and SDK | `main.go`, `internal/sandbox/`, `pkg/venv/`, `cmd/mcp/` |
| `apex-dashboard` | TypeScript, React | Sandbox management UI | `src/App.tsx`, `src/api/client.ts`, `src/hooks/` |
| `apex-trace` | Go, TypeScript | Distributed tracing library | `pkg/apextrace/`, `packages/apex-trace-js/` |
