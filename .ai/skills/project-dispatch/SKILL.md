---
name: project-dispatch
description: >
  Dispatch ready work items to parallel hive agents. Scans Obsidian Projects for work
  items at `research`, `design`, or `planning` phase, lets the user select which to
  dispatch, then runs `hive batch` to spawn one agent per item. Use when you have a
  queue of work items ready to run in parallel.
allowed-tools: "Bash(*),Read,Write"
version: "1.2.0"
author: "User"
---

# Project Dispatch

Scan the Obsidian project board for work items ready to dispatch and spawn parallel
hive agent sessions for them.

## Vault Resolution

```bash
echo "$OBSIDIAN_NOTEBOOK_DIR"
```

If empty, stop and tell the user to set `OBSIDIAN_NOTEBOOK_DIR`.

## Step 1: Find All Work Items

Scan all work item notes:

```bash
find "$OBSIDIAN_NOTEBOOK_DIR/Projects" -path "*/Work/*.md" -type f
```

Read each file fully to extract frontmatter and Artifacts section.

For each item, extract:
- Work item title (filename without `.md`)
- Project name (from `project` frontmatter, strip `[[` and `]]`)
- Phase
- Priority
- Repos (from `repos` frontmatter)
- `dispatched-at` and `dispatched-session` (from frontmatter, if present)
- Objective (from `## Objective` section body)
- Acceptance Criteria (from `## Acceptance Criteria` section body)
- Plan file path (from `- Plan:` in Artifacts, if present)

### Classify items

| Phase | Classification |
|---|---|
| `research`, `design`, `planning` | **Dispatchable** — ready for an agent |
| `building` | **In progress** — already dispatched, show but do not offer for selection |
| `review`, `done`, `blocked`, `backlog` | **Excluded** — skip entirely |

## Step 2: Show Dispatch Board

Present dispatchable items grouped by phase, then project, sorted by priority.
Show in-progress (`building`) items in a separate section so the user can see what
is already running.

```
In-progress work items (already dispatched — phase: building):

  ● Fix HTTP Status Codes        [Adaptive Logs]  dispatched 2026-03-10

Dispatchable work items:

── PLANNING ───────────────────────────────────────────────
[Adaptive Logs API Alignment]
  1. Validation Consolidation     (high)   ✗ no plan yet
  2. Consolidate Response Types   (low)    ✓ plan exists

── DESIGN ─────────────────────────────────────────────────
[Adaptive Logs Observability]
  3. Logging Infrastructure       (high)

── RESEARCH ───────────────────────────────────────────────
  (none)
```

Ask the user which to dispatch — they can say "all", "1 2 3", a phase name, or a
project name.

## Step 3: Build Agent Prompts

Construct the prompt for each selected item based on its phase.

### Research phase prompt

```
Work Item: <title>
Project: <project>
Repos: <repos>

Objective:
<objective>

Run deep codebase research for this work item using the `research` skill. Conduct
parallel research across the listed repos focused on the objective above.

Save the research document to:
  $OBSIDIAN_NOTEBOOK_DIR/Projects/<project>/Research/YYYY-MM-DD-<slug>.md

Include frontmatter:
  work-item: "[[<title>]]"
  project: "[[<project>]]"

After saving, update the work item file at:
  <work-item-file-path>
Add the research doc filename to the Artifacts section: `- Research: [[<filename>]]`
Then update `phase: design` in the frontmatter.
```

### Design phase prompt

```
Work Item: <title>
Project: <project>
Repos: <repos>

Objective:
<objective>

Acceptance Criteria:
<acceptance-criteria>

Create a design document for this work item using the `design-doc` skill. Read any
linked research doc from the work item's Artifacts section first if one exists.

Save the design doc to:
  $OBSIDIAN_NOTEBOOK_DIR/Projects/<project>/Design Docs/YYYY-MM-DD-<slug>.md

After saving, update the work item file at:
  <work-item-file-path>
Add the design doc to Artifacts: `- Design Doc: [[<filename>]]`
Then update `phase: planning` in the frontmatter.
```

### Planning phase — plan exists

```
Work Item: <title>
Project: <project>
Repos: <repos>

Objective:
<objective>

Acceptance Criteria:
<acceptance-criteria>

An implementation plan exists at: <plan-path>

Read the plan fully. Then use the `plan-to-hc` skill to load the plan into hive hc
tasks for this session. Execute each task in order. When all tasks are complete and
a PR is open, you are done.
```

### Planning phase — no plan yet

```
Work Item: <title>
Project: <project>
Repos: <repos>

Objective:
<objective>

Acceptance Criteria:
<acceptance-criteria>

No implementation plan exists yet. Use the `plan-write` skill to create one. Save the
plan to `.hive/plans/`. Do not implement any code changes — the plan will be reviewed
before execution begins.

After saving the plan, update the work item file at:
  <work-item-file-path>
Add the plan path to Artifacts: `- Plan: .hive/plans/<filename>`
```

## Step 4: Build Batch JSON

Combine selected items into the batch input:

```json
{
  "sessions": [
    { "name": "<slugified-title>", "prompt": "<prompt>" },
    { "name": "<slugified-title>", "prompt": "<prompt>" }
  ]
}
```

Show the session names and a brief summary (title, phase, plan status) for review.
Do NOT show the full prompts — keep the confirmation concise. Ask for confirmation
before dispatching.

## Step 5: Dispatch

```bash
echo '<json>' | hive batch
```

## Step 6: Mark Dispatched Work Items

This is the critical step that prevents double-dispatch. For each dispatched item,
apply **all three edits** using the Edit tool (not a full file rewrite):

1. Set `phase: building`
2. Set `dispatched-at: <RFC 3339 timestamp>` (e.g. `2026-03-11T09:00:00-07:00`)
3. Set `dispatched-session: <session-id>` from the `hive batch` output

If the field already exists in frontmatter, replace the existing line.
If the field does not exist, add it after the `phase:` line.

Example targeted edits:
```
phase: research  →  phase: building
dispatched-at: ""  →  dispatched-at: "2026-03-11T09:00:00-07:00"
dispatched-session: ""  →  dispatched-session: "abc123"
```

If `hive batch` output does not include a session ID for a particular item, still
set `phase: building` and `dispatched-at` — omit `dispatched-session`.

**These edits are what prevents the item from re-appearing in future dispatch runs.**
Do not skip this step even if partial failures occurred.

## After Dispatch

Report:
- How many sessions spawned, grouped by phase
- Session names and the work items they correspond to
- Remind user: `hive ls` to check status
