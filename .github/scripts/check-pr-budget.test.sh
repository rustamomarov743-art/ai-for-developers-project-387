#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d "$PWD/.budget-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

workflow_path="$script_dir/../workflows/opencode.yml"
if ! grep -Eq '^run-name: "opencode .+#\$\{\{[^}]+\}\}"$' "$workflow_path"; then
  echo "PR number in run-name must be inside a quoted YAML scalar" >&2
  exit 1
fi

cat > "$tmp_dir/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "${MOCK_MODE:-count}" == "api_error" ]]; then
  echo "Actions API unavailable" >&2
  exit 1
fi

case "$*" in
  *"actions/workflows/opencode.yml/runs"*) printf '1\t2\n2\t1\n999\t1\n' ;;
  *"actions/runs/1/attempts/1/jobs"*|*"actions/runs/1/attempts/2/jobs"*|*"actions/runs/2/attempts/1/jobs"*) printf '1\n' ;;
  *"actions/runs/999/attempts/1/jobs"*) printf '0\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp_dir/bin/gh"

export PATH="$tmp_dir/bin:$PATH"
export PR_NUMBER=42 CURRENT_RUN_ID=999 CURRENT_ATTEMPT=1
export WORKFLOW_ID=opencode.yml PR_MODEL_LIMIT=3
export GITHUB_OUTPUT="$tmp_dir/output"

: > "$GITHUB_OUTPUT"
bash "$script_dir/check-pr-budget.sh"
grep -q '^count=3$' "$GITHUB_OUTPUT"
grep -q '^allowed=false$' "$GITHUB_OUTPUT"
grep -q '^reason=limit_exhausted$' "$GITHUB_OUTPUT"

: > "$GITHUB_OUTPUT"
export MOCK_MODE=api_error
if bash "$script_dir/check-pr-budget.sh"; then
  echo "Expected an Actions API failure to close the budget" >&2
  exit 1
fi
if grep -q '^allowed=true$' "$GITHUB_OUTPUT"; then
  echo "Budget must not allow a model call when Actions API fails" >&2
  exit 1
fi

printf 'Budget regression tests passed\n'
