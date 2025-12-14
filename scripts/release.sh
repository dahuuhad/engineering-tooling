#!/usr/bin/env bash
set -euo pipefail

# Release helper script
# Usage: ./scripts/release.sh [major|minor|patch]
# Defaults to patch. Determines latest semver tag (prefers GitHub releases), bumps,
# then dispatches the reusable release-and-tag workflow via gh CLI.

RELEASE_WORKFLOW_FILE="release-and-tag.yml"
DEFAULT_BUMP="patch"
RELEASE_TYPE="release"  # Could be extended to accept prerelease/draft later

usage() {
  cat <<EOF
Release script
Usage: $0 [major|minor|patch]

Examples:
  $0                # bump patch
  $0 minor          # bump minor
  $0 major          # bump major

Requires: gh CLI authenticated (gh auth login) and access to repository.
Will trigger workflow: ${RELEASE_WORKFLOW_FILE}
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

BUMP_TYPE=${1:-$DEFAULT_BUMP}

if ! [[ "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "[ERROR] Invalid bump type: $BUMP_TYPE" >&2
  usage
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[ERROR] gh CLI not found. Install from https://github.com/cli/cli" >&2
  exit 1
fi

# Ensure we have all tags locally
git fetch --tags --quiet || true

current_tag=""

# Try to get latest GitHub release tag first
if gh release list --limit 1 --json tagName --jq '.[0].tagName' >/dev/null 2>&1; then
  current_tag=$(gh release list --limit 1 --json tagName --jq '.[0].tagName' || true)
fi

# Fallback to git tags if no release
if [[ -z "$current_tag" ]]; then
  current_tag=$(git tag --sort=-version:refname | head -n1 || true)
fi

if [[ -z "$current_tag" ]]; then
  echo "[INFO] No existing tags found; starting from v0.0.0" >&2
  current_tag="v0.0.0"
fi

if ! [[ "$current_tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] Current tag '$current_tag' is not a valid semver (vX.Y.Z)" >&2
  exit 1
fi

# Strip leading v if present
version_core=${current_tag#v}
IFS='.' read -r major minor patch <<<"$version_core"

case "$BUMP_TYPE" in
  major)
    ((major+=1)); minor=0; patch=0 ;;
  minor)
    ((minor+=1)); patch=0 ;;
  patch)
    ((patch+=1)) ;;
esac

new_version="${major}.${minor}.${patch}"
new_tag="v${new_version}"

echo "[INFO] Current tag: $current_tag" >&2
echo "[INFO] Bump type: $BUMP_TYPE" >&2
echo "[INFO] New version: $new_tag" >&2
echo "" >&2

echo "[INFO] Running tests..." >&2
if ! ./bin/pytest-cov -q; then
  echo "[ERROR] Tests failed. Aborting release." >&2
  exit 1
fi
echo "[SUCCESS] All tests passed." >&2
echo "" >&2

read -r -p "Proceed with dispatching workflow for ${new_version}? [y/N] " ans
ans=${ans:-N}
if [[ ! "$ans" =~ ^[Yy]$ ]]; then
  echo "[INFO] Aborted by user." >&2
  exit 0
fi

if ! gh workflow view "$RELEASE_WORKFLOW_FILE" >/dev/null 2>&1; then
  echo "[ERROR] Workflow file '$RELEASE_WORKFLOW_FILE' not found or inaccessible." >&2
  echo "       Ensure .github/workflows/${RELEASE_WORKFLOW_FILE} exists." >&2
  exit 1
fi

echo "[INFO] Triggering workflow dispatch..." >&2
run_output=$(gh workflow run "$RELEASE_WORKFLOW_FILE" -f version="$new_version" -f release_type="$RELEASE_TYPE" || { echo "[ERROR] Workflow dispatch failed" >&2; exit 1; })
echo "$run_output" >&2

echo "[INFO] Waiting briefly for run to register..." >&2
sleep 3

run_id=$(gh run list --workflow "$RELEASE_WORKFLOW_FILE" --limit 1 --json databaseId -q '.[0].databaseId' || true)
if [[ -n "$run_id" ]]; then
  repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
  echo "[INFO] Run created: https://github.com/${repo_slug}/actions/runs/${run_id}" >&2
else
  echo "[WARN] Could not determine run ID; check Actions tab manually." >&2
fi

echo "[SUCCESS] Release workflow dispatched for version ${new_version}" >&2
echo "$new_tag"
