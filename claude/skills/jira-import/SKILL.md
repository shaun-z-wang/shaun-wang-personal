---
name: jira-import
description: Import tasks from a document into Jira
disable-model-invocation: true
---

# Jira Task Import

You are helping me import tasks from a document into Jira. Ask me the following questions one by one to gather requirements. Show the default value in parentheses—I can just press enter or say "default" to accept it.

**Questions to ask:**

1. **Source document URL?**
   (no default - required)

2. **Project key?**
   (default: FUL)

3. **Epic key to link tasks to?**
   (no default - required)

4. **Issue type?**
   (default: Task)

5. **Component?**
   (default: Enterprise Platform)

6. **Assignee?**
   (default: Unassigned)

7. **Summary format?**
   (default: Remove leading task ID prefix, keep the rest)

8. **Description format?**
   (default: Just link the doc and say "Refer to doc for details")

9. **Story Points calculation?**
   (default: For day estimates like "2-3 days", use formula: (min + max) / 2 * 2. Leave empty for deferred/unestimated tasks)

**After gathering answers:**
- Show me example of one ticket before actually creating it in Jira
- Create one test ticket for verification before proceeding with the rest.
- Show me a summary of all the tickets you are going to create before creating all of them in Jira

**After creating each ticket**
If the assignee is default (unassigned), after creating the ticket, need to go view the ticket to make sure it is actually unassigned. Sometimes jira automatically assign the tickets to someone else
