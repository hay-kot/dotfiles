---
---

Generate a full Obsidian “How-To” document based on the engineering workflow template. Use the conversation with the user for what to generate. If not enough context is provided ask the engineer for more details.

1. **Prompt for Workflow Details**
   - Ask the user for:
     - Workflow title
     - Description / purpose
     - Key commands, steps, and notes
     - Slack context or external references

_only if required_

2. **Generate Markdown File**
   - Structure it using the How-To template:

```markdown
---
tags:
  - how-to
  - devops
  - engineering
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# How To [Workflow Title]

## 🧭 Overview

Goal: Describe what this guide helps achieve.

## 🧩 Prerequisites

- [ ] Access requirements
- [ ] Installed tools
- [ ] Links to internal/external docs

## ⚙️ Steps

### 1. Prepare

### 2. Execute

### 3. Verify

## 🧠 Notes & Gotchas

Add common issues, Slack conversations, or troubleshooting tips.

## 💬 Slack Threads / Team Conversations

Paste or summarize relevant context.

## 🌐 External Resources

List useful references or documentation links.

## 🔗 Related How-To’s

List related internal guides.

## 🏁 Summary

State what success looks like and next steps.
```
