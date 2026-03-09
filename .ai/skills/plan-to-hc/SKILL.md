---
name: plan-to-hc
description: >
  Create a hive hc epic from the current plan file, inserting the ENTIRE PLAN TEXT
  into the epic and creating subtasks to track all work items.
allowed-tools: "Read,Bash(hive hc:*),Bash(echo:*),Bash(bpcopy:*),Bash(cat:*)"
version: "1.0.0"
author: "User"
license: "MIT"
---

# Plan to Hive HC

Converts a Claude Code plan file into a hive hc epic with subtasks.

## Instructions

When this command is invoked:

1. **Locate the most recent (active) plan file**: Read the current plan file from the plans directory

2. **Extract the plan content**: Get the ENTIRE TEXT of the plan

3. **Create a hive hc epic with subtasks**: Use the **bulk JSON stdin format** to create the epic and all subtasks in a single command. This avoids shell escaping issues with `--desc`.

   Build a JSON object and pipe it to `hive hc create`:
   ```bash
   cat <<'JSONEOF' | hive hc create
   {
     "title": "Epic title here",
     "type": "epic",
     "desc": "Full plan text here (escaped for JSON)",
     "children": [
       {"title": "Step 1: ...", "type": "task"},
       {"title": "Step 2: ...", "type": "task", "desc": "details"}
     ]
   }
   JSONEOF
   ```

   - The epic description must contain the COMPLETE plan text
   - Each major work item becomes a child task
   - Use clear, actionable titles for subtasks

   **CRITICAL**: Do NOT use `--desc` flag for long text. Always use the JSON stdin format to avoid the description being added as a comment instead.

4. **Copy the epic id**: Put the epic id on the clipboard
   - echo <epic id> | bpcopy

## Notes

- **ALWAYS use the JSON stdin format** — never pass plan text via `--desc` flag (it gets added as a comment instead of description)
- The epic description must contain the COMPLETE plan text
- Subtasks should capture all trackable work items from the plan
- Escape the plan text properly for JSON (newlines as `\n`, quotes as `\"`)
- Preserve any dependencies or sequential ordering from the plan
