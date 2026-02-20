#!/usr/bin/env bash
# review-ralph.sh — iterative self-critiquing code review loop
# Usage: review-ralph.sh [iterations=3]
#
# Each iteration spawns a fresh claude process with:
#   - a rotating skill focus (correctness → design → tests → comments)
#   - the full diff
#   - the previous review (if any), with instructions to challenge it
#
# Output is saved to .hive/review-ralph-<timestamp>.md and overwritten each pass.

set -euo pipefail

ITERATIONS=${1:-3}
if [[ -z "$ITERATIONS" || ! "$ITERATIONS" =~ ^[0-9]+$ ]]; then
    ITERATIONS=3
fi
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REVIEW_FILE=".hive/review-ralph-${TIMESTAMP}.md"

FORMAT_SKILL=".ai/skills/review-format/SKILL.md"

SKILLS=(
    ".ai/skills/review-correctness/SKILL.md"
    ".ai/skills/review-design/SKILL.md"
    ".ai/skills/review-tests/SKILL.md"
    ".ai/skills/review-comments/SKILL.md"
)

SKILL_NAMES=(
    "Correctness (bugs, error handling, dead code)"
    "Design (naming, abstractions, helper bloat)"
    "Tests (coverage, redundancy)"
    "Comments (comment quality)"
)

# Validate we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: not in a git repository" >&2
    exit 1
fi

# Ensure .hive/ exists (it should be a symlink created by hive ctx init)
if [[ ! -d ".hive" ]]; then
    echo "Error: .hive/ not found — run 'hive ctx init' first" >&2
    exit 1
fi

echo "ReviewRalph: $ITERATIONS iteration(s)"
echo "Output:      $REVIEW_FILE"
echo ""

for i in $(seq 1 "$ITERATIONS"); do
    SKILL_INDEX=$(( (i - 1) % ${#SKILLS[@]} ))
    SKILL_FILE="${SKILLS[$SKILL_INDEX]}"
    SKILL_NAME="${SKILL_NAMES[$SKILL_INDEX]}"

    echo "── Iteration $i/$ITERATIONS: $SKILL_NAME ──────────────────────"

    # Tool-based analysis for specific skill passes
    TOOL_SECTION=""
    if [[ $SKILL_INDEX -eq 0 ]] && command -v deadcode &>/dev/null; then
        echo "  running deadcode..."
        TOOL_OUTPUT=$(deadcode -test ./... 2>&1 || true)
        if [[ -n "$TOOL_OUTPUT" ]]; then
            TOOL_SECTION="## Dead Code Analysis (deadcode -test ./...)
\`\`\`
${TOOL_OUTPUT}
\`\`\`
"
        fi
    elif [[ $SKILL_INDEX -eq 1 ]] && command -v go &>/dev/null && [[ -f go.mod ]]; then
        echo "  running coverage..."
        TOOL_OUTPUT=$(go test ./... -coverprofile=/tmp/ralph-coverage.out -covermode=atomic 2>&1 \
            && go tool cover -func=/tmp/ralph-coverage.out 2>&1 || true)
        if [[ -n "$TOOL_OUTPUT" ]]; then
            TOOL_SECTION="## Test Coverage (go test -coverprofile)
\`\`\`
${TOOL_OUTPUT}
\`\`\`
"
        fi
    fi

    # Collect diff
    DIFF=$(git diff main...HEAD 2>/dev/null; git diff 2>/dev/null)
    if [[ -z "$DIFF" ]]; then
        echo "  warning: no diff against main found — using staged+unstaged changes only"
        DIFF=$(git diff HEAD 2>/dev/null || true)
    fi

    # Load skill content
    SKILL_CONTENT=$(cat "$SKILL_FILE" 2>/dev/null || echo "(skill file not found: $SKILL_FILE)")
    FORMAT_CONTENT=$(cat "$FORMAT_SKILL" 2>/dev/null || echo "")

    # Build prompt
    PROMPT="You are performing iteration $i of $ITERATIONS in a self-critiquing code review loop.

Focus this iteration: ${SKILL_NAME}

---
${FORMAT_CONTENT}
---

## Skill Instructions for This Iteration

${SKILL_CONTENT}

${TOOL_SECTION}
## Code Diff

\`\`\`diff
${DIFF}
\`\`\`
"

    if [[ -f "$REVIEW_FILE" ]]; then
        PREV_REVIEW=$(cat "$REVIEW_FILE")
        PROMPT+="
## Previous Review (Iteration $((i - 1))) — Challenge This

Read the review below critically before writing your own. You must:
- Validate every finding against the diff above — if the evidence is absent or weak, downgrade to Nit or drop it
- Identify what this review missed entirely given your skill focus this iteration
- Correct any false positives before carrying findings forward
- Do not repeat findings verbatim — update them or remove them

${PREV_REVIEW}
"
    fi

    PROMPT+="
Produce the complete updated review using the format defined above.
This is iteration $i of $ITERATIONS — be more precise and evidence-based than the previous pass.
Every Critical and Suggestion finding must cite a specific file and line from the diff."

    echo "  running claude..."
    claude --dangerously-skip-permissions -p "$PROMPT" | tee "$REVIEW_FILE"
    echo "  saved → $REVIEW_FILE"
    echo ""
done

echo "══ ReviewRalph complete ($ITERATIONS iteration(s)) ════════════"
echo "Final review: $REVIEW_FILE"
