# myRepo

A **Self-Healing CI/CD Pipeline** implemented with GitHub Actions.

Automatically detects, classifies, and recovers from common pipeline failures — reducing manual intervention and maximising deployment reliability.

## Quick Links

- 📖 [Full Documentation](docs/self-healing-pipeline.md)
- ⚙️ [Pipeline Configuration](config/pipeline.yml)
- 🔧 [Scripts](scripts/)
- 🧪 [Tests](tests/)

## Self-Healing Features at a Glance

| Feature | Description |
|---|---|
| **Automatic retry** | Jobs retry up to 3× with exponential back-off |
| **Flaky-test detection** | Failed tests re-run to distinguish flakes from true failures |
| **Health checks** | Service polled after every deployment |
| **Auto-rollback** | Reverts to previous SHA when health checks fail |
| **Failure classification** | Categorises failures as transient / dependency / test / infra |
| **Auto-fix PRs** | Opens PRs with `npm audit fix` for dependency failures |
| **Issue escalation** | Creates GitHub Issues for failures needing manual review |
| **Notifications** | Slack-compatible webhook alerts on key events |

## Running Tests

```bash
bash tests/test-scripts.sh
```

See [docs/self-healing-pipeline.md](docs/self-healing-pipeline.md) for full setup instructions.