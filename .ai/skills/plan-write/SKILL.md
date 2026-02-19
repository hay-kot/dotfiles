---
name: plan-write
description: >
  Create detailed implementation plans through interactive research and iteration.
  Use when the user wants to plan a feature, task, or ticket before implementing.
  Researches the codebase, interviews the user, and writes a structured plan to .hive/plans/.
allowed-tools: "Bash(git status:*),Bash(git log:*),Bash(git diff:*),Read,Write,Task(*)"
version: "1.0.0"
author: "User"
---

# Implementation Plan

Create detailed implementation plans through an interactive, iterative process. Be
skeptical, thorough, and work collaboratively to produce high-quality technical
specifications.

## Context Directory

Plans are stored in `.hive/plans/` managed by `hive ctx`.

**IMPORTANT:** `.hive` must be a symlink, not a directory. If it doesn't exist, run
`hive ctx init` to create it — NEVER use `mkdir`.

---

## Step 1: Context Gathering & Initial Analysis

### 1a. Read all mentioned files immediately and fully

Read ticket files, research documents, related plans, and any JSON/data files mentioned.
Use Read tool WITHOUT limit/offset parameters. Read completely — no partial reads.
Do NOT spawn sub-tasks before reading these yourself.

### 1b. Spawn initial research tasks in parallel

Use specialized agents to gather context before asking the user questions:
- **codebase-locator** — find all files related to the ticket/task
- **codebase-analyzer** — understand how the current implementation works
- Check `.hive/` for existing research or context about this feature

### 1c. Read all files identified by research tasks

After research tasks complete, read ALL identified files fully into main context.

### 1d. Present informed understanding and interview the user

Summarize findings:
```
Based on the ticket and my research, I understand we need to [accurate summary].

I've found that:
- [Current implementation detail with file:line reference]
- [Relevant pattern or constraint discovered]
- [Potential complexity or edge case identified]
```

Then use **AskUserQuestion** for any open questions:
- Requirements clarifications that code can't answer
- Business logic decisions
- Design preferences between valid alternatives
- Scope boundaries and out-of-scope items
- Performance or compatibility requirements

Only ask questions you genuinely cannot answer through code investigation.

---

## Step 2: Research & Discovery

### 2a. If the user corrects any misunderstanding

Do NOT just accept the correction. Spawn new research tasks to verify the correct
information. Only proceed once you've verified the facts yourself.

### 2b. Spawn parallel sub-tasks for comprehensive research

Use the right agent for each type:
- **codebase-locator** — find more specific files
- **codebase-analyzer** — understand implementation details
- **codebase-pattern-finder** — find similar features to model after

Wait for **ALL** sub-tasks to complete before proceeding.

### 2c. Present findings and design interview

Summarize research findings:
```
Based on my research:

**Current State:**
- [Key discovery about existing code]
- [Pattern or convention to follow]

**Design Options:**
1. [Option A] - [pros/cons]
2. [Option B] - [pros/cons]
```

Use **AskUserQuestion** for design decisions:
- Which architectural approach to take when multiple are valid
- Trade-offs between complexity and flexibility
- Performance vs. maintainability preferences
- Integration strategy choices
- Testing depth requirements

---

## Step 3: Plan Structure Development

Once aligned on approach, propose the plan structure:

```
Here's my proposed plan structure:

## Overview
[1-2 sentence summary]

## Implementation Phases:
1. [Phase name] - [what it accomplishes]
2. [Phase name] - [what it accomplishes]
3. [Phase name] - [what it accomplishes]
```

Use **AskUserQuestion** to validate:
- Confirm phasing makes sense
- Verify granularity is appropriate
- Check order of implementation
- Validate out-of-scope items

Get explicit approval before writing the detailed plan.

---

## Step 4: Detailed Plan Writing

Write the plan to `.hive/plans/YYYY-MM-DD-ENG-XXXX-description.md`.

**Filename format:**
- With ticket: `2025-01-08-ENG-1478-parent-child-tracking.md`
- Without ticket: `2025-01-08-improve-error-handling.md`

**Template:**

```markdown
# [Feature/Task Name] Implementation Plan

## Overview

[Brief description of what we're implementing and why]

## Current State Analysis

[What exists now, what's missing, key constraints discovered]

## Desired End State

[Specification of the desired end state and how to verify it]

### Key Discoveries:

- [Important finding with file:line reference]
- [Pattern to follow]
- [Constraint to work within]

## What We're NOT Doing

[Explicitly list out-of-scope items to prevent scope creep]

## Implementation Approach

[High-level strategy and reasoning]

## Phase 1: [Descriptive Name]

### Overview

[What this phase accomplishes]

### Changes Required:

#### 1. [Component/File Group]

**File**: `path/to/file.ext`
**Changes**: [Summary of changes]

```[language]
// Specific code to add/modify
```

### Success Criteria:

#### Automated Verification:

- [ ] Migration applies cleanly: `make migrate`
- [ ] Unit tests pass: `make test-component`
- [ ] Type checking passes: `npm run typecheck`
- [ ] Linting passes: `make lint`

#### Manual Verification:

- [ ] Feature works as expected when tested via UI
- [ ] No regressions in related features

**Implementation Note**: After completing this phase and all automated verification
passes, pause here for manual confirmation from the human before proceeding.

---

## Phase 2: [Descriptive Name]

[Similar structure...]

---

## Testing Strategy

### Unit Tests:
- [What to test]
- [Key edge cases]

### Integration Tests:
- [End-to-end scenarios]

### Manual Testing Steps:
1. [Specific step to verify feature]
2. [Edge case to test manually]

## Performance Considerations

[Any performance implications or optimizations needed]

## Migration Notes

[If applicable, how to handle existing data/systems]

## References

- Original ticket: `[ticket reference]`
- Related research: `.hive/research/[relevant].md`
- Similar implementation: `[file:line]`
```

---

## Step 5: Review and Iterate

Present the plan location and ask the user to review:

```
I've created the implementation plan at:
`.hive/plans/YYYY-MM-DD-ENG-XXXX-description.md`

Please review it and let me know:
- Are the phases properly scoped?
- Are the success criteria specific enough?
- Any technical details that need adjustment?
- Missing edge cases or considerations?
```

Iterate based on feedback until the user is satisfied.

---

## Guidelines

### Be Skeptical
- Question vague requirements
- Identify potential issues early
- Ask "why" and "what about"
- Don't assume — verify with code

### Be Interactive
- Don't write the full plan in one shot
- Get buy-in at each major step
- Allow course corrections

### Be Thorough
- Read all context files completely before planning
- Research actual code patterns using parallel sub-tasks
- Include specific file paths and line numbers
- Write measurable success criteria with clear automated vs. manual distinction
- Use `make` for automated steps whenever possible (e.g., `make -C humanlayer-wui check`)

### No Open Questions in Final Plan
- If you encounter open questions, STOP and use AskUserQuestion immediately
- Do NOT write the plan with unresolved questions
- Every decision must be made before finalizing

## Success Criteria Format

Always separate into two categories:

**Automated Verification** (runnable by execution agents):
- Commands: `make test`, `npm run lint`, etc.
- Specific files that should exist
- Code compilation/type checking

**Manual Verification** (requires human testing):
- UI/UX functionality
- Performance under real conditions
- Edge cases that are hard to automate
- User acceptance criteria

## Common Patterns

### Database Changes
Schema/migration → store methods → business logic → API → clients

### New Features
Research existing patterns → data model → backend logic → API endpoints → UI last

### Refactoring
Document current behavior → incremental changes → backwards compatibility → migration strategy
