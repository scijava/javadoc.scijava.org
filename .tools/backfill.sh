#!/bin/bash
#
# backfill.sh VERSION... - build several pom-scijava releases into the build
# tree, one at a time, stopping at the first sign of trouble.
#
# For (re)building many releases at once, e.g. after a pombast or jgo fix
# that changes what is built; update.py handles each new release on its own.
# Each release's log goes to $JD_LOGS/{version}${LOG_SUFFIX}.log. A release
# stops the run if pombast fails, a repository rate-limits (429) or refuses
# (401/403) us, or it makes more than MAX_REQUESTS remote requests: far more
# than a release needs once most artifacts are cached.
#
# Publish afterwards with pombast's bin/publish-javadoc.sh.

set -u

ROOT=/var/www/javadoc
BUILD=${JD_BUILD:-$ROOT/build}
LOGS=${JD_LOGS:-$ROOT/logs}
POMBAST=${JD_POMBAST:-$ROOT/src/pombast}
POM_SCIJAVA=${JD_POM_SCIJAVA:-$ROOT/src/pom-scijava}
MAX_REQUESTS=${MAX_REQUESTS:-3000}
# The same caches update.py uses (see there).
export M2_REPO=${M2_REPO:-$ROOT/cache/m2}
export CJDK_CACHE_DIR=${CJDK_CACHE_DIR:-$ROOT/cache/cjdk}
export UV_CACHE_DIR=${UV_CACHE_DIR:-$ROOT/cache/uv}

if [ $# -eq 0 ]; then
  sed -n '3,14s/^# \{0,1\}//p' "$0" >&2
  exit 2
fi
mkdir -p "$LOGS"
cd "$POM_SCIJAVA" || exit 1
for v in "$@"; do
  log=$LOGS/$v${LOG_SUFFIX:-}.log
  echo "=== $(date -Is) pom-scijava $v"
  uv run --project "$POMBAST" pombast javadoc --config pombast.toml \
    --workers 2 -o "$BUILD" "org.scijava:pom-scijava:$v" > "$log" 2>&1
  code=$?
  limited=$(grep -c "Rate-limited" "$log")
  denied=$(grep -cE "HTTP (401|403)" "$log")
  reqs=$(grep -oE "Remote requests: .*" "$log" | grep -oE "[0-9]+" | paste -sd+ | bc)
  echo "    exit $code, requests ${reqs:-0}, 429s $limited, denials $denied"
  grep -E "^(Unpacked|Union org)" "$log" | sed 's/^/    /'
  if [ "$code" -ne 0 ] || [ "$limited" -gt 0 ] || [ "$denied" -gt 0 ] ||
    [ "${reqs:-0}" -gt "$MAX_REQUESTS" ]; then
    echo "=== stopping after $v (see $log)"
    exit 1
  fi
done
echo "=== $(date -Is) done"
