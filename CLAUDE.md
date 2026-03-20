# Project Management Rules

## Task List Formatting (`project_management/task_list.md`)

### Task Lifecycle Statuses
Use these statuses in order: **Not started** → **Scoping** → **Design** → **Development** → **Review** → **Testing** → **Rolling out**

Additional statuses:
- **Not assigned** — task exists but no owner yet
- **HIGH PRIORITY / {status}** — prefix for urgent items
- **Future** — nice-to-have, not currently planned
- **{Date} / {status}** — when a specific target date applies (e.g. "Tomorrow / Rolling out", "April 6 / Rolling out")

### Bullet Format
- My tasks: `- **Status** — Description (TICKET-ID)`
- Others' tasks: `- **Status** — Name — Description (TICKET-ID)`
- Ticket IDs go at the end in parentheses, not inline
- Keep descriptions concise — one line per task

### Organization
- Group tasks by project/workstream with `## N. Project Name` headers
- Within a project, split into subsections by component or ownership (e.g. "My Tasks" vs "Others' Tasks")
- Include a `## Timeline Context` section at the bottom with key dates, velocity estimates, and availability constraints
- Order tasks roughly by priority within each section
