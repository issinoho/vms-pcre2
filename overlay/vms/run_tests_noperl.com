$! RUN_TESTS_NOPERL.COM - PCRE2's test suites without Perl (OpenVMS Alpha has
$! no VSI Perl).  Started by RUN_TESTS.COM from the top of the tree, with the
$! foreign command PCRE2TEST defined and extended parsing set.  It does what
$! run_tests.pl does -- same tests, same options, same skips, same message
$! formats -- but compares output with SAMELINES, a small C program built here.
$!
$! Usage:  @[.VMS]RUN_TESTS_NOPERL [test-number ...]     (default: all)
$! Exit status 1 if every test that ran passed.
$!
$ set noon
$ want = ","
$ n = 1
$wl:
$ if p'n' .nes. "" then want = want + p'n' + ","
$ n = n + 1
$ if n .le. 8 then goto wl
$ all = (want .eqs. ",")
$ if f$search("TESTOUT.DIR") .eqs. "" then create/directory [.TESTOUT]
$!
$ write sys$output "RUN_TESTS_NOPERL: comparing with SAMELINES.C (no VSI Perl)"
$ cc/names=(as_is,shortened)/object=[.testout]samelines.obj [.vms]samelines.c
$ link/executable=[.testout]samelines.exe [.testout]samelines.obj
$ if .not. $status
$ then
$   write sys$output "FAIL  ??  could not build SAMELINES"
$   exit 44
$ endif
$! pcre2test reads its input files as bytes, so the ones made here must be
$! Stream_LF (a DCL WRITE makes VAR records, which carry length prefixes).
$ create [.testout]stmlf.fdl
FILE
        ORGANIZATION            sequential
RECORD
        FORMAT                  stream_lf
        CARRIAGE_CONTROL        carriage_return
$ samelines = "$" + f$parse("[.TESTOUT]SAMELINES.EXE") - ";"
$!
$! Is test <p1> wanted?
$ goto start
$!
$! Make file <p1> (Stream_LF) from the lines in <p2>, separated by "|".
$mktext: subroutine
$ open/write mkf [.testout]mk.tmp
$ i = 0
$ml:
$ l = f$element(i, "|", p2)
$ if l .eqs. "|" then goto md
$ write mkf l
$ i = i + 1
$ goto ml
$md:
$ close mkf
$ if f$search(p1) .nes. "" then delete/nolog 'p1';*
$ convert/fdl=[.testout]stmlf.fdl [.testout]mk.tmp 'p1'
$ delete/nolog [.testout]mk.tmp;*
$ exit 1
$ endsubroutine
$!
$wanted: subroutine
$ if all .or. f$locate("," + p1 + ",", want) .ne. f$length(want) then exit 1
$ exit 0
$ endsubroutine
$!
$! Compare file <p1> with each alternative in <p2> (comma list under
$! testdata/); like RunTest, any one may match.  Sets cmp_ok and cmp_why.
$compare: subroutine
$ cmp_ok == 0
$ cmp_why == ""
$ if f$search(p1) .eqs. ""
$ then
$   cmp_why == "no output file ''p1'"
$   exit
$ endif
$ i = 0
$cl:
$ e = f$element(i, ",", p2)
$ if e .eqs. "," then exit
$ i = i + 1
$ if f$search("[.testdata]" + e + ".") .eqs. "" then goto cl
$ define/user sys$output [.testout]cmp.txt
$ samelines "''p1'" "[.testdata]''e'."
$ if $status .eq. 1
$ then
$   cmp_ok == 1
$   exit
$ endif
$ open/read/error=cl1 cf [.testout]cmp.txt
$ cmp_why == ""
$cr:
$ read/end=cl1 cf line
$ cmp_why == cmp_why + f$fao("!/!AS", line)
$ goto cr
$cl1:
$ close/nolog cf
$ goto cl
$ endsubroutine
$!
$ start:
$ q = """"
$!
$! Standard test: pcre2test -q -8 [opt] testinputN, compared with <expected>.
$! p1 number, p2 title, p3 expected list, p4 option (or "")
$ goto defs
$run_std: subroutine
$ call wanted 'p1'
$ if .not. $status then exit 1
$ tag = f$edit(p4, "COLLAPSE")
$ got = "testout/testoutput''p1'''tag'"
$ gotv = "[.testout]testoutput''p1'''tag'."
$ if f$search(gotv) .nes. "" then delete/nolog 'gotv';*
$ if p4 .eqs. ""
$ then
$   pcre2test "-q" "-8" "testdata/testinput''p1'" "''got'"
$ else
$   pcre2test "-q" "-8" "''p4'" "testdata/testinput''p1'" "''got'"
$ endif
$ rc = $status
$ if rc .ne. 1
$ then
$   write sys$output f$fao("FAIL  !2AS  !AS !AS!/      pcre2test exit status !XL", p1, p2, tag, rc)
$   fail == fail + 1
$   exit 1
$ endif
$ call compare "''gotv'" "''p3'"
$ if cmp_ok
$ then
$   write sys$output f$fao("PASS  !2AS  !AS !AS", p1, p2, tag)
$   pass == pass + 1
$ else
$   write sys$output f$fao("FAIL  !2AS  !AS !AS", p1, p2, tag), cmp_why
$   fail == fail + 1
$ endif
$ exit 1
$ endsubroutine
$!
$skipt: subroutine
$ call wanted 'p1'
$ if .not. $status then exit 1
$ write sys$output f$fao("SKIP  !2AS  !AS!/      !AS", p1, p2, p3)
$ skip == skip + 1
$ exit 1
$ endsubroutine
$!
$ defs:
$ pass == 0
$ fail == 0
$ skip == 0
$ xfail == 0
$!
$! Test 0: argument handling; only exit statuses are checked (as RunTest).
$! pcre2test exits with POSIX status: 0 gives $STATUS 1; 1 is any other value.
$ call wanted 0
$ if .not. $status then goto t1
$ call mktext "testSinput." "/abc/jit,memory,framesize|   abc"
$ bad = ""
$ i = 0
$t0l:
$ i = i + 1
$ goto t0'i'
$t01:
$ e = 0
$ args = """-8"" ""-C"""
$ goto t0run
$t02:
$ e = 0
$ args = """--help"""
$ goto t0run
$t03:
$ e = 0
$ args = """-8"" ""testSinput"""
$ goto t0run
$t04:
$ e = 0
$ args = """-8"" ""testdata/testinputheap"""
$ goto t0run
$t05:
$ e = 1
$ args = """-8"" ""reallydoesnotexist"""
$ goto t0run
$t06:
$ e = 1
$ args = """-8"" ""testSinput"" ""reallydoesnotexist/outfile"""
$ goto t0run
$t07:
$ e = 0
$ args = """-8"" ""-pattern"" ""debug"" ""testSinput"""
$ goto t0run
$t08:
$ e = 1
$ args = """-8"" ""-pattern"" ""INVALID"" ""testSinput"""
$ goto t0run
$t09:
$ e = 0
$ args = """-8"" ""-subject"" ""notempty"" ""testSinput"""
$ goto t0run
$t010:
$ e = 1
$ args = """-8"" ""-subject"" ""INVALID"" ""testSinput"""
$ goto t0run
$t011:
$ e = 0
$ args = """-LM"""
$ goto t0run
$t012:
$ e = 0
$ args = """-LP"""
$ goto t0run
$t013:
$ e = 0
$ args = """-LS"""
$ goto t0run
$t014:
$ e = 0
$ args = """-8"" ""-unittest"""
$ goto t0run
$t015:
$ goto t0done
$t0run:
$ define/user sys$output nl:
$ define/user sys$error nl:
$ pcre2test 'args'
$ rc = $status
$ ok = (e .eq. 0 .and. rc .eq. 1) .or. (e .eq. 1 .and. rc .ne. 1 .and. rc .ne. 0)
$ if .not. ok then bad = bad + f$fao("!/      pcre2test !AS -> !XL (want !UL)", args, rc, e)
$ goto t0l
$t0done:
$ if f$search("testSinput") .nes. "" then delete/nolog testSinput.;*
$ if bad .eqs. ""
$ then
$   write sys$output "PASS   0  Unchecked pcre2test argument tests "
$   pass == pass + 1
$ else
$   write sys$output "FAIL   0  Unchecked pcre2test argument tests ", bad
$   fail == fail + 1
$ endif
$!
$t1:
$ call run_std 1 "Main non-UTF, non-UCP functionality" testoutput1 ""
$!
$! Test 2 also appends the output of an -error run, and reads testbtables.
$ call wanted 2
$ if .not. $status then goto t3
$ copy/nolog [.testdata]testbtables []testbtables.
$ got = "testout/testoutput2"
$ gotv = "[.testout]testoutput2."
$ if f$search(gotv) .nes. "" then delete/nolog 'gotv';*
$ pcre2test "-q" "-8" "testdata/testinput2" "''got'"
$ rc = $status
$ if rc .eq. 1
$ then
$   define/user sys$output [.testout]err2.txt
$   pcre2test "-q" "-8" "-error" "-80,-62,-2,-1,0,100,101,191,300"
$   append [.testout]err2.txt 'gotv'
$   call compare "''gotv'" testoutput2
$   if cmp_ok
$   then
$     write sys$output "PASS   2  API, errors, internals and non-Perl stuff "
$     pass == pass + 1
$   else
$     write sys$output "FAIL   2  API, errors, internals and non-Perl stuff ", cmp_why
$     fail == fail + 1
$   endif
$ else
$   write sys$output f$fao("FAIL   2  API, errors, internals and non-Perl stuff!/      pcre2test exit status !XL", rc)
$   fail == fail + 1
$ endif
$ if f$search("testbtables.") .nes. "" then delete/nolog testbtables.;*
$!
$! Test 3 needs a French locale that pcre2test can select by one of these
$! names (RUN_TESTS.COM aliases VMS's fr_FR.ISO8859-1 as fr_FR).
$t3:
$ call wanted 3
$ if .not. $status then goto t4
$ loc = ""
$ i = 0
$t3l:
$ nm = f$element(i, ",", "fr_FR,french,fr,fr_CA")
$ if nm .eqs. "," then goto t3d
$ i = i + 1
$ call mktext "testlocale." "/a/locale=''nm'"
$ define/user sys$output [.testout]loc.txt
$ pcre2test "-q" "testlocale"
$ search/nowarn/nooutput [.testout]loc.txt "Failed to set locale"
$ if $status .eq. 1 then goto t3l
$ loc = nm
$t3d:
$ if f$search("testlocale") .nes. "" then delete/nolog testlocale.;*
$ if loc .eqs. ""
$ then
$   call skipt 3 "Locale-specific features" "none of fr_FR, french, fr, fr_CA can be set"
$ else
$   if loc .nes. "fr_FR"
$   then
$     call skipt 3 "Locale-specific features" "only '''loc'' is available; RunTest's renaming not implemented"
$   else
$     before = fail
$     call run_std 3 "Locale-specific features (fr_FR)" "testoutput3,testoutput3A,testoutput3B,testoutput3C" ""
$     if fail .gt. before
$     then
$       fail == fail - 1
$       xfail == xfail + 1
$       write sys$output "      XFAIL: VMS's fr_FR.ISO8859-1 character classes differ from glibc's"
$     endif
$   endif
$ endif
$!
$t4:
$ call run_std 4 "UTF-8 and Unicode property support" testoutput4 ""
$ call run_std 5 "API, internals, and non-Perl stuff for UTF-8 and UCP" testoutput5 ""
$ call run_std 6 "DFA matching main non-UTF, non-UCP functionality" testoutput6 ""
$ call run_std 7 "DFA matching with UTF-8 and Unicode property support" testoutput7 ""
$ call run_std 8 "Internal offsets and code size tests" testoutput8-8-2 ""
$ call run_std 9 "Specials for the basic 8-bit library" testoutput9 ""
$ call run_std 10 "Specials for the 8-bit library with UTF-8 and UCP support" testoutput10 ""
$ call skipt 11 "Specials for the 16-bit and 32-bit libraries" "only the 8-bit library is built"
$ call skipt 12 "Specials for the 16-bit and 32-bit libraries with UTF/UCP" "only the 8-bit library is built"
$ call skipt 13 "DFA specials for the 16-bit and 32-bit libraries" "only the 8-bit library is built"
$ call run_std 14 "DFA specials for UTF and UCP support" testoutput14-8 ""
$ call run_std 15 "Non-JIT limits and other non-JIT tests" testoutput15 ""
$ call run_std 16 "JIT-specific features when JIT is not available" testoutput16 ""
$ call skipt 17 "JIT-specific features when JIT is available" "no JIT on OpenVMS"
$ call run_std 18 "POSIX interface, excluding UTF/UCP" testoutput18 ""
$ call run_std 19 "POSIX interface with UTF/UCP" testoutput19 ""
$ call run_std 20 "Serialization and code copy tests" testoutput20 ""
$ call run_std 21 "\C tests without UTF" testoutput21 ""
$ call run_std 21 "\C tests without UTF" testoutput21 "-dfa"
$ call run_std 22 "\C tests with UTF" testoutput22-8 ""
$ call skipt 23 "\C disabled test" "\C is not disabled in this build"
$ call run_std 24 "Non-UTF pattern conversion tests" testoutput24 ""
$ call run_std 25 "UTF pattern conversion tests" testoutput25 ""
$ call run_std 26 "Unicode property tests" testoutput26 ""
$ call run_std 27 "Auto-generated Unicode property tests" testoutput27 ""
$ call skipt 28 "EBCDIC-specific tests" "not an EBCDIC build"
$ call skipt 29 "EBCDIC-specific tests (NL=0x25)" "not an EBCDIC build"
$!
$ if f$search("testsaved1") .nes. "" then delete/nolog testsaved1;*
$ if f$search("testsaved2") .nes. "" then delete/nolog testsaved2;*
$ write sys$output f$fao("PCRE2 TESTS: !UL passed, !UL failed, !UL expected failures, !UL skipped", pass, fail, xfail, skip)
$ if fail .eq. 0 then exit 1
$ exit 44
