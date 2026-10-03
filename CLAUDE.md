# CLAUDE.md

A port of PCRE2 to OpenVMS (IA64, x86-64) that stores only our deltas over the signed
upstream release. It is a sibling of `~/projects/vms-grep` (github.com/issinoho/vms-grep),
whose `CLAUDE.md` lists the ground rules and the VMS/ssh/DCL pitfalls. All of them apply
here, so read it first. In short:

- **Never edit `staging/`, `cache/` or `out/`.** Change upstream files with
  `patches/NNNN-*.patch` (listed in `patches/series`); add new files under `overlay/`.
  Run `tools/prepare.sh` after every change, before building.
- **Configuration** is `overlay/vms/config/config-vms.txt`, applied to
  `src/config.h.generic` by `tools/gen_config.py`, with a reason for each setting.
- **Compiler qualifiers** (`overlay/vms/config/ccflags.txt`) must match vms-grep's,
  especially `/NAMES=(AS_IS,SHORTENED)`: grep links this library statically, and long
  external names are only shortened identically when both use the same `/NAMES`.
- **Use `tools/vms.sh`** for all remote work. Never run raw `ssh host cmd`, and never use
  `WAIT` in DCL run over ssh.
- **Committed files must not contain real node details.** The real values live in the
  git-ignored `tools/nodes.conf`.
- **Releases:** `upstream.conf` pins the version, SHA-256 and the signing key's primary
  fingerprint; `keys/` holds the public key.

## Commands

```sh
tools/prepare.sh                         # fetch + verify, patch, overlay, config.h, MMS list
tools/build.sh <ia64|x86> [ALL|CLEAN] [KEEP_GOING]
tools/vms.sh <node> dcl '<cmd>' ...      # also run/batch/put/get
tools/kit.sh <node>                      # build, then PCSI kit -> out/kits/ (producer ISSINOHO)
tools/installcheck.sh <node>             # install kit, build a program against it, remove (changes system; ask first)
```

Bump `VMS_PATCH_LEVEL` for any kit change and never reuse a kit version.

Don't push without the user asking; the remote is `origin` (github.com/issinoho/vms-pcre2).
