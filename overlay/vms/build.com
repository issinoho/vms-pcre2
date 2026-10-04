$! BUILD.COM - build PCRE2 for OpenVMS
$!
$! Usage:  @[.VMS]BUILD [target] [KEEP_GOING] [CLANG]
$!         target defaults to ALL; CLEAN also works.  KEEP_GOING carries on
$!         past failed compiles so one run reports every error.  CLANG (x86-64
$!         only) builds with VSI C++'s clang into the X86_64_CLANG trees, for
$!         programs built with clang (LP64); see [.VMS]DESCRIP.MMS.
$!
$! Runs from the top of the prepared source tree regardless of where it is
$! invoked from.  Outputs: see [.VMS]DESCRIP.MMS
$!
$ status = 44  ! SS$_ABORT unless the build runs
$ on control_y then goto done
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$getsyi("ARCH_NAME")
$ if arch .eqs. "x86_64" then arch = "X86_64"
$ if arch .eqs. "IA64" .or. arch .eqs. "X86_64" then goto arch_ok
$ write sys$error "BUILD: unsupported architecture ''arch'"
$ goto done
$arch_ok:
$ mmsmac = ""
$ if f$edit(p3, "UPCASE") .eqs. "CLANG"
$ then
$   if arch .nes. "X86_64"
$   then
$     write sys$error "BUILD: CLANG needs x86-64"
$     goto done
$   endif
$   arch = "X86_64_CLANG"
$   mmsmac = ",CLANG=1"
$   clang :== $sys$system:clang.exe
$!  Keep the case of clang's arguments (-D...), and show its diagnostics.
$   set process/parse_style=extended
$   define/process decc$argv_parse_style enable
$   define/process sys$error sys$output
$ endif
$ if f$search("OBJ_''arch'.DIR") .eqs. "" then create/directory [.OBJ_'arch']
$ if f$search("[.OBJ_''arch']LIB.DIR") .eqs. "" then create/directory [.OBJ_'arch'.LIB]
$ if f$search("[.OBJ_''arch']POSIX.DIR") .eqs. "" then create/directory [.OBJ_'arch'.POSIX]
$ if f$search("BIN_''arch'.DIR") .eqs. "" then create/directory [.BIN_'arch']
$ if f$search("[.INSTALL_''arch']INCLUDE.DIR") .eqs. "" then create/directory [.INSTALL_'arch'.INCLUDE]
$ if f$search("[.INSTALL_''arch']LIB.DIR") .eqs. "" then create/directory [.INSTALL_'arch'.LIB]
$ target = p1
$ if target .eqs. "" then target = "ALL"
$ write sys$output "BUILD: ''target' for ''arch' in ''f$environment("DEFAULT")'"
$ mmsq = ""
$ if p2 .eqs. "KEEP_GOING" then mmsq = "/IGNORE=ERROR"
$ mms/description=[.vms]descrip.mms/macro=("ARCH=''arch'"'mmsmac')'mmsq' 'target'
$ status = $status
$ if status then write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
