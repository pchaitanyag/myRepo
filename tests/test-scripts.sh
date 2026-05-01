#!/usr/bin/env bash
# tests/test-scripts.sh – Unit tests for self-healing pipeline scripts.
# Run with:  bash tests/test-scripts.sh
# Requires:  bash 4+, curl (mocked via PATH override)

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"

# ── Mini test harness ─────────────────────────────────────────────────────────
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✅ PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ FAIL: $desc"
    echo "     expected: $expected"
    echo "     actual  : $actual"
    (( FAIL++ )) || true
  fi
}

assert_exit() {
  local desc="$1" expected_code="$2"
  shift 2
  local actual_code=0
  "$@" || actual_code=$?
  assert_eq "$desc (exit code)" "$expected_code" "$actual_code"
}

# ── Mock curl ─────────────────────────────────────────────────────────────────
# We override curl with a function that returns a configurable HTTP code.
setup_curl_mock() {
  local http_code="${1:-200}"
  export MOCK_HTTP_CODE="$http_code"
  export PATH="/tmp/mock-bin:$PATH"
  mkdir -p /tmp/mock-bin
  cat > /tmp/mock-bin/curl <<'EOF'
#!/usr/bin/env bash
# Minimal curl mock: honours -w "%{http_code}" and -o /dev/null
WRITE_OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w) WRITE_OUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ "$WRITE_OUT" == "%{http_code}" ]]; then
  echo -n "${MOCK_HTTP_CODE:-200}"
fi
exit 0
EOF
  chmod +x /tmp/mock-bin/curl
}

teardown_curl_mock() {
  rm -f /tmp/mock-bin/curl
}

# ── Tests: classify-failure.sh ────────────────────────────────────────────────
echo ""
echo "=== classify-failure.sh ==="

run_classify() {
  local json="$1"
  # Capture only the 'type=...' line
  unset GITHUB_OUTPUT
  bash "$SCRIPT_DIR/classify-failure.sh" "$json" 2>/dev/null | grep '^type=' | cut -d= -f2
}

assert_eq "timeout → transient" \
  "transient" \
  "$(run_classify '[{"name":"install","steps":["Download timed out"]}]')"

assert_eq "ETIMEDOUT → transient" \
  "transient" \
  "$(run_classify '[{"name":"install","steps":["ETIMEDOUT error occurred"]}]')"

assert_eq "npm audit → dependency" \
  "dependency" \
  "$(run_classify '[{"name":"audit","steps":["npm audit found issues"]}]')"

assert_eq "module not found → dependency" \
  "dependency" \
  "$(run_classify '[{"name":"build","steps":["Cannot find module lodash"]}]')"

assert_eq "jest test fail → test" \
  "test" \
  "$(run_classify '[{"name":"test","steps":["jest: 3 tests failed"]}]')"

assert_eq "OOM → infrastructure" \
  "infrastructure" \
  "$(run_classify '[{"name":"deploy","steps":["runner: out of memory"]}]')"

assert_eq "unknown failure → unknown" \
  "unknown" \
  "$(run_classify '[{"name":"misc","steps":["Something unexpected happened"]}]')"

# ── Tests: health-check.sh ────────────────────────────────────────────────────
echo ""
echo "=== health-check.sh ==="

setup_curl_mock "200"
assert_exit "healthy endpoint passes (exit 0)" 0 \
  bash "$SCRIPT_DIR/health-check.sh" --url "http://localhost:8080" --retries 2 --interval 0

teardown_curl_mock
setup_curl_mock "503"
assert_exit "unhealthy endpoint fails (exit 1)" 1 \
  bash "$SCRIPT_DIR/health-check.sh" --url "http://localhost:8080" --retries 2 --interval 0

teardown_curl_mock

# Missing --url should exit 1
assert_exit "missing --url exits 1" 1 \
  bash "$SCRIPT_DIR/health-check.sh" --retries 1 --interval 0

# ── Tests: rollback.sh ────────────────────────────────────────────────────────
echo ""
echo "=== rollback.sh ==="

assert_exit "missing args exits 1" 1 \
  bash "$SCRIPT_DIR/rollback.sh"

assert_exit "SHA=none exits 1" 1 \
  bash "$SCRIPT_DIR/rollback.sh" staging "none"

assert_exit "invalid SHA exits 1" 1 \
  bash "$SCRIPT_DIR/rollback.sh" staging "not-a-sha!!"

assert_exit "unknown environment exits 1" 1 \
  bash "$SCRIPT_DIR/rollback.sh" unknown-env "abc1234"

assert_exit "valid staging rollback succeeds" 0 \
  bash "$SCRIPT_DIR/rollback.sh" staging "abc1234def5"

assert_exit "valid production rollback succeeds" 0 \
  bash "$SCRIPT_DIR/rollback.sh" production "abc1234def5"

# ── Tests: notify.sh ─────────────────────────────────────────────────────────
echo ""
echo "=== notify.sh ==="

assert_exit "missing --message exits 1" 1 \
  bash "$SCRIPT_DIR/notify.sh" --level info

assert_exit "no webhook still exits 0" 0 \
  bash "$SCRIPT_DIR/notify.sh" --level success --message "All good"

setup_curl_mock "200"
assert_exit "webhook 200 exits 0" 0 \
  bash "$SCRIPT_DIR/notify.sh" --level info --message "hello" --webhook "http://fake-webhook"
teardown_curl_mock

# ── Tests: deploy.sh ──────────────────────────────────────────────────────────
echo ""
echo "=== deploy.sh ==="

assert_exit "missing args exits 1" 1 \
  bash "$SCRIPT_DIR/deploy.sh"

assert_exit "staging deploy succeeds" 0 \
  bash "$SCRIPT_DIR/deploy.sh" staging "deadbeef123"

assert_exit "production deploy succeeds" 0 \
  bash "$SCRIPT_DIR/deploy.sh" production "deadbeef123" "--strategy=blue-green" "--phase=swap"

assert_exit "unknown env exits 1" 1 \
  bash "$SCRIPT_DIR/deploy.sh" unknown "deadbeef123"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================"

[[ "$FAIL" -eq 0 ]] || exit 1
