---
name: gh-issue
description: Review the contents and discussion in a GitHub issue. Use when the user references an issue number and wants context before fixing it.
allowed-tools: "Bash(gh issue view:*)"
argument-hint: "<issue-number>"
---

# GitHub Issue Review

Review the contents and discussion in GitHub issue #$ARGUMENTS.

## Instructions

1. Fetch the issue with full context:

```bash
gh issue view $ARGUMENTS --json author,body,comments,createdAt,labels,number,state,title,url
```

2. Summarize:
   - What the issue is asking for or reporting
   - Key points from the discussion
   - Any decisions or conclusions reached in the comments

3. Wait for further instructions before proposing or implementing a fix.
