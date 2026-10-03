#!/usr/bin/env bash
# prepare.sh - build a VMS-ready PCRE2 source tree in staging/<name>-<version>/
#
#   1. fetch + verify the upstream tarball
#   2. extract it, apply patches/series, lay overlay/ over the top
#   3. config.h from config.h.generic + overlay/vms/config/config-vms.txt,
#      pcre2.h from pcre2.h.generic, pcre2_chartables.c from the .dist copy
#   4. MMS source list from upstream's CMakeLists.txt
#
# Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$top/cache/$(basename "$UPSTREAM_URL")
stage=$top/staging/$name
cfgdir=$top/overlay/vms/config

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"; mkdir -p "$top/staging"
tar -xzf "$tarball" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

# overlay/ may only add files; changes to upstream files belong in patches/.
(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

step "config.h, pcre2.h, pcre2_chartables.c"
python3 "$top/tools/gen_config.py" "$stage/src/config.h.generic" "$cfgdir/config-vms.txt" \
    > "$stage/src/config.h"
cp "$stage/src/pcre2.h.generic" "$stage/src/pcre2.h"
cp "$stage/src/pcre2_chartables.c.dist" "$stage/src/pcre2_chartables.c"

step "MMS source list"
python3 "$top/tools/gen_mms.py" "$stage/CMakeLists.txt" "$cfgdir/ccflags.txt" \
    > "$stage/vms/sources.mms"
printf 'VERSION=%s\nKIT_VERSION=%s-vms%s\n' "$UPSTREAM_VERSION" "$UPSTREAM_VERSION" \
    "$VMS_PATCH_LEVEL" > "$stage/vms/version.env"

step "staged $stage"
