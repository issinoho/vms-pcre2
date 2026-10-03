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

# --- PCSI kit inputs (vms/kit/MAKE_KIT.COM builds the kit on each node) ----
step "PCSI kit inputs"
: "${KIT_PRODUCER:=ISSINOHO}"
major=${UPSTREAM_VERSION%%.*}; minor=${UPSTREAM_VERSION#*.}; minor=${minor%%.*}
pcsiversion="V$major.$minor-$VMS_PATCH_LEVEL"
kitversion="$UPSTREAM_VERSION-vms$VMS_PATCH_LEVEL"
kit=$stage/vms/kit
subst() {
    sed -e "s/@PRODUCER@/$KIT_PRODUCER/g" -e "s/@BASE@/$1/g" \
        -e "s/@PCSIVERSION@/$pcsiversion/g" -e "s/@VERSION@/$UPSTREAM_VERSION/g" \
        -e "s/@KITVERSION@/$kitversion/g" -e "s/@ARCH@/$2/g"
}
for base in I64VMS X86VMS; do
    subst $base "" < "$kit/pcre2.pcsi\$desc_template" > "$kit/PCRE2-$base.PCSI\$DESC"
    subst $base "" < "$kit/pcre2.pcsi\$text_template" > "$kit/PCRE2-$base.PCSI\$TEXT"
done
rm -f "$kit/pcre2.pcsi\$desc_template" "$kit/pcre2.pcsi\$text_template"
subst "" "IA64 and x86-64" < "$kit/readme.vms" > "$kit/README.VMS"; rm -f "$kit/readme.vms"
mkdir -p "$kit/doc"
cp "$stage/LICENCE.md" "$kit/doc/LICENCE.MD"
cp "$stage/NEWS" "$kit/doc/NEWS."
cp "$stage/doc/pcre2.txt" "$kit/doc/PCRE2.TXT"
cp "$stage/doc/pcre2test.txt" "$kit/doc/PCRE2TEST.TXT"
printf 'KIT_PRODUCER=%s\nPCSI_VERSION=%s\nKIT_VERSION=%s\n' "$KIT_PRODUCER" "$pcsiversion" \
    "$kitversion" > "$kit/kit.env"

step "staged $stage"
