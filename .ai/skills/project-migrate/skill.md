---
name: project-migrate
description: >
  Migrate an existing Obsidian project folder from the old structure (Work Items/, work-item tags)
  to the new psweep-compatible structure (Work/, work tags, new frontmatter fields). One-time migration.
allowed-tools: "Bash(mv:*),Bash(ls:*),Bash(echo:*),Bash(find:*),Read,Edit"
version: "1.0.0"
author: "User"
---

# Project Migrate

Migrate an existing project from the old work item schema to the new psweep-compatible schema.

## Vault Resolution

```bash
echo "$OBSIDIAN_NOTEBOOK_DIR"
```

If empty, stop and tell the user to set `OBSIDIAN_NOTEBOOK_DIR`.

## Arguments

If an argument is provided, use it as the project name. Otherwise, list available projects and ask.

```bash
ls "$OBSIDIAN_NOTEBOOK_DIR/Projects/"
```

## Step 1: Rename Directory

If `Work Items/` exists, rename it to `Work/`:

```bash
mv "$OBSIDIAN_NOTEBOOK_DIR/Projects/<Project>/Work Items" "$OBSIDIAN_NOTEBOOK_DIR/Projects/<Project>/Work"
```

If `Work/` already exists and `Work Items/` does not, skip this step.
If neither exists, stop — nothing to migrate.

## Step 2: Update Work Item Frontmatter

For each `.md` file in the `Work/` directory, apply these edits using the Edit tool:

### Required changes

1. **Tag rename**: `work-item` → `work`
   - `tags: [work-item]` → `tags: [work]`
   - Or in list form:
     ```
     tags:
       - work-item
     ```
     →
     ```
     tags:
       - work
     ```

2. **Type rename**: `type: work-item` → `type: work`

### Add new fields

Add these fields to frontmatter if not already present. Insert them after the `priority:` line:

```yaml
auto-advance: false
gate-before: ""
lane: ""
```

Do NOT overwrite existing values if they are already set.

## Step 3: Verify

After migration, read each migrated file and confirm:
- No remaining `work-item` references in frontmatter
- New fields `auto-advance`, `gate-before`, `lane` are present
- File content (body after frontmatter) is unchanged

## Step 4: Report

List all migrated files and summarize what changed:
- Directory renamed (if applicable)
- Number of files updated
- Fields added to each file
