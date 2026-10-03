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
| Library (8-bit, Unicode, no JIT) builds with MMS | yes | yes |
| `pcre2test` test suites (8-bit, no JIT) | 23 pass, 0 fail | 23 pass, 0 fail (1 expected: locale data) |
| Used by grep for `grep -P` ([v3.12-vms3](https://github.com/issinoho/vms-grep/releases/tag/v3.12-vms3)) | yes | yes |
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

## Patches

| Patch | Purpose |
|---|---|
| 0001 | `pcre2test`: keep the C exit status when built with POSIX exit semantics. On VMS it otherwise always returns `SS$_NORMAL` and reports through DCL symbols. |
| 0002 | `pcre2_compile`: work around a VSI C 7.4 (IA64) optimiser bug. Writes through `optset`/`xoptset` were lost, so `(?-x)`, `(?-r)` etc. had no effect. |

## Testing

`@[.VMS]RUN_TESTS` (or `tools/test.sh <node>`) runs upstream's test data through
`pcre2test`, the same way upstream's `RunTest` does, using VSI Perl. GNV isn't needed, so
it runs on IA64 as well. Every skipped test gives its reason:
- **11–13:** only the 8-bit library is built.
- **17:** no JIT.
- **23:** `\C` isn't disabled.
- **28–29:** not an EBCDIC build.
- **3, the locale test:** it needs a French locale. It runs on x86-64, where VMS's
  `fr_FR.ISO8859-1` is aliased to `fr_FR`. Its character classes are narrower than glibc's,
  so a difference is reported as an expected failure.

## How to build

The build has two halves. A **Linux host** prepares a ready-to-compile source tree from
the PCRE2 release, and an **OpenVMS system** compiles it with VSI C and MMS. The scripts in
`tools/` can drive the VMS side over ssh. The prepared tree is self-contained, though, so
you can also copy it to VMS any way you like and build there by hand.

### What you need

- **Linux host:** git, bash, python3, curl and gpg. ssh/sftp too, for the automated route.
- **OpenVMS IA64 or x86-64:** VSI C and MMS. OpenSSH for the automated route. VSI Perl for
  the tests. Tested on IA64 V8.4-2L3 with VSI C 7.4, and on x86-64 E9.2-4 with VSI C 7.7.

### 1. Prepare the source tree (Linux)

```sh
git clone https://github.com/issinoho/vms-pcre2.git
cd vms-pcre2
tools/prepare.sh
```

This downloads the release named in `upstream.conf`, and checks its SHA-256 and its GPG
signature against the pinned key in `keys/`. It then applies `patches/`, adds `overlay/`,
generates `src/config.h`, `src/pcre2.h`, the character tables and the MMS source list,
and leaves the result in `staging/pcre2-10.49/`.

### 2a. Build on VMS by hand

Copy `src/`, `testdata/` and `vms/` from `staging/pcre2-10.49/` to a directory on the VMS
system, keeping the directory structure. Then, on VMS:

```
$ SET DEFAULT dev:[dir.PCRE2-10_49]
$ @[.VMS]BUILD                    ! libraries, PCRE2TEST.EXE and the install tree
$ @[.VMS]RUN_TESTS                ! pcre2test test suites (needs VSI Perl)
```

`@[.VMS]BUILD ALL KEEP_GOING` carries on past compile errors so that one run reports them
all. `@[.VMS]BUILD CLEAN` removes the objects. MMS here tracks neither compiler flags nor
headers, so clean after changing either.

### 2b. Build on VMS from the host over ssh

Set up `tools/nodes.conf` and an ssh key as described in
[vms-grep's README](https://github.com/issinoho/vms-grep#2b-build-on-vms-from-the-host-over-ssh).
The same file works for both projects. Then:

```sh
tools/build.sh ia64         # upload changed files, MMS build on the node
tools/test.sh ia64          # pcre2test test suites
tools/build.sh x86 && tools/test.sh x86
```

### 3. Use the library

Point your build at the install tree, for example with
`$ DEFINE PCRE2$ROOT dev:[dir.PCRE2-10_49.INSTALL_IA64.]` (a rooted logical name).
- **Compile** with `/INCLUDE=PCRE2$ROOT:[INCLUDE]` and `/DEFINE=PCRE2_CODE_UNIT_WIDTH=8`.
- **Link** with `PCRE2$ROOT:[LIB]PCRE2-8.OLB/LIBRARY`.
- **Use the same `/NAMES=(AS_IS,SHORTENED)`** as this build. PCRE2's longer external names
  only match when both sides shorten them the same way.

## Roadmap

1. ~~Build grep against this library to enable `grep -P`~~: done in
   [vms-grep v3.12-vms3](https://github.com/issinoho/vms-grep/releases/tag/v3.12-vms3).
2. A PCSI kit for PCRE2 itself (library, headers, `pcre2test`).
3. A port to OpenVMS **Alpha**, alongside IA64 and x86-64.
4. Next port: **GNU sed**, following on from grep and PCRE2 with exactly the same methods
   and roadmap ([vms-sed](https://github.com/issinoho/vms-sed)).

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
