---
name: plan-to-beads
description: >
  Create a beads epic from the current plan file, inserting the ENTIRE PLAN TEXT 
  into the epic and creating subtasks to track all work items.
allowed-tools: "Read,Bash(bd:*),Bash(echo:*),Bash(bpcopy:*)"
version: "1.0.0"
author: "User"
license: "MIT"
---

# Plan to Beads

Converts a Claude Code plan file into a beads epic with subtasks.

## Instructions

When this command is invoked:

1. **Ensure stealth mode is initialized**: Check if beads is already initialized for the project. If not, run:

   ```bash
   bd init --stealth
   ```

2. **Locate the most recent (active) plan file**: Read the current plan file from the plans directory

3. **Extract the plan content**: Get the ENTIRE TEXT of the plan

4. **Create a beads epic**: Use `bd create -t epic` to create an epic with:
   - A descriptive title based on the plan's goal
   - The complete plan text in the description

5. **Create subtasks**: Analyze the plan and create subtasks for each major work item or implementation step using `bd create` with:
   - Clear, actionable titles
   - Parent reference to the epic
   - Appropriate status and labels

6. **Link dependencies**: If the plan has sequential steps, link the subtasks with appropriate dependencies

7. **Sync to git**: Run `bd sync` to persist the changes

8. **Copy the plan id**: Put the epic id on the clipboard
   - echo <plan id> | bpcopy

## Expected Workflow

```bash
# User runs:
/plan-to-beads

# Agent should:
# 1. Read the plan file
# 2. Create epic with full plan text
# 3. Create subtasks for each work item
# 4. Link dependencies as needed
# 5. Sync to git
```

## Notes

- The epic description should contain the COMPLETE plan text for reference
- Subtasks should capture all trackable work items from the plan
- Use clear, descriptive titles for easy identification
- Preserve any dependencies or sequential ordering from the plan
