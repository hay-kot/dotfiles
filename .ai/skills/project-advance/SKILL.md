---
name: project-advance
description: >
  Advance a project work item through its lifecycle. Reads work items from the Obsidian
  Projects folder, finds the next ready item by priority and phase, then runs the
  appropriate workflow (research, design-doc, plan-write, beads). Use when you want to
  continue project work or let AI pick and execute the next task autonomously.
allowed-tools: "Bash(*),Read,Write,Task(*)"
version: "1.0.0"
author: "User"
---

# Project Advance

Find the next work item to progress and run the appropriate AI workflow for its current phase.

## Vault Resolution

```bash
echo "$OBSIDIAN_NOTEBOOK_DIR"
```

If empty, stop and tell the user to set `OBSIDIAN_NOTEBOOK_DIR`.

## Step 1: Discover Work Items

Scan all work item notes:

```bash
find "$OBSIDIAN_NOTEBOOK_DIR/Projects" -path "*/Work Items/*.md" -type f
```

Read the frontmatter of each file to extract: `phase`, `status`, `priority`, `project`, `repos`.

## Step 2: Select Work Item

**If an argument was provided** (file path or partial title), use that specific work item.

**Otherwise**, filter and rank candidates:
- Exclude `status: done` and `status: review` (those need human attention)
- Rank: `status: active` before `status: backlog`
- Then by priority: `high` → `medium` → `low`
- Then by phase progression: `research` → `design` → `planning` → `ideation`

Show the user the top 3 candidates and confirm which to advance before proceeding.

## Step 3: Run Workflow by Phase

### `ideation`

Help refine the work item into something actionable:
1. Review the current objective and acceptance criteria with the user
2. Ask clarifying questions: what does done look like? what are the constraints?
3. Update the note with refined content
4. Ask if it's ready to move to `research` phase

### `research`

Run deep codebase and context research:
1. Read the work item's objective, repos, and any existing notes
2. Use parallel research agents (codebase-analyzer, codebase-locator) focused on the repos listed
3. Produce a research summary document
4. Save to Obsidian:
   - Folder: `$OBSIDIAN_NOTEBOOK_DIR/Research/`
   - Filename: `YYYY-MM-DD-<slugified-work-item-title>.md`
   - Frontmatter: include `work-item: "[[<Work Item Name>]]"` and `project: "[[<Project Name>]]"`
5. Update the work item's Artifacts section: `- Research: [[<filename>]]`
6. Advance `phase` to `design`

### `design`

Create a design document:
1. Read the work item and its linked research doc (if exists)
2. Invoke the `design-doc` skill with this context
3. The design-doc skill will save to `$OBSIDIAN_NOTEBOOK_DIR/Design Docs/`
4. Update the work item's Artifacts section: `- Design Doc: [[<filename>]]`
5. Advance `phase` to `planning`

### `planning`

Write an implementation plan and create beads issues:
1. Read the work item, research doc, and design doc
2. Invoke the `plan-write` command with this context — it will save the plan to `.hive/plans/`
3. From the plan, create beads issues for each major task:
   ```bash
   bd add --no-daemon "<task title>" --description "<description>"
   ```
4. Update the work item's Artifacts section:
   - `- Plan: .hive/plans/<filename>`
   - `- Beads Board: <bd issue IDs>`
5. Advance `phase` to `in-progress`

### `in-progress`

Check implementation status:
1. Check beads for any linked issues: `bd list --no-daemon`
2. Check for open PRs in the linked repos (if using gh CLI)
3. Summarize: what's done, what's in flight, what's blocked
4. If all beads issues are closed and PRs merged, prompt user to advance to `review`

### `review`

Surface what's ready for human review:
1. List linked PRs and their status
2. Summarize what was built and what acceptance criteria were met
3. Prompt user to verify against acceptance criteria and mark `status: done` when complete

## Step 4: Update Work Item Note

After completing the workflow step, update the note using the Edit tool:
- Append new artifact links to the Artifacts section
- Update the `phase` frontmatter field to the next phase
- Update `status` if appropriate (e.g., backlog → active when starting)

When updating frontmatter, do a targeted Edit of just the changed property line — don't rewrite the whole file.

## Advancement Map

| Current Phase | Next Phase  | Workflow Triggered          |
|---------------|-------------|-----------------------------|
| ideation      | research    | refine with user            |
| research      | design      | research agents             |
| design        | planning    | design-doc skill            |
| planning      | in-progress | plan-write + beads issues   |
| in-progress   | review      | status check                |
| review        | done        | human verification          |
