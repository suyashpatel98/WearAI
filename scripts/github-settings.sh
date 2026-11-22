#!/usr/bin/env bash
# Applies the repo settings from docs/spec/dev-ex.md#protecting-main and #security-alerts-and-fixes.
# Idempotent: re-running updates the existing ruleset instead of adding another. Human only.
set -euo pipefail
repo="${1:-suyashpatel98/WearAI}"

echo "Repo settings: squash merge only, PR title as the commit title, delete branches on merge"
gh api -X PATCH "repos/$repo" --silent \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true -F allow_auto_merge=false

echo "Dependabot alerts and security updates"
gh api -X PUT "repos/$repo/vulnerability-alerts" --silent
gh api -X PUT "repos/$repo/automated-security-fixes" --silent

echo "Ruleset 'main': PR required (0 approvals), ci must pass, no force push or deletion, no bypass"
ruleset='{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"] } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "ci", "integration_id": 15368 } ] } }
  ]
}'
id="$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "main") | .id')"
if [ -n "$id" ]; then
  printf '%s' "$ruleset" | gh api -X PUT "repos/$repo/rulesets/$id" --input - --silent
  echo "Updated ruleset $id."
else
  printf '%s' "$ruleset" | gh api -X POST "repos/$repo/rulesets" --input - --silent
  echo "Created ruleset."
fi
echo "Done."
