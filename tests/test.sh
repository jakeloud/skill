#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLIENT="$ROOT/skills/jakeloud/scripts/jakeloud.sh"
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/jakeloud-skill-test.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT

export JAKELOUD_CONFIG="$TEST_TMP/config/jakeloud.json"
export MOCK_CURL_REQUESTS="$TEST_TMP/requests.jsonl"
export MOCK_FIXTURES="$ROOT/tests/fixtures"
export PATH="$ROOT/tests/bin:$PATH"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local value=$1
  local expected=$2
  [[ "$value" == *"$expected"* ]] || fail "expected output to contain: $expected"
}

mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

printf 'http://localhost:666\nadmin@example.com\nsecret-password\n' | bash "$CLIENT" configure >/dev/null
[[ -f "$JAKELOUD_CONFIG" ]] || fail "configure did not create the config file"
[[ $(mode "$JAKELOUD_CONFIG") == 600 ]] || fail "config file mode is not 600"
[[ $(mode "${JAKELOUD_CONFIG%/*}") == 700 ]] || fail "config directory mode is not 700"
[[ $(jq -r '.base_url' "$JAKELOUD_CONFIG") == http://localhost:666 ]] || fail "base URL was not saved"

if printf 'http://jl.example.com\nadmin@example.com\nsecret-password\n' | bash "$CLIENT" configure >"$TEST_TMP/http.out" 2>"$TEST_TMP/http.err"; then
  fail "configure accepted remote HTTP without explicit opt-in"
fi
assert_contains "$(<"$TEST_TMP/http.err")" 'HTTP is insecure'

if printf 'https://user:password@jl.example.com\nadmin@example.com\nsecret-password\n' | bash "$CLIENT" configure >"$TEST_TMP/userinfo.out" 2>"$TEST_TMP/userinfo.err"; then
  fail "configure accepted credentials embedded in the base URL"
fi
assert_contains "$(<"$TEST_TMP/userinfo.err")" 'must not contain embedded credentials'

projects=$(bash "$CLIENT" projects)
assert_contains "$projects" $'store\trunning\tstore.example.com:5'
[[ "$projects" != *$'jakeloud\t'* ]] || fail "service project should not be listed"

projects_json=$(bash "$CLIENT" projects --json)
[[ $(jq 'length' <<<"$projects_json") == 1 ]] || fail "JSON project list has the wrong length"
[[ $(jq -r '.[0].name' <<<"$projects_json") == store ]] || fail "JSON project list has the wrong project"
[[ $(jq -r '.[0] | has("additional")' <<<"$projects_json") == false ]] || fail "JSON project list exposed additional fields"

status=$(bash "$CLIENT" status store)
assert_contains "$status" 'State: running'
assert_contains "$status" 'Release: 7'
assert_contains "$status" 'Process: active (pid 1234)'
assert_contains "$status" 'release ready'

status_json=$(bash "$CLIENT" status store --json)
[[ $(jq -r '.additional.runtime.pid' <<<"$status_json") == 1234 ]] || fail "status JSON is incorrect"
[[ $(jq -r '.additional | has("cmd")' <<<"$status_json") == false ]] || fail "status JSON exposed the deployment command"

if bash "$CLIENT" reboot store >"$TEST_TMP/reboot.out" 2>"$TEST_TMP/reboot.err"; then
  fail "reboot succeeded without --yes"
fi
assert_contains "$(<"$TEST_TMP/reboot.err")" 'requires explicit confirmation'

reboot=$(bash "$CLIENT" reboot store --yes)
assert_contains "$reboot" 'Full reboot started for store'
reboot_payload=$(jq -s 'map(select(.op == "createAppOp")) | last' "$MOCK_CURL_REQUESTS")
[[ $(jq -r '.name' <<<"$reboot_payload") == store ]] || fail "reboot project name was not preserved"
[[ $(jq -r '.repo' <<<"$reboot_payload") == 'git@github.com:example/store.git' ]] || fail "reboot repository was not preserved"
[[ $(jq -r '.domain' <<<"$reboot_payload") == 'store.example.com:5' ]] || fail "reboot domain was not preserved"
[[ $(jq -r '.additional.cmd' <<<"$reboot_payload") == *'docker build -t store'* ]] || fail "reboot command was not preserved"

if MOCK_AUTH_FAIL=true bash "$CLIENT" projects >"$TEST_TMP/auth.out" 2>"$TEST_TMP/auth.err"; then
  fail "authentication failure returned success"
fi
assert_contains "$(<"$TEST_TMP/auth.err")" 'authentication failed'

printf 'All tests passed\n'
