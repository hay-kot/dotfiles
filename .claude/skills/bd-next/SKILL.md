---
name: bd-next
description: Work on beads tasks to completion, prioritizing current branch context
argument-hint: [optional task-id]
---

# Next - Work to Completion

Find and complete tasks, working continuously until all open work is done or a specific task is completed.

## Workflow

1. **Check current branch**: `git branch --show-current`
2. **Find related work** (in order of priority):
   - If task-id provided: Work ONLY on that specific task to completion
   - In-progress issues: `bd list --status=in-progress`
   - Issues matching branch name: `bd search <branch-name>`
   - Ready tasks with no blockers: `bd ready`
3. **Load the task**: `bd show <issue-id>` for full context
4. **Complete the work**:
   - Mark as in-progress if needed
   - Follow Research → Plan → Implement → Validate workflow
   - Run tests, linters, formatters
   - Mark task as closed when fully complete: `bd close <issue-id>`
5. **Continue working**: After completing a task, automatically find and start the next task
6. **Stop when**:
   - If specific task-id was provided: Stop after completing that task
   - If no task-id: Continue until no more tasks are ready or in-progress

## Completion Criteria

A task is complete when:
- All implementation is done
- Tests pass
- Code is formatted and linted
- Task is marked closed in beads

## Output

Report which task you're working on, complete it fully, then move to the next task. Keep working until done.
