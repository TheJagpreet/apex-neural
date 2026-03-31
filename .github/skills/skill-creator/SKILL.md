---
name: skill-creator
description: "Creates new skills, modifies existing skills, and validates skill structure. Also creates new agents and adds skills to existing agents. Use when users want to create a skill from scratch, edit an existing skill, improve skill descriptions for better triggering accuracy, create a new agent, or add skills to agents."
---

# Skill Creator Skill

When asked to create, edit, or improve a skill — or create agents and add skills to them — follow this structured process.

## Skill Anatomy

Every skill lives in its own directory under `.github/skills/`:

```
.github/skills/<skill-name>/
├── SKILL.md              # Required — skill definition with YAML frontmatter
└── references/           # Optional — supplementary docs loaded on demand
    └── *.md
```

### SKILL.md Structure

```yaml
---
name: <skill-name>            # kebab-case identifier
description: "<trigger description>"  # When to activate — be specific and slightly "pushy"
---

# <Skill Title>

Instructions for the AI agent when this skill is active...
```

## Creating a New Skill

### Step 1: Capture Intent

Understand what the user wants by clarifying:
1. **Purpose** — What should this skill enable the agent to do?
2. **Trigger** — What user phrases or contexts should activate it?
3. **Output** — What is the expected output format or behavior?
4. **Scope** — Is this a narrow task skill or a broad knowledge skill?

### Step 2: Research Existing Patterns

Before writing, check what already exists:
- Read `.github/skills/` to see existing skill directories
- Check for overlaps or opportunities to extend rather than duplicate
- Review the project's `copilot-instructions.md` for global conventions

### Step 3: Write the SKILL.md

Follow these writing principles:

**Frontmatter:**
- `name` — kebab-case, descriptive, unique across all skills
- `description` — Include both what the skill does AND when to trigger it. Err on the side of being "pushy" about triggering to avoid under-triggering. Example: instead of "Helps with API design", write "Provides API design patterns and best practices. Use whenever the user mentions APIs, endpoints, REST, GraphQL, request handling, or service interfaces — even if they don't explicitly ask for design help."

**Body:**
- Use imperative instructions ("Do X", "Check Y", "Always Z")
- Keep the main SKILL.md under 500 lines
- Structure with clear headings and numbered steps
- Include concrete examples where helpful
- Use progressive disclosure — put detailed references in `references/` subdirectory
- Explain *why* things are important, not just *what* to do

**Examples pattern:**
```markdown
## Example
**Input:** User asks "help me set up logging"
**Output:** Structured logging configuration following project conventions
```

### Step 4: Register the Skill

After creating the SKILL.md:
1. Add the skill path to `plugin.json` under `skills`:
   ```json
   "skills": [
     ".github/skills/existing-skill",
     ".github/skills/<new-skill>"
   ]
   ```
2. The skill auto-loads when its description matches the conversation context

### Step 5: Validate the Skill

Check the skill against these quality criteria:
- [ ] `name` field is kebab-case and unique
- [ ] `description` field clearly states when to trigger
- [ ] Instructions are actionable and use imperative form
- [ ] No overlap with existing skills (or overlap is documented)
- [ ] SKILL.md is under 500 lines
- [ ] References directory used if content exceeds 500 lines

## Modifying an Existing Skill

When editing an existing skill:
1. Read the current SKILL.md to understand its scope
2. Identify what needs to change (content, trigger description, structure)
3. Make targeted edits — avoid rewriting sections that don't need changes
4. Verify the `description` field still accurately reflects the skill's scope
5. Check that the skill is still registered in `plugin.json`

## Improving Skill Descriptions

The `description` field in the YAML frontmatter is the primary trigger mechanism. To improve triggering:

1. **List trigger phrases** — What would a user say that should activate this skill?
2. **Add context cues** — Include synonyms and related concepts
3. **Be inclusive** — "Use when the user mentions X, Y, or Z — even if they don't explicitly ask for help with this topic"
4. **Test mentally** — For each trigger phrase, would the description match?

### Good vs Bad Descriptions

**Bad:** "Helps with testing"
**Good:** "Provides testing strategies, patterns, and best practices. Use when creating test plans, writing tests, or reviewing test coverage."

**Bad:** "Database patterns"
**Good:** "Provides database design patterns including schema design, query optimization, migrations, and connection management. Use whenever the user mentions databases, SQL, queries, tables, migrations, ORMs, or data modeling."

## Agent Anatomy

Every agent is defined by an `.agent.md` file in `.github/agents/`:

```yaml
---
name: <AgentName>                # PascalCase identifier
description: "<what the agent does>"
user-invocable: true             # true for standalone agents
tools: ['<tool-1>', '<tool-2>']  # VS Code Copilot tools the agent can use
---

# <Agent Name> Agent

Instructions for the agent...
```

## Creating a New Agent

### Step 1: Capture Intent

Understand what the user wants:
1. **Role** — What is this agent's core responsibility?
2. **Tools** — What tools does it need? (file reading, editing, search, terminal, memory)
3. **Standalone or subagent?** — Can users invoke it directly, or is it only used by other agents?
4. **Subagents** — Does it need to coordinate other agents?

### Step 2: Research Existing Agents

Before creating:
- List existing agents in `.github/agents/` to check for overlaps
- Review agent conventions by reading existing `.agent.md` files
- Identify which tools are commonly used

### Step 3: Write the Agent

Create the file at `.github/agents/<agent-name>.agent.md`:

**Frontmatter fields:**
- `name` — PascalCase, unique across all agents
- `description` — Concise one-liner explaining the agent's role
- `user-invocable` — Set to `true` for standalone agents
- `tools` — Array of VS Code Copilot tools the agent can use
- `agents` — (Optional) Array of subagent names if this agent coordinates others

**Body guidelines:**
- Start with a clear role statement
- Define when the agent should act
- Provide a step-by-step process
- Specify the expected output format
- List rules and constraints

### Step 4: Validate the Agent

- [ ] Agent file exists at `.github/agents/<name>.agent.md`
- [ ] YAML frontmatter has `name`, `description`, and `tools`
- [ ] `user-invocable` is set appropriately
- [ ] Instructions are clear and follow project conventions
- [ ] No significant overlap with existing agents

## Adding Skills to Agents

Skills auto-load based on conversation context when registered in `plugin.json`. To add a skill to an agent:

1. **Ensure the skill exists** — Check `.github/skills/` and `plugin.json`
2. **Create the skill if needed** — Follow the skill creation process above
3. **Register in `plugin.json`** — Add the skill path to the `skills` array (this makes it available to all agents)
4. **Update agent tools** — If the agent needs additional tools to leverage the skill (e.g., `createFile` for a scaffolding skill), add those to the agent's `tools` array
5. **Update agent instructions** — If needed, add a reference to the skill in the agent's body so it knows when to use the skill's knowledge

## Output Format

When creating a skill, present it to the user for review:

```
## New Skill: <name>

**Trigger:** <description summary>
**Location:** .github/skills/<name>/SKILL.md
**Registration:** Added to plugin.json

### Preview
<show the full SKILL.md content>

### Checklist
- [ ] Name is unique and descriptive
- [ ] Description triggers on the right contexts
- [ ] Instructions are clear and actionable
- [ ] Registered in plugin.json
```

When creating an agent, present it similarly:

```
## New Agent: <name>

**Role:** <description summary>
**Location:** .github/agents/<name>.agent.md
**User-invocable:** yes/no

### Preview
<show the full agent content>

### Checklist
- [ ] Name is unique and descriptive
- [ ] Tools are appropriate for the role
- [ ] Instructions are clear and actionable
```
