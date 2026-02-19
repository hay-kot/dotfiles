---
name: obsidian
description: >
  Save documents to Obsidian notebook. Use when the user asks to save, write, or put
  a document (test plan, design doc, etc.) into their Obsidian notebook.
allowed-tools: "Bash(mkdir:*),Write,Read"
version: "1.0.0"
author: "User"
---

# Obsidian Notebook

Save structured documents into the user's Obsidian vault.

## Vault Location

The vault root is stored in `$OBSIDIAN_NOTEBOOK_DIR`. Always resolve this before writing:

```bash
echo "$OBSIDIAN_NOTEBOOK_DIR"
```

If the variable is empty, stop and tell the user to set `OBSIDIAN_NOTEBOOK_DIR`.

## Document Types

| Type        | Folder         | Filename Pattern                     |
| ----------- | -------------- | ------------------------------------ |
| test-plan   | Test Plans     | `YYYY-MM-DD-<slugified-title>.md`    |
| design-doc  | Design Docs    | `YYYY-MM-DD-<slugified-title>.md`    |

If the user requests a type not in this table, ask which folder to use and suggest they add it to this table.

## Writing a Document

1. **Resolve the vault path** from `$OBSIDIAN_NOTEBOOK_DIR`
2. **Determine the document type** from user intent
3. **Create the target folder** if it doesn't exist:
   ```bash
   mkdir -p "$OBSIDIAN_NOTEBOOK_DIR/<Folder>"
   ```
4. **Generate the filename**: `YYYY-MM-DD-<slugified-title>.md` using today's date
5. **Write the file** using the Write tool with the frontmatter and content

## Frontmatter

Every document must start with YAML frontmatter:

```yaml
---
title: "<Document Title>"
repository: "<owner>/<repo>"
created: YYYY-MM-DD
status: draft
---
```

Field details:
- **title**: Descriptive title for the document
- **repository**: Infer from the current git remote (`git remote get-url origin`, extract `owner/repo`). If not in a git repo, ask the user.
- **created**: Today's date
- **status**: Always `draft` unless the user specifies otherwise

## Slug Generation

Convert the title to a filename-safe slug:
- Lowercase
- Replace spaces and non-alphanumeric characters with hyphens
- Strip leading/trailing hyphens

Example: `Auth Service Redesign` -> `auth-service-redesign`

## Example

User says: "Save this test plan for the auth refactor to my obsidian notebook"

Result: `$OBSIDIAN_NOTEBOOK_DIR/Test Plans/2026-02-18-auth-refactor-test-plan.md`

```markdown
---
title: "Auth Refactor Test Plan"
repository: "hay-kot/hive"
created: 2026-02-18
status: draft
---

<content from the conversation>
```
