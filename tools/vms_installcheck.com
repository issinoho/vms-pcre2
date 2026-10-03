$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the PCRE2 kit, verify it,
$! compile and link a program against the installed library, run pcre2test
$! from it, then remove it.  Changes the system while it runs (PCSI database,
$! SYS$COMMON:[PCRE2], system logical PCRE2$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ here = f$environment("DEFAULT")
$ tree = here - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$! A PCRE2$ROOT left in the process table (from a build) would hide the system one.
$ if f$trnlnm("PCRE2$ROOT", "LNM$PROCESS_TABLE") .nes. "" then deassign/process PCRE2$ROOT
$ write sys$output "=== INSTALL from ", kitdir
$ product install PCRE2 /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product PCRE2 /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:PCRE2$STARTUP.COM"), "]"
$ show logical PCRE2$ROOT
$ directory/nohead/notrail PCRE2$ROOT:[000000...]*.*
$ write sys$output "=== BUILD A PROGRAM AGAINST THE INSTALLED KIT"
$ test_src = tree - "]" + ".VMS.KIT]KIT_TEST.C"
$ cc /names=(as_is,shortened) /include=PCRE2$ROOT:[INCLUDE] -
     /define=PCRE2_CODE_UNIT_WIDTH=8 /object=kit_test.obj 'test_src'
$ link /executable=kit_test.exe kit_test.obj, PCRE2$ROOT:[LIB]PCRE2-8.OLB/library
$ run kit_test.exe
$ delete/nolog kit_test.obj;*, kit_test.exe;*
$ write sys$output "=== PCRE2TEST FROM THE INSTALLED KIT"
$ pcre2test = "$PCRE2$ROOT:[BIN]PCRE2TEST.EXE"
$ pcre2test "-C"
$ write sys$output "=== REMOVE"
$ product remove PCRE2 /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "PCRE2$ROOT after removal: [", f$trnlnm("PCRE2$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[PCRE2...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:PCRE2$STARTUP.COM"), "]"
$ product show product PCRE2 /producer=ISSINOHO
