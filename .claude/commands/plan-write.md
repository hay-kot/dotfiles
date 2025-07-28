---
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git diff:*)
description: write a plan for whatever task the AI is going to work on.
---

## Overview

Task: #$ARGUMENTS

Analyze the repository context and create a detailed plan for the specified task. Save this plan to `PLAN.local.md` in the repository root.

## Required Plan Structure

1. **Front Matter**

   - Include metadata for tracking purposes (GitHub issues, PRs, etc.)
   - Add a status tracker (e.g., "Status: Not Started | In Progress | Completed")
   - Include estimated time to completion

2. **Task Analysis**

   - Summarize your understanding of the task requirements
   - List any assumptions you're making
   - Identify potential challenges or dependencies

3. **Execution Plan**

   - Break down the task into specific, sequential steps
   - For each step, include:
     - Clear success criteria
     - Estimated time for completion
     - Any dependencies on previous steps
   - Tag steps as [RESEARCH], [IMPLEMENTATION], [TESTING], or [REVIEW]

4. **Resource Index**

   - List key files relevant to the task with brief descriptions
   - Include paths to documentation or reference materials
   - Note any external resources that may be needed

5. **Validation Strategy**
   - Outline how you'll verify the task is complete and correct
   - Include test cases or validation criteria

## Instructions for Plan Development

1. First explore the repository structure to understand the codebase organization
2. Examine relevant files to understand the task context
3. Review recent commits to understand ongoing development
4. Consider how your changes will integrate with existing code
5. Be specific about file paths and code locations
6. Prioritize incremental steps that can be validated independently
7. Ensure that tests are written at each step of the process
8. Do not put time constraints or estimates in your work plan
