---
name: plannotator-last
description: Open the previous assistant response in Plannotator and act on returned annotations. Use only when invoked directly.
disable-model-invocation: true
---

# Plannotator last response

Do not send a status message before opening Plannotator. It could become the response selected for review.

Run:

```bash
if message="$(python3 <skill-directory>/scripts/last-message.py --claude-session-id '${CLAUDE_SESSION_ID}')"; then
  printf '%s' "$message" | plannotator annotate-last --stdin
else
  plannotator last
fi
```

Replace `<skill-directory>` with this skill's directory. The helper selects the response before the current skill invocation from Pi, Claude Code, or Codex session logs. Other agents fall back to Plannotator's session detection.

Wait for the annotation session to finish. Apply returned annotation feedback to the follow-up response. If the response was approved or the session closed without feedback, acknowledge that briefly and stop.
