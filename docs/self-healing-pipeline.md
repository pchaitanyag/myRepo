# Self-Healing CI/CD Pipeline

## Overview

This repository contains a **Self-Healing CI/CD Pipeline** implemented with GitHub Actions. The pipeline automatically detects and recovers from common failure modes — minimising manual intervention and maximising deployment reliability.

```
┌────────────────────────────────────────────────────────────────┐
│                    Self-Healing CI/CD Pipeline                 │
│                                                                │
│  Push / PR                                                     │
│     │                                                          │
│     ▼                                                          │
│  ┌─────────┐  pass   ┌──────────────┐  healthy  ┌──────────┐  │
│  │  CI     │ ──────► │  CD Staging  │ ────────► │  CD Prod │  │
│  │ Workflow│         │  + Health    │           │ + Health │  │
│  └────┬────┘         │    Check     │           │  Check   │  │
│       │ fail         └──────┬───────┘           └────┬─────┘  │
│       │                     │ unhealthy               │unhealthy│
│       ▼                     ▼                         ▼        │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Self-Heal Orchestrator                      │  │
│  │  • Classify failure (transient/dep/test/infra/unknown)  │  │
│  │  • Auto-retry transient failures                        │  │
│  │  • Auto-fix + PR for dependency failures                │  │
│  │  • Open GitHub Issue + notify for others                │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## Workflows

| Workflow | File | Trigger | Purpose |
|---|---|---|---|
| **CI** | `.github/workflows/ci.yml` | Push / PR | Build, lint, test, security scan |
| **CD** | `.github/workflows/cd.yml` | CI success on `main` | Deploy → staging → production |
| **Self-Heal** | `.github/workflows/self-heal.yml` | Any workflow failure | Triage and remediate failures |
| **Dependency Scan** | `.github/workflows/dependency-scan.yml` | Weekly / package file change | Find & fix vulnerable deps |

---

## Self-Healing Features

### 1. Automatic Job Retry
Every long-running or network-sensitive job is wrapped with [`nick-fields/retry`](https://github.com/nick-fields/retry), which retries up to **3 times** with exponential back-off before reporting a failure.

Configured in `config/pipeline.yml`:
```yaml
retry:
  max_attempts: 3
  wait_seconds: 30
  backoff_multiplier: 2
```

### 2. Flaky-Test Detection
When tests fail on the first attempt, the CI workflow automatically re-runs **only the failed tests**. If they pass on the second attempt they are marked as **flaky** (a warning annotation) but the build is not broken. If they fail again, the build fails.

```
Attempt 1 → some tests fail
  └─► Attempt 2 → failed tests only
        ├── pass  →  ⚠️ Flaky (build GREEN)
        └── fail  →  ❌ Build FAILED
```

### 3. Deployment Health Checks
After every deployment (staging and production) the pipeline polls `<SERVICE_URL>/health` up to **5 times** with a 15-second interval.

```bash
# Manually run the health check
bash scripts/health-check.sh \
  --url https://my-service.example.com \
  --retries 5 \
  --interval 15
```

### 4. Automatic Rollback
If post-deployment health checks fail, `scripts/rollback.sh` is automatically invoked to restore the previous SHA.

```bash
# Manually trigger a rollback
bash scripts/rollback.sh staging <previous-sha>
bash scripts/rollback.sh production <previous-sha>
```

> **Note:** `rollback.sh` contains stub commands. Replace them with your real infrastructure commands (e.g. `kubectl set image …`, AWS CLI, Heroku CLI).

### 5. Failure Classification & Remediation
The `self-heal.yml` workflow classifies every pipeline failure into one of five types and takes the appropriate action:

| Type | Example Keywords | Action |
|---|---|---|
| `transient` | timeout, ETIMEDOUT, 503, rate-limit | Re-run failed jobs automatically |
| `dependency` | npm audit, Cannot find module | Open a PR with `npm audit fix` |
| `test` | jest, pytest, assertion failed | Open a GitHub Issue for review |
| `infrastructure` | runner, OOM, disk full | Open a GitHub Issue + alert on-call |
| `unknown` | (none of the above) | Open a GitHub Issue + alert on-call |

### 6. Automated Dependency Vulnerability Fixes
The `dependency-scan.yml` workflow runs every **Monday at 03:00 UTC** (and on every `package.json` / `package-lock.json` change). It:
1. Runs `npm audit`
2. If high/critical vulnerabilities are found, runs `npm audit fix --force`
3. If any files changed, opens a pull request for review

### 7. Notifications
`scripts/notify.sh` sends messages to any **Slack-compatible webhook**. Set the `NOTIFY_WEBHOOK_URL` secret in your repository or environment settings.

```bash
bash scripts/notify.sh \
  --level success \
  --message "Deploy to production succeeded" \
  --webhook "$NOTIFY_WEBHOOK_URL"
```

Levels: `info`, `success`, `warning`, `error`

---

## Configuration

All tunable parameters live in `config/pipeline.yml`. You do **not** need to edit the workflow files to change retry counts, health-check intervals, etc.

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml               # Build, lint, test, security scan
│       ├── cd.yml               # Staging + production deployment
│       ├── self-heal.yml        # Failure triage & remediation
│       └── dependency-scan.yml  # Weekly vulnerability scan
├── config/
│   └── pipeline.yml             # Tunable pipeline parameters
├── docs/
│   └── self-healing-pipeline.md # This file
├── scripts/
│   ├── classify-failure.sh      # Classifies CI/CD failure types
│   ├── deploy.sh                # Stub deployment script
│   ├── health-check.sh          # Service health poller
│   ├── notify.sh                # Webhook notification sender
│   └── rollback.sh              # Deployment rollback
└── tests/
    └── test-scripts.sh          # Shell script unit tests
```

---

## Setup Instructions

### 1. GitHub Secrets
Configure the following secrets in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `NOTIFY_WEBHOOK_URL` | Slack / Teams incoming-webhook URL |

### 2. GitHub Variables
Configure the following variables in **Settings → Secrets and variables → Actions → Variables**:

| Variable | Example Value | Description |
|---|---|---|
| `STAGING_URL` | `https://staging.example.com` | Staging environment URL |
| `PRODUCTION_URL` | `https://example.com` | Production environment URL |

### 3. GitHub Environments
Create two environments in **Settings → Environments**:

- `staging` – no protection rules required
- `production` – enable **required reviewers** to gate production deployments

### 4. Adapt the Deploy & Rollback Scripts
Edit `scripts/deploy.sh` and `scripts/rollback.sh` to replace the `[stub]` comments with real commands for your infrastructure (Kubernetes, ECS, Heroku, SSH, etc.).

### 5. Run the Tests
```bash
bash tests/test-scripts.sh
```

---

## Extending the Pipeline

| Goal | How |
|---|---|
| Add a new environment | Add a job in `cd.yml` following the `deploy-staging` pattern; add env config to `config/pipeline.yml` |
| Add a new failure category | Add keywords to `scripts/classify-failure.sh` and a matching job in `self-heal.yml` |
| Use a different notification provider | Adapt the payload in `scripts/notify.sh` (e.g. Microsoft Teams card format) |
| Support Python / Go dependencies | Add `pip audit` / `govulncheck` steps to `dependency-scan.yml` |
