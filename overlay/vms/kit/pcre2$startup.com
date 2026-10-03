$! PCRE2$STARTUP.COM - system startup for the PCRE2 library on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! PCRE2$ROOT, pointing at the installed [PCRE2] directory, so that programs
$! compile with /INCLUDE=PCRE2$ROOT:[INCLUDE] and link with
$! PCRE2$ROOT:[LIB]PCRE2-8.OLB/LIBRARY.  To run it at every boot, add this
$! line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:PCRE2$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign PCRE2$ROOT instead (PCSI runs it so at removal).
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("PCRE2$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode PCRE2$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[PCRE2].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.PCRE2.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "PCRE2.]"
$ if root .eqs. dir + "PCRE2.]"
$ then
$   write sys$error "PCRE2$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed PCRE2$ROOT 'dev''root'
$ if f$search("PCRE2$ROOT:[LIB]PCRE2-8.OLB") .eqs. ""
$ then
$   write sys$error "PCRE2$STARTUP: PCRE2-8.OLB not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for PCRE2"
$ say ""
$ say "    At system startup: to define PCRE2$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:PCRE2$STARTUP.COM"
$ say "    Building against PCRE2: compile with"
$ say "    /NAMES=(AS_IS,SHORTENED)/INCLUDE=PCRE2$ROOT:[INCLUDE]/DEFINE=PCRE2_CODE_UNIT_WIDTH=8"
$ say "    and link with PCRE2$ROOT:[LIB]PCRE2-8.OLB/LIBRARY."
$ say "    See PCRE2$ROOT:[DOC]README.VMS."
$ say ""
$ say "    PRODUCT REMOVE PCRE2 removes the product and deassigns PCRE2$ROOT."
$ say ""
$ exit 1
