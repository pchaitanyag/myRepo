#!/usr/bin/env bash
# rollback.sh – Roll back a deployment to a previous SHA.
#
# Usage:
#   bash scripts/rollback.sh <environment> <previous-sha>
#
# Environment variables (consumed from GitHub Actions context):
#   DEPLOY_HOST   – SSH host / k8s cluster / platform endpoint
#   DEPLOY_TOKEN  – Authentication token
#
# The script is intentionally generic. Adapt the "platform-specific" section
# below for your deployment target (k8s, ECS, Heroku, bare-metal SSH, etc.).

set -euo pipefail

ENVIRONMENT="${1:-}"
PREVIOUS_SHA="${2:-}"

if [[ -z "$ENVIRONMENT" || -z "$PREVIOUS_SHA" ]]; then
  echo "Usage: rollback.sh <environment> <previous-sha>" >&2
  exit 1
fi

echo "========================================"
echo " Rollback"
echo " Environment : $ENVIRONMENT"
echo " Rolling to  : $PREVIOUS_SHA"
echo " Time        : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "========================================"

# ── Validate SHA format ────────────────────────────────────────────────────
if [[ "$PREVIOUS_SHA" == "none" ]]; then
  echo "::error::No previous SHA available for rollback. Cannot proceed." >&2
  exit 1
fi

if ! [[ "$PREVIOUS_SHA" =~ ^[0-9a-f]{7,40}$ ]]; then
  echo "::error::Invalid SHA format: $PREVIOUS_SHA" >&2
  exit 1
fi

# ── Platform-specific rollback logic ─────────────────────────────────────────
# Replace / extend the sections below to match your infrastructure.

case "$ENVIRONMENT" in
  staging)
    echo "→ Rolling back STAGING to $PREVIOUS_SHA"
    # Example: Kubernetes
    # kubectl set image deployment/app-staging app=registry/app:"$PREVIOUS_SHA" --record
    # kubectl rollout status deployment/app-staging --timeout=120s

    # Example: docker-compose over SSH
    # ssh "$DEPLOY_HOST" "cd /srv/app && git checkout $PREVIOUS_SHA && docker-compose up -d"

    echo "  [stub] staging rollback to $PREVIOUS_SHA – replace with real commands"
    ;;

  production)
    echo "→ Rolling back PRODUCTION to $PREVIOUS_SHA"
    # Example: Kubernetes
    # kubectl set image deployment/app-production app=registry/app:"$PREVIOUS_SHA" --record
    # kubectl rollout status deployment/app-production --timeout=180s

    echo "  [stub] production rollback to $PREVIOUS_SHA – replace with real commands"
    ;;

  *)
    echo "::error::Unknown environment: $ENVIRONMENT" >&2
    exit 1
    ;;
esac

echo "✅ Rollback to $PREVIOUS_SHA completed for $ENVIRONMENT"
