---
name: daily-prep
description: >
  Morning daily prep: creates or updates today's Obsidian daily note with a GitHub
  status brief (open PRs, review requests, recent activity) and a summary of
  yesterday's completed work. Use when the user says "morning prep", "daily prep",
  "start my day", or wants a GitHub status update written to their daily note.
allowed-tools: "Bash(gh:*),Bash(date:*),Bash(echo:*),Bash(mkdir:*),Read,Write,Edit"
---

# Daily Prep

Build a morning brief from GitHub and yesterday's note, then write it into today's
daily note. Create the note if it doesn't exist.

## Vault Resolution

```bash
echo "$OBSIDIAN_NOTEBOOK_DIR"
```

Stop if empty and tell the user to set `OBSIDIAN_NOTEBOOK_DIR`.

## Compute Filenames

```bash
# Today
TODAY=$(date +"%Y-%m-%d")
TODAY_DAY=$(date +"%a")   # e.g. Tue
TODAY_FILE="$OBSIDIAN_NOTEBOOK_DIR/Daily/${TODAY} - ${TODAY_DAY}.md"

# Yesterday (skip weekends back to Friday if today is Monday)
YESTERDAY=$(date -v-1d +"%Y-%m-%d")
YESTERDAY_DAY=$(date -v-1d +"%a")
YESTERDAY_FILE="$OBSIDIAN_NOTEBOOK_DIR/Daily/${YESTERDAY} - ${YESTERDAY_DAY}.md"
```

## Create Today's Note (if missing)

If `TODAY_FILE` does not exist, create it using the structure below. Determine the
current weekday and include the appropriate recurring tasks.

**Recurring task rules:**
- Every day: `Review yesterday's On-Call Rotation`, `Zero Inbox for Gmail`
- Monday only: `Plan weekly goals`, `Update 1:1 Doc`
- Wednesday only: `PromQL, LogQL and TraceQL Training`
- Friday only: `Post thread for gathering updates`, `Post final update slack thread`, `Follow up on brag document`

Carry over incomplete tasks from yesterday's note: read `YESTERDAY_FILE`, extract all
lines matching `- [ ]` (top-level and indented), and include them under
`### Carryover`.

```markdown
---
tags:
  - daily
---
## Recurring Tasks

- [ ] Review yesterday's On-Call Rotation
- [ ] Zero Inbox for Gmail
<!-- weekday-specific tasks here -->

## To Do's

### Carryover

<!-- incomplete tasks from yesterday or: _No undone tasks found._ -->

## Notes

```

## Gather GitHub Data

Run these in sequence. GitHub username is `hay-kot`.

```bash
# Compute yesterday's date for filtering
YESTERDAY_DATE=$(date -v-1d +"%Y-%m-%d")

# 1. My open PRs in log-template-service
gh pr list \
  --repo grafana/log-template-service \
  --author "@me" \
  --state open \
  --json number,title,url,reviewDecision,isDraft,createdAt \
  --limit 20

# 2. PRs requesting my review in log-template-service
gh pr list \
  --repo grafana/log-template-service \
  --review-requested "@me" \
  --state open \
  --json number,title,url,author,createdAt \
  --limit 10

# 3. My open PRs across grafana org (excluding deployment_tools)
gh search prs \
  --author "@me" \
  --org grafana \
  --state open \
  --json number,title,url,repository \
  --limit 20

# 4. PRs I merged yesterday in log-template-service
gh pr list \
  --repo grafana/log-template-service \
  --author "@me" \
  --state merged \
  --json number,title,url,mergedAt \
  --limit 10

# 5. PRs I reviewed yesterday across grafana org
gh search prs \
  --reviewed-by "@me" \
  --org grafana \
  --updated $(date -v-1d +"%Y-%m-%d") \
  --json number,title,url,repository,updatedAt \
  --limit 20

# 6. Commits I pushed yesterday to log-template-service
gh search commits \
  --author "@me" \
  --repo grafana/log-template-service \
  --committer-date ">=${YESTERDAY_DATE}" \
  --json sha,message,committedDate \
  --limit 20
```

Filter out `deployment_tools` from results #3 and #5 when formatting.
Filter results #4, #5, #6 to only include activity with dates matching `YESTERDAY_DATE`.

## Read Yesterday's Note (Supplemental)

Read `YESTERDAY_FILE` if it exists. Extract only:
- Content under `## Notes` — freeform context that may not appear in GitHub

## Synthesize the Morning Brief

**No emojis anywhere in the output.**

**Every PR reference must be a markdown link.** Never write a bare `#NNN` — always
`[#NNN](url)`. This applies everywhere: tables, callout bullets, the Yesterday section,
and any prose.

The brief has two destinations:

1. `## Morning Brief` — prepended before `## Recurring Tasks` in today's note.
   Contains the PR tables and focus suggestion.
2. `### Yesterday` — appended as a subsection inside `## Notes` in today's note.
   Contains the narrative of what happened yesterday.

Check for `## Morning Brief` before writing. If already present, skip and tell the
user. Otherwise write both sections.

---

### Morning Brief format

```markdown
## Morning Brief
_Generated: YYYY-MM-DD_

### Open PRs (log-template-service)

| PR | Title | Status |
|----|-------|--------|
| [#NNN](url) | truncated title | Draft |

<!-- One row per open PR. PR column is just the linked number: [#NNN](url)
     Title column: truncate to 72 characters max, append … if truncated.
     Status values (derived from isDraft and reviewDecision):
       isDraft=true                        -> Draft
       reviewDecision=null                 -> Needs Review
       reviewDecision=REVIEW_REQUIRED      -> In Review
       reviewDecision=CHANGES_REQUESTED    -> Changes Requested
       reviewDecision=APPROVED             -> Approved
     Do NOT add a trailing empty row. The table ends after the last PR row. -->

### Review Queue

| PR | Title | Author |
|----|-------|--------|
| [#NNN](url) | truncated title | @author |

<!-- Omit this section entirely if there are no review requests.
     Title column: truncate to 72 characters max, append … if truncated.
     Do NOT add a trailing empty row. -->

### Other Grafana PRs

| PR | Repo | Title |
|----|------|-------|
| [#NNN](url) | repo-name | truncated title |

<!-- Only PRs outside log-template-service. Exclude deployment_tools.
     Omit this section entirely if there are none.
     Title column: truncate to 72 characters max, append … if truncated.
     Do NOT add a trailing empty row. -->

> [!focus] Focus
> - item one
> - item two

<!-- 1-3 actionable bullets inside an Obsidian [!focus] callout.
     Base on: approved PRs ready to merge, PRs with no review yet,
     high-priority carryover tasks, anything blocking progress.
     ALWAYS use markdown links for any PR reference: [#NNN](url)
     Never write a bare #NNN without a link. -->
```

---

### Yesterday format (written into ## Notes)

```markdown
### Yesterday
_YYYY-MM-DD_

<!-- 3-6 bullet points grounded entirely in GitHub data:
     - PRs merged: [#NNN](url) — title
     - PRs reviewed: [#NNN](url) — title (repo if outside log-template-service)
     - Commits pushed: brief thematic summary (not individual hashes)
     - Any notable freeform context from yesterday's ## Notes section
     If nothing happened in GitHub, say so honestly. -->
```

Append this after any existing content in `## Notes`. Do not replace existing notes.

---

## Writing

Use `Write` when creating a new file or rewriting the full file to prepend
`## Morning Brief`. Use `Edit` when appending `### Yesterday` into an existing
`## Notes` section.

**Placement:**
- `## Morning Brief` — before `## Recurring Tasks`
- `### Yesterday` — appended inside `## Notes`

## After Writing

Tell the user:
- File path written
- Count of open PRs and review requests
- The Focus bullets (so they're visible without opening the file)
