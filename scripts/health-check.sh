#!/usr/bin/env bash
# health-check.sh – Poll a service URL until it is healthy or retries are exhausted.
#
# Usage:
#   bash scripts/health-check.sh --url <URL> --retries <N> --interval <S> [--sha <SHA>]
#
# Exit codes:
#   0 – service is healthy
#   1 – service is unhealthy after all retries

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
URL=""
RETRIES=5
INTERVAL=15
SHA=""
EXPECTED_STATUS=200
HEALTH_PATH="/health"

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)       URL="$2";             shift 2 ;;
    --retries)   RETRIES="$2";         shift 2 ;;
    --interval)  INTERVAL="$2";        shift 2 ;;
    --sha)       SHA="$2";             shift 2 ;;
    --status)    EXPECTED_STATUS="$2"; shift 2 ;;
    --path)      HEALTH_PATH="$2";     shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "Error: --url is required" >&2
  exit 1
fi

echo "========================================"
echo " Health Check"
echo " URL     : $URL"
echo " Retries : $RETRIES"
echo " Interval: ${INTERVAL}s"
[[ -n "$SHA" ]] && echo " SHA     : $SHA"
echo "========================================"

# ── Helper ───────────────────────────────────────────────────────────────────
check_health() {
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 30 \
    "${URL}${HEALTH_PATH}" 2>/dev/null) || return 1
  echo "  → HTTP $http_code"
  [[ "$http_code" == "$EXPECTED_STATUS" ]]
}

# ── Main retry loop ───────────────────────────────────────────────────────────
attempt=1
while (( attempt <= RETRIES )); do
  echo "[Attempt $attempt/$RETRIES] Checking $URL/health ..."

  if check_health; then
    echo "✅ Health check PASSED on attempt $attempt"
    exit 0
  fi

  if (( attempt < RETRIES )); then
    echo "  Waiting ${INTERVAL}s before next attempt..."
    sleep "$INTERVAL"
  fi

  (( attempt++ ))
done

echo "❌ Health check FAILED after $RETRIES attempts" >&2
exit 1
