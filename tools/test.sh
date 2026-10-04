#!/usr/bin/env bash
# test.sh <node> [test-number...] - run PCRE2's test suites on <node> (VSI Perl).
# Output is saved to out/tests-<node>.log; exit status 0 only if nothing failed.
# VARIANT=CLANG tests the clang build (build.sh <node> ALL "" CLANG).
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
node=${1:?usage: test.sh <node> [test-number...]}; shift
. "$top/upstream.conf"
remote=$(echo "$UPSTREAM_NAME-$UPSTREAM_VERSION" | tr . _ | tr a-z A-Z)
read -r _ _ _ _ _ WORKDIR _ < <(awk -v n="$node" '$1==n' "$top/tools/nodes.conf")

mkdir -p "$top/out"
job=$top/cache/tests-$node.com
{ printf '$ set noon\n'
  [ "${VARIANT:-}" = CLANG ] && printf '$ define/process pcre2_test_variant clang\n'
  printf '$ @%s.%s.VMS]RUN_TESTS.COM %s\n' "${WORKDIR%]}" "$remote" "$*"; } > "$job"
VMS_TIMEOUT=${VMS_TEST_TIMEOUT:-3600} "$top/tools/vms.sh" "$node" run "$job" |
    grep -av '^$' | tee "$top/out/tests-$node${VARIANT:-}.log"
grep -q 'PCRE2 TESTS: [0-9]* passed, 0 failed' "$top/out/tests-$node${VARIANT:-}.log"
