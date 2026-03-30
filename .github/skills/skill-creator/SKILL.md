---
name: skill-creator
description: "Creates new skills, modifies existing skills, and validates skill structure. Use when users want to create a skill from scratch, edit an existing skill, or improve skill descriptions for better triggering accuracy."
---

# Skill Creator Skill

When asked to create, edit, or improve a skill, follow this structured process.

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
