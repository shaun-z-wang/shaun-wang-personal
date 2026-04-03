---
name: remember
description: Save a memory or piece of knowledge to the persistent memory store at ~/.claude/memory/. Use when the user says /remember or asks to remember, save, or store something for later.
---

# Remember

Save a piece of knowledge to the persistent memory store at `~/.claude/memory/`.

## Memory Store Structure

```
~/.claude/memory/
├── CLAUDE.md                        # Root index — each line imports a project CLAUDE.md
├── <project>/
│   ├── CLAUDE.md                    # Project index — each line imports a memory .md file
│   ├── <topic-a>.md                 # Individual memory file
│   └── <topic-b>.md
```

## Workflow

### Step 1: Identify the project

1. Read `~/.claude/memory/CLAUDE.md` to list known projects.
2. If the user's message makes it clear which project (e.g. conversation context, explicit mention), use that project.
3. If ambiguous, ask: "Which project should I save this under?" and list the available projects. Also offer the option to create a new project.

### Step 2: Decide target file

1. Read the project's `CLAUDE.md` (e.g. `~/.claude/memory/<project>/CLAUDE.md`) to see existing memory files.
2. For each imported memory file, read its contents to understand what topics it covers.
3. Decide:
   - If the memory fits naturally into an **existing file** (same topic/theme), append to that file.
   - If it is a **new topic**, create a new `.md` file with a descriptive kebab-case name.

### Step 3: Write the memory

- If appending to an existing file, add the new content on a new line at the end.
- If creating a new file:
  1. Create `~/.claude/memory/<project>/<topic-name>.md` with the content.
  2. Add `@<topic-name>.md` as a new line in the project's `CLAUDE.md`.
- Keep each memory entry concise — facts and context only, no filler.

### Step 4: Confirm

Tell the user what was saved and where:
- Which project
- Which file (new or existing)
- Brief summary of what was stored
