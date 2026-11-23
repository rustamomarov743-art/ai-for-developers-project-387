#!/usr/bin/env bash
set -euo pipefail

: "${PR_NUMBER?PR_NUMBER is required}"
: "${CURRENT_RUN_ID:?CURRENT_RUN_ID is required}"
: "${CURRENT_ATTEMPT:?CURRENT_ATTEMPT is required}"
: "${WORKFLOW_ID:?WORKFLOW_ID is required}"

limit="${PR_MODEL_LIMIT:-3}"

if [[ -z "$PR_NUMBER" ]]; then
  echo "allowed=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

run_title="opencode PR #$PR_NUMBER"
count=0

while read -r run_id run_attempts; do
  [[ -n "$run_id" ]] || continue
  for ((attempt = 1; attempt <= run_attempts; attempt++)); do
    if [[ "$run_id" == "$CURRENT_RUN_ID" && "$attempt" == "$CURRENT_ATTEMPT" ]]; then
      continue
    fi

    started="$(
      gh api "repos/{owner}/{repo}/actions/runs/$run_id/attempts/$attempt/jobs?per_page=100" \
        --jq '[.jobs[].steps[] | select(.name == "Run OpenCode" and .started_at != null)] | length'
    )"
    if [[ "$started" -gt 0 ]]; then
      count=$((count + 1))
    fi
  done
done < <(
  gh api --paginate "repos/{owner}/{repo}/actions/workflows/$WORKFLOW_ID/runs?per_page=100" \
    --jq ".workflow_runs[] | select(.display_title == \"$run_title\") | [.id, .run_attempt] | @tsv"
)

echo "count=$count" >> "$GITHUB_OUTPUT"
echo "limit=$limit" >> "$GITHUB_OUTPUT"
if [[ "$count" -ge "$limit" ]]; then
  echo "allowed=false" >> "$GITHUB_OUTPUT"
  echo "reason=limit_exhausted" >> "$GITHUB_OUTPUT"
else
  echo "allowed=true" >> "$GITHUB_OUTPUT"
fi
