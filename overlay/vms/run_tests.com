$! RUN_TESTS.COM - run PCRE2's test suites with VSI Perl
$!
$! Usage:  @[.VMS]RUN_TESTS [test-number ...]
$! Needs a built [.BIN_<arch>]PCRE2TEST.EXE and VSI Perl.  Output files go to
$! [.TESTOUT]; results are printed.
$!
$ set noon
$ status = 44
$ saved_default = f$environment("DEFAULT")
$ saved_parse = f$getjpi("", "PARSE_STYLE_PERM")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ top = f$environment("DEFAULT")
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ bin = f$parse("[.BIN_''arch']PCRE2TEST.EXE")
$ pcre2test :== $'bin'
$!
$! Test 3 selects the French locale as "fr_FR", which VMS ships as
$! fr_FR.ISO8859-1.  Alias it in a private directory searched first by this
$! process (the whole SYS$I18N_LOCALE search list is kept).
$ if f$search("SYS$I18N_LOCALE:FR_FR_ISO8859-1.LOCALE") .eqs. "" then goto no_fr
$ locdir = top - "]" + ".TESTOUT.LOCALE]"
$ if f$search("TESTOUT.DIR") .eqs. "" then create/directory [.TESTOUT]
$ if f$search("[.TESTOUT]LOCALE.DIR") .eqs. "" then create/directory 'locdir'
$ copy/nolog SYS$I18N_LOCALE:FR_FR_ISO8859-1.LOCALE 'locdir'FR_FR.LOCALE
$ purge/nolog 'locdir'
$ i18n = ""
$ i = 0
$i18n_loop:
$ e = f$trnlnm("SYS$I18N_LOCALE",,i)
$ if e .eqs. "" then goto i18n_done
$ i18n = i18n + "," + e
$ i = i + 1
$ goto i18n_loop
$i18n_done:
$ define/process SYS$I18N_LOCALE 'locdir''i18n'
$no_fr:
$!
$! Several Perl versions may be installed; the last one found is the newest.
$ perl_setup = ""
$perl_loop:
$ f = f$search("SYS$COMMON:[PERL-5_*]PERL_SETUP.COM", 5)
$ if f .eqs. "" then goto perl_done
$ perl_setup = f
$ goto perl_loop
$perl_done:
$ if perl_setup .eqs. ""
$ then
$   write sys$error "RUN_TESTS: VSI Perl not found"
$   goto finish
$ endif
$ @'perl_setup'
$! Upper-case pcre2test options (-LM, -C ...) need extended parsing.
$ set process/parse_style=extended
$ perl vms/run_tests.pl 'p1' 'p2' 'p3' 'p4' 'p5' 'p6' 'p7' 'p8'
$ status = $status
$finish:
$ set process/parse_style='saved_parse'
$ if f$trnlnm("SYS$I18N_LOCALE", "LNM$PROCESS_TABLE") .nes. "" then deassign/process SYS$I18N_LOCALE
$ set default 'saved_default'
$ delete/symbol/global pcre2test
$ exit status
