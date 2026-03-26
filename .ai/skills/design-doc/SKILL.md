---
name: design-doc
description: >
  Generate a design doc from template and save to .hive/design-docs/. Use when the user asks to create, draft, or
  write a design doc, design proposal, or technical proposal.
allowed-tools: "Read,Write,Bash(mkdir:*),Bash(git:*),Bash(hive:*),Bash(date:*)"
version: "2.0.0"
author: "User"
---

# Design Doc Generator

Generate design documents from a team template, saving to `.hive/design-docs/`.

## Template Location

The template lives at a path relative to this skill:

```
.ai/skills/design-doc/templates/design-doc.md
```

Read the template file before generating. If the template is missing, tell the user it needs to be created (it is gitignored and must be set up locally).

## Context Directory

Design docs are stored in `.hive/design-docs/` managed by `hive ctx`.

**IMPORTANT:** `.hive` must be a symlink, not a directory. If it doesn't exist, run
`hive ctx init` to create it — NEVER use `mkdir`.

After confirming `.hive` exists, create the subdirectory if needed:

```bash
mkdir -p .hive/design-docs
```

## Workflow

1. **Read the template** from the path above
2. **Gather information** from the user and codebase:
   - Title of the design
   - Background and problem statement
   - At least two proposals (including "do nothing")
3. **Research the codebase** to inform the proposals — understand existing architecture, relevant code, and constraints
4. **Gather metadata**:
   ```bash
   git config user.name
   git branch --show-current
   git rev-parse --short HEAD
   date +"%Y-%m-%d"
   gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown"
   ```
5. **Fill in the template** replacing placeholders:
   - `{{TITLE}}` — design doc title
   - `{{AUTHOR}}` — from git config
   - `{{DATE}}` — today's date in display format (e.g. `Mar 25, 2026`)
   - `{{PROPOSAL_NAME}}` — name of the first real proposal
6. **Present the draft** to the user for review before saving
7. **Save to `.hive/design-docs/`**

**Filename format:** `.hive/design-docs/YYYY-MM-DD-<slug>.md`

Example: `.hive/design-docs/2026-03-25-auth-service-redesign.md`

Add YAML frontmatter before the template content:

```yaml
---
type: design-doc
date: YYYY-MM-DD
repository: owner/repo
branch: [current branch]
commit: [short commit hash]
status: draft
topic: "[Design doc title]"
---
```

## Audience

Assume readers work on the same codebase or a related codebase. They have general context on the project but not the specifics of what this design addresses. Don't over-explain the system — focus on the specific problem and proposals.

## Writing Style

- **Be brief.** Readers' time is valuable. Use only enough text to make each point clear and useful.
- Use tables, bullet points, and lists to aid readability over prose paragraphs.
- Keep language direct and concise — no filler, no hedging.

## Section Guidelines

- **Background**: Brief context on the relevant part of the system, enough to frame the problem
- **Problem**: Be specific about the pain point and its impact
- **Goals**: Distinguish must-haves from nice-to-haves
- **Proposals**: Each proposal should include:
  - A clear description of the approach
  - Trade-offs (pros/cons) — tables work well here
  - Rough scope/effort
  - Risks or unknowns
- **Proposal 0 (Do nothing)**: Always include — describe the cost of inaction
- Add additional proposal sections as needed (`### Proposal 2: ...`, etc.)

## Slug Generation

Convert the title to a filename-safe slug:
- Lowercase
- Replace spaces and non-alphanumeric characters with hyphens
- Strip leading/trailing hyphens

Example: `Auth Service Redesign` -> `auth-service-redesign`
