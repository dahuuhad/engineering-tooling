# Engineering Tooling (Reusable)

Shared assets you can reuse across repositories: release helper script, Ruff-first pre-commit config, and reusable GitHub Actions for linting and testing.

## Contents
- `scripts/release.sh`: bumps semver (major/minor/patch) and dispatches a `release-and-tag.yml` workflow via `gh` after running tests.
- `.pre-commit-config.yaml`: Ruff + basic hygiene hooks.
- `.github/workflows/lint.yml`: reusable Ruff lint workflow (workflow_call).
- `.github/workflows/test.yml`: reusable pytest workflow (workflow_call).

## Usage

### Pre-commit (Ruff)
1) Copy or curl the config into your repo (or reference this repo if you prefer syncing):
   - `curl -o .pre-commit-config.yaml https://raw.githubusercontent.com/dahuuhad/engineering-tooling/main/.pre-commit-config.yaml`
2) Install hooks: `pre-commit install`
3) Run manually: `pre-commit run -a`

### Release script
- Add the script (or vendor it via curl) to `scripts/release.sh` and make it executable: `chmod +x scripts/release.sh`.
- Run: `./scripts/release.sh [major|minor|patch]` (defaults to patch). It bumps based on latest tag/release, runs tests, and dispatches `release-and-tag.yml` via `gh`.

### Reusable GitHub Actions
In your repo, create caller workflows like:

**Lint:** `.github/workflows/lint.yml`
```yaml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    uses: dahuuhad/engineering-tooling/.github/workflows/lint.yml@main
    with:
      python_version: "3.11"
```

**Tests:** `.github/workflows/test.yml`
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    uses: dahuuhad/engineering-tooling/.github/workflows/test.yml@main
    with:
      python_version: "3.11"
      test_command: "./bin/pytest-cov"
```

> Tip: Pin to a tag (e.g., `@v1.0.0`) once you tag this repo for stability.

### Suggested structure for new repos
- Place scripts in `scripts/` (make them executable).
- Keep `bin/` for wrappers (e.g., `bin/pytest-cov`).
- Use the shared pre-commit config for Ruff; avoid mixing redundant linters.

## Notes
- The release script expects a `release-and-tag.yml` workflow in the target repo and `gh` authenticated.
- Ruff version pinned to `0.6.9`; update in both the pre-commit config and lint workflow when bumping.
