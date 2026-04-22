#!/usr/bin/env bash
# pr-status.sh — Report PR status as JSON for ci-watch skill
#
# Usage: pr-status.sh [PR_NUMBER]
#   PR_NUMBER  optional; defaults to current branch's open PR
#
# Output: JSON matching the ci-watch schema

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "pr-status.sh error: $*" >&2; exit 1; }

# Emit a "no PR found" JSON and exit cleanly
no_pr_json() {
  local forge="$1"
  printf '{"forge":"%s","pr_number":0,"pr_title":"","pr_state":"no_pr","ci_status":"unknown","failing_checks":[],"review_comments":[],"action_needed":"none"}\n' "$forge"
  exit 0
}

# ---------------------------------------------------------------------------
# Forge detection
# ---------------------------------------------------------------------------

REMOTE_URL=$(git remote get-url origin 2>/dev/null) || die "no git remote 'origin'"

if echo "$REMOTE_URL" | grep -qi "github\.com"; then
  FORGE="github"
else
  FORGE="gitea"
fi

# ---------------------------------------------------------------------------
# Determine PR number
# ---------------------------------------------------------------------------

PR_NUMBER="${1:-}"

if [[ "$FORGE" == "github" ]]; then

  # -------------------------------------------------------------------------
  # GitHub path
  # -------------------------------------------------------------------------

  if [[ -z "$PR_NUMBER" ]]; then
    PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null) || no_pr_json "github"
  fi

  [[ -z "$PR_NUMBER" ]] && no_pr_json "github"

  # PR metadata + CI rollup
  PR_JSON=$(gh pr view "$PR_NUMBER" \
    --json number,title,headRefName,state,statusCheckRollup \
    2>/dev/null) || no_pr_json "github"

  PR_TITLE=$(echo "$PR_JSON" | jq -r '.title // ""')
  PR_STATE=$(echo "$PR_JSON" | jq -r '.state // "unknown"' | tr '[:upper:]' '[:lower:]')

  # Map GitHub states to our schema (MERGED → merged, OPEN → open, CLOSED → closed)
  case "$PR_STATE" in
    merged) PR_STATE="merged" ;;
    closed) PR_STATE="closed" ;;
    *)      PR_STATE="open" ;;
  esac

  # CI status from statusCheckRollup
  ROLLUP=$(echo "$PR_JSON" | jq -r '.statusCheckRollup // [] | length')

  if [[ "$ROLLUP" -eq 0 ]]; then
    CI_STATUS="unknown"
  else
    # Aggregate: any FAILURE/ERROR → fail; any PENDING/IN_PROGRESS → pending; else pass
    OVERALL=$(echo "$PR_JSON" | jq -r '
      .statusCheckRollup
      | if any(.state? == "FAILURE" or .state? == "ERROR" or .conclusion? == "failure" or .conclusion? == "timed_out" or .conclusion? == "cancelled") then "fail"
        elif any(.state? == "PENDING" or .state? == "IN_PROGRESS" or .state? == "EXPECTED" or .conclusion? == null and .status? != "COMPLETED") then "pending"
        else "pass"
        end
    ')
    CI_STATUS="$OVERALL"
  fi

  # Failing checks via gh pr checks (gives names + URLs)
  FAILING_CHECKS_JSON="[]"
  if [[ "$CI_STATUS" == "fail" ]]; then
    # gh pr checks outputs TSV: name \t state \t elapsed \t link
    FAILING_CHECKS_JSON=$(gh pr checks "$PR_NUMBER" 2>/dev/null \
      | awk -F'\t' '$2 ~ /^(fail|error|FAIL|ERROR)/' \
      | jq -Rn '
          [inputs | split("\t") | select(length >= 4) | {"name": .[0], "url": .[3]}]
        ' 2>/dev/null || echo "[]")
  fi

  # Review comments (inline)
  OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
  REVIEW_COMMENTS_JSON="[]"

  if [[ -n "$OWNER_REPO" ]]; then
    REVIEW_COMMENTS_JSON=$(gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/comments" \
      --paginate 2>/dev/null \
      | jq '[.[] | {file: .path, line: (.line // .original_line // 0), body: .body, author: .user.login}]' \
      2>/dev/null || echo "[]")

    # Top-level reviews — check for CHANGES_REQUESTED
    CHANGES_REQUESTED=$(gh api "repos/${OWNER_REPO}/pulls/${PR_NUMBER}/reviews" \
      --paginate 2>/dev/null \
      | jq '[.[] | select(.state == "CHANGES_REQUESTED") | {file: "", line: 0, body: .body, author: .user.login}]' \
      2>/dev/null || echo "[]")

    # Merge inline comments + CHANGES_REQUESTED reviews into one list
    REVIEW_COMMENTS_JSON=$(jq -n \
      --argjson inline "$REVIEW_COMMENTS_JSON" \
      --argjson reviews "$CHANGES_REQUESTED" \
      '$inline + $reviews')
  fi

else

  # -------------------------------------------------------------------------
  # Gitea path
  # -------------------------------------------------------------------------

  # Parse host, owner, repo from remote URL
  # Supports: https://host/owner/repo or git@host:owner/repo
  if echo "$REMOTE_URL" | grep -q "^https://"; then
    GITEA_HOST=$(echo "$REMOTE_URL" | sed 's|https://||' | cut -d'/' -f1)
    OWNER=$(echo "$REMOTE_URL" | sed 's|https://[^/]*/||' | cut -d'/' -f1)
    REPO=$(echo "$REMOTE_URL" | sed 's|https://[^/]*/[^/]*/||' | sed 's|\.git$||')
  else
    GITEA_HOST=$(echo "$REMOTE_URL" | sed 's|.*@||' | cut -d':' -f1)
    OWNER=$(echo "$REMOTE_URL" | cut -d':' -f2 | cut -d'/' -f1)
    REPO=$(echo "$REMOTE_URL" | cut -d':' -f2 | cut -d'/' -f2 | sed 's|\.git$||')
  fi

  API_BASE="https://${GITEA_HOST}/api/v1"

  if [[ -z "$PR_NUMBER" ]]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || no_pr_json "gitea"
    # Find open PR for current branch
    PR_NUMBER=$(teaapi curl "${API_BASE}/repos/${OWNER}/${REPO}/pulls?state=open&limit=50" 2>/dev/null \
      | jq -r --arg branch "$CURRENT_BRANCH" '.[] | select(.head.label == $branch) | .number' \
      | head -1)
  fi

  [[ -z "$PR_NUMBER" ]] && no_pr_json "gitea"

  # Full PR JSON (includes head.sha)
  PR_JSON=$(teaapi curl "${API_BASE}/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}" 2>/dev/null) \
    || no_pr_json "gitea"

  PR_TITLE=$(echo "$PR_JSON" | jq -r '.title // ""')
  RAW_STATE=$(echo "$PR_JSON" | jq -r '.state // "open"')
  MERGED=$(echo "$PR_JSON" | jq -r '.merged // false')

  if [[ "$MERGED" == "true" ]]; then
    PR_STATE="merged"
  elif [[ "$RAW_STATE" == "closed" ]]; then
    PR_STATE="closed"
  else
    PR_STATE="open"
  fi

  HEAD_SHA=$(echo "$PR_JSON" | jq -r '.head.sha // ""')

  # CI status via commit statuses
  CI_STATUS="unknown"
  FAILING_CHECKS_JSON="[]"

  if [[ -n "$HEAD_SHA" ]]; then
    STATUSES=$(teaapi curl "${API_BASE}/repos/${OWNER}/${REPO}/statuses/${HEAD_SHA}" \
      2>/dev/null || echo "[]")

    STATUS_COUNT=$(echo "$STATUSES" | jq 'length' 2>/dev/null || echo 0)

    if [[ "$STATUS_COUNT" -gt 0 ]]; then
      # Gitea statuses: state is "success","failure","error","pending","warning"
      HAS_FAILURE=$(echo "$STATUSES" | jq 'any(.state == "failure" or .state == "error")' 2>/dev/null || echo "false")
      HAS_PENDING=$(echo "$STATUSES" | jq 'any(.state == "pending" or .state == "warning")' 2>/dev/null || echo "false")

      if [[ "$HAS_FAILURE" == "true" ]]; then
        CI_STATUS="fail"
        FAILING_CHECKS_JSON=$(echo "$STATUSES" | jq '[
          .[] | select(.state == "failure" or .state == "error")
          | {name: .context, url: .target_url}
        ]' 2>/dev/null || echo "[]")
      elif [[ "$HAS_PENDING" == "true" ]]; then
        CI_STATUS="pending"
      else
        CI_STATUS="pass"
      fi
    fi
  fi

  # Review comments
  REVIEW_COMMENTS_JSON=$(teaapi curl \
    "${API_BASE}/repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
    2>/dev/null \
    | jq '[
        .[] | select(.state == "REQUEST_CHANGES")
        | {file: "", line: 0, body: .body, author: .user.login}
      ]' \
    2>/dev/null || echo "[]")

fi

# ---------------------------------------------------------------------------
# action_needed logic
# ---------------------------------------------------------------------------

HAS_FAILING=$(echo "$FAILING_CHECKS_JSON" | jq 'length > 0' 2>/dev/null || echo "false")
HAS_COMMENTS=$(echo "$REVIEW_COMMENTS_JSON" | jq 'length > 0' 2>/dev/null || echo "false")

if [[ "$CI_STATUS" == "fail" ]] || [[ "$HAS_FAILING" == "true" ]]; then
  ACTION_NEEDED="ci"
elif [[ "$HAS_COMMENTS" == "true" ]]; then
  ACTION_NEEDED="comments"
elif [[ "$CI_STATUS" == "pending" || "$CI_STATUS" == "unknown" ]]; then
  ACTION_NEEDED="wait"
else
  ACTION_NEEDED="none"
fi

# ---------------------------------------------------------------------------
# Emit JSON
# ---------------------------------------------------------------------------

jq -n \
  --arg forge "$FORGE" \
  --argjson pr_number "$PR_NUMBER" \
  --arg pr_title "$PR_TITLE" \
  --arg pr_state "$PR_STATE" \
  --arg ci_status "$CI_STATUS" \
  --argjson failing_checks "$FAILING_CHECKS_JSON" \
  --argjson review_comments "$REVIEW_COMMENTS_JSON" \
  --arg action_needed "$ACTION_NEEDED" \
  '{
    forge: $forge,
    pr_number: $pr_number,
    pr_title: $pr_title,
    pr_state: $pr_state,
    ci_status: $ci_status,
    failing_checks: $failing_checks,
    review_comments: $review_comments,
    action_needed: $action_needed
  }'
