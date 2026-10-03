<p align="center">
  <img src="docs/images/banner.svg" alt="PCRE2 for OpenVMS: a DECterm window running pcre2test, with the PCRE2 mark" width="100%">
</p>

# PCRE2 for OpenVMS

A port of the [PCRE2](https://github.com/PCRE2Project/pcre2) regular-expression library
(10.49) to OpenVMS on **IA64** and **x86-64**, kept as a thin layer over the official
release. Its first user is [GNU grep for OpenVMS](https://github.com/issinoho/vms-grep),
where it provides `grep -P`.

Like vms-grep, this repository holds **only our changes**. Every build starts from the
signed release tarball, which is verified against the PCRE2 maintainer's key in `keys/`.
It then applies our patches, adds our VMS-only files, and generates the configuration for
VSI C.

## Status

Work in progress.

| | IA64 | x86-64 |
|---|---|---|
| Library (8-bit, Unicode, no JIT) builds with MMS | yes | not yet tried |
| `pcre2test` test suites | not yet | not yet |
| Used by grep for `grep -P` | not yet | not yet |
| PCSI kit | planned | planned |

## What gets built

- **`PCRE2-8.OLB`:** the 8-bit library as an object library, for static linking into
  programs such as grep.
- **`PCRE2TEST.EXE`:** PCRE2's test program, used to run the upstream test data on VMS.
- **An install tree** (`[.INSTALL_<arch>]` with `INCLUDE/PCRE2.H` and `LIB/PCRE2-8.OLB`):
  this is what other ports build against.

JIT compilation is not available: SLJIT has no OpenVMS support. Only the 8-bit code unit
width is built.

## Repository layout

```
upstream.conf          upstream version, tarball URL, SHA-256, signing key fingerprint
keys/                  the PCRE2 release signing key
patches/               unified diffs against the upstream tree, applied in order (series)
overlay/vms/           DESCRIP.MMS, BUILD.COM, and configuration (config/config-vms.txt)
tools/                 host-side scripts: fetch, prepare, push, build (shared with vms-grep)
docs/                  documentation and images
```

## How the configuration works

PCRE2 ships `src/config.h.generic` and `src/pcre2.h.generic` for builds without autotools.
`tools/prepare.sh` starts from these. It applies the reviewed VMS settings in
`overlay/vms/config/config-vms.txt` to make `config.h`, uses the shipped character tables,
and generates the MMS source list from upstream's `CMakeLists.txt`. A new release's added
sources are therefore picked up automatically. A setting that has disappeared upstream
stops the build.

## Everyday workflow

```sh
tools/prepare.sh            # fetch + verify tarball, patch, overlay, config.h -> staging/
tools/build.sh ia64         # push changed files, MMS build on the node
tools/build.sh x86
```

Node access works as in vms-grep: `tools/nodes.conf` (git-ignored) and an ssh key.

## Artwork

`docs/images/banner.svg` and `docs/images/icon.svg` were made for this project in the style
of classic DECwindows and VT terminals. They include the PCRE2 project's mark, white
"PC/RE²" on blue as used by the [PCRE2 project](https://github.com/PCRE2Project), to
identify the library this port is built from.

OpenVMS is a trademark of VMS Software, Inc. This project is not affiliated with VMS
Software, Inc. or with the PCRE2 project.

## Licence

PCRE2 is distributed under the BSD licence with the PCRE2 exception; see `COPYING`, a copy
of upstream's `LICENCE.md`. Our patches and VMS build files are distributed under the same
terms.
