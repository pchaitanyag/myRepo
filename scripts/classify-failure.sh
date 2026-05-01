#!/usr/bin/env bash
# classify-failure.sh – Classify a CI/CD failure into a known category.
#
# Usage:
#   bash scripts/classify-failure.sh '<json-string-of-failed-jobs>'
#
# Outputs (via GITHUB_OUTPUT or stdout):
#   type = transient | dependency | test | infrastructure | unknown
#
# Classification heuristics (keyword-based):
#   transient      – network errors, rate-limits, timeout, connection refused
#   dependency     – npm audit, package not found, dependency resolution
#   test           – test failures that are not infrastructure or dependency
#   infrastructure – runner, docker, k8s, OOM, disk, permission denied
#   unknown        – none of the above

set -euo pipefail

FAILED_JOBS_JSON="${1:-[]}"

# ── Flatten to lowercase text for keyword matching ───────────────────────────
FLAT_TEXT=$(echo "$FAILED_JOBS_JSON" | tr '[:upper:]' '[:lower:]')

classify() {
  local text="$1"

  # Transient: network or timeout issues
  if echo "$text" | grep -qE "(network|timeout|timed out|connection refused|rate.?limit|econnreset|etimedout|enotfound|socket hang up|503|502|504)"; then
    echo "transient"
    return
  fi

  # Dependency: package management issues
  if echo "$text" | grep -qE "(npm audit|package not found|peer dep|dependency resolution|cannot find module|module not found|enoent.*node_modules|lock file)"; then
    echo "dependency"
    return
  fi

  # Infrastructure: runner / OS / container issues
  if echo "$text" | grep -qE "(runner|docker|kubernetes|k8s|out of memory|oom|disk full|permission denied|no such file or directory|cannot allocate|segfault)"; then
    echo "infrastructure"
    return
  fi

  # Test: explicit test-step failures (catches jest, mocha, pytest, etc.)
  if echo "$text" | grep -qE "(test|spec|jest|mocha|pytest|rspec|assertion|expect.*fail|fail.*expect)"; then
    echo "test"
    return
  fi

  echo "unknown"
}

TYPE=$(classify "$FLAT_TEXT")
echo "Classified failure as: $TYPE"

# Output for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "type=$TYPE" >> "$GITHUB_OUTPUT"
else
  echo "type=$TYPE"
fi
