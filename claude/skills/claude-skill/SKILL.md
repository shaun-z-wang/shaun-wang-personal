---
name: claude-skill
description: Create a new Claude skill. Use when the user asks to create, write, or set up a new skill, or says /claude-skill.
---

# Create a Claude Skill

Guide the user through creating a new Claude skill at `~/.claude/skills/`.

## Skill anatomy

Every skill lives in its own directory and has a `SKILL.md` file:

```
~/.claude/skills/
└── <skill-name>/
    └── SKILL.md
```

### SKILL.md format

```markdown
---
name: <skill-name>            # kebab-case, max 64 chars
description: <what and when>  # third-person, max 1024 chars
---

# <Skill Title>

<instructions for the agent — what to do when this skill is invoked>
```

### Frontmatter fields

| Field | Rules |
|-------|-------|
| `name` | Lowercase, hyphens only, max 64 chars. Must match the directory name. |
| `description` | Third-person. Describe WHAT the skill does and WHEN to use it. Include trigger words (e.g. "Use when the user says /foo or asks to ..."). |

Optional: `disable-model-invocation: true` — prevents the skill from being auto-invoked by the model; only triggers on explicit user command.

## Workflow

### Step 1: Gather requirements

Ask the user:
1. **What should the skill do?** — purpose, scope, desired behavior.
2. **What should it be called?** — suggest a kebab-case name based on the answer above.
3. **When should it trigger?** — slash command, keyword, or automatic detection.

If the user has already described the skill in conversation context, infer answers instead of re-asking.

### Step 2: Draft the SKILL.md

Write the skill following these principles:

- **Concise** — the agent is smart; only include knowledge it wouldn't already have.
- **Actionable** — write as clear steps the agent should follow when the skill triggers.
- **Structured** — use headings, numbered steps, and bullet points.
- **No filler** — skip boilerplate explanations of what a skill is or how markdown works.

### Step 3: Write to disk

1. Create directory: `~/.claude/skills/<skill-name>/`
2. Write `SKILL.md` inside it.

### Step 4: Confirm

Tell the user:
- Skill name and path
- Brief summary of what it does
- How to invoke it (e.g. "say `/skill-name` or ask to ...")

## Reference: Existing skill examples

For style reference, look at other skills in `~/.claude/skills/` (e.g. `jira-import`, `remember`).
