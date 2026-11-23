#!/usr/bin/env bash
set -euo pipefail

: "${PR_NUMBER:?PR_NUMBER is required}"

output_dir="${1:-.review-context}"
mkdir -p "$output_dir/issues"

gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER" > "$output_dir/pr.json"
gh pr diff "$PR_NUMBER" > "$output_dir/diff.patch"
gh pr view "$PR_NUMBER" --json comments,reviews > "$output_dir/discussion.json"

head_sha="$(jq -r '.head.sha' "$output_dir/pr.json")"
gh api "repos/{owner}/{repo}/commits/$head_sha/check-runs" > "$output_dir/check-runs.json"
gh api "repos/{owner}/{repo}/commits/$head_sha/status" > "$output_dir/commit-status.json"
gh pr checks "$PR_NUMBER" > "$output_dir/checks.txt" || true
gh api "repos/{owner}/{repo}/actions/artifacts?per_page=100" > "$output_dir/artifacts.json"

jq -r '.body // ""' "$output_dir/pr.json" \
  | { grep -oE '#[0-9]+' || true; } \
  | tr -d '#' \
  | sort -un \
  | while read -r issue_number; do
      if ! gh issue view "$issue_number" \
        --json number,title,body,state,labels,comments,url \
        > "$output_dir/issues/$issue_number.json"; then
        printf 'Issue #%s could not be read.\n' "$issue_number" \
          > "$output_dir/issues/$issue_number.unavailable"
      fi
    done

cat > "$output_dir/prompt.txt" <<EOF
Проведи независимое read-only ревью pull request #$PR_NUMBER на head SHA $head_sha.

Сначала прочитай REVIEW.md и выполни его критерии. Затем прочитай:
- $output_dir/pr.json — описание PR и ссылки на исходные задачи;
- $output_dir/diff.patch — полный diff;
- $output_dir/issues/ — спецификация, тикеты и комментарии согласования;
- $output_dir/discussion.json — предыдущие замечания и решения людей;
- $output_dir/checks.txt, check-runs.json, commit-status.json — доступные результаты CI;
- $output_dir/artifacts.json — доступные браузерные артефакты.

Сверь изменение со спецификацией и человеческим согласованием. Учитывай уже разобранные замечания. Если источник недоступен, CI ещё выполняется или артефакт относится к другому SHA, прямо укажи ограничение. Не изменяй файлы, не запускай shell и не публикуй комментарии самостоятельно.

Верни только текст ревью на русском. Каждое подтверждённое замечание оформи с файлом, строкой, условиями ошибки, последствием и рекомендацией проверки. Если дефектов нет, прямо сообщи об этом. Не дублируй линтер и форматтер.
EOF
