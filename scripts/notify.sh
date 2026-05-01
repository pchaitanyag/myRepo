#!/usr/bin/env bash
# notify.sh – Send a notification to Slack / Microsoft Teams (or any webhook).
#
# Usage:
#   bash scripts/notify.sh --level <info|success|warning|error> \
#                          --message "<text>" \
#                          --webhook "<url>"
#
# If --webhook is empty or unset, the message is only printed to stdout
# (useful for testing without a real endpoint).

set -euo pipefail

# ── Parse arguments ──────────────────────────────────────────────────────────
LEVEL="info"
MESSAGE=""
WEBHOOK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --level)   LEVEL="$2";   shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --webhook) WEBHOOK="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MESSAGE" ]]; then
  echo "Error: --message is required" >&2
  exit 1
fi

# ── Map level to emoji + color ────────────────────────────────────────────────
case "$LEVEL" in
  success) EMOJI="✅"; COLOR="#2ECC71" ;;
  warning) EMOJI="⚠️";  COLOR="#F39C12" ;;
  error)   EMOJI="❌"; COLOR="#E74C3C" ;;
  *)       EMOJI="ℹ️";  COLOR="#3498DB" ;;
esac

FULL_MESSAGE="$EMOJI [$LEVEL] $MESSAGE"

# ── Always print to stdout ────────────────────────────────────────────────────
echo "[notify] $FULL_MESSAGE"

# ── Send to webhook (Slack-compatible) ───────────────────────────────────────
if [[ -n "$WEBHOOK" ]]; then
  PAYLOAD=$(jq -n \
    --arg text "$FULL_MESSAGE" \
    --arg color "$COLOR" \
    --arg level "$LEVEL" \
    '{
      "attachments": [
        {
          "color": $color,
          "text": $text,
          "footer": ("Self-Healing CI/CD | " + (now | todate))
        }
      ]
    }')

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    --connect-timeout 10 \
    --max-time 30 \
    "$WEBHOOK") || {
    echo "::warning::Failed to reach webhook endpoint" >&2
    exit 0   # notification failure should not break the pipeline
  }

  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    echo "  Notification sent (HTTP $HTTP_CODE)"
  else
    echo "::warning::Webhook returned HTTP $HTTP_CODE" >&2
  fi
else
  echo "  No webhook configured – notification logged only."
fi
