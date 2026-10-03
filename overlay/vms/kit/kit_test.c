/* kit_test.c - compiled and linked against an installed PCRE2 kit by
   tools/vms_installcheck.com, to check that the headers and object library
   in PCRE2$ROOT work for a program built the documented way.  */
#include <stdio.h>
#include <string.h>
#include <pcre2.h>

int
main (void)
{
  int err;
  PCRE2_SIZE erroff;
  PCRE2_UCHAR ver[64];
  const char *subject = "order 12345 shipped";
  pcre2_code *re = pcre2_compile ((PCRE2_SPTR) "(?<num>\\d+)\\s(?=shipped)",
                                  PCRE2_ZERO_TERMINATED, PCRE2_UTF, &err, &erroff, NULL);
  if (! re)
    {
      printf ("KIT_TEST: compile failed (%d)\n", err);
      return 1;
    }
  pcre2_match_data *md = pcre2_match_data_create_from_pattern (re, NULL);
  int rc = pcre2_match (re, (PCRE2_SPTR) subject, strlen (subject), 0, 0, md, NULL);
  PCRE2_SIZE *ov = pcre2_get_ovector_pointer (md);
  int ok = rc == 2 && ov[2] == 6 && ov[3] == 11;
  pcre2_config (PCRE2_CONFIG_VERSION, ver);
  printf ("KIT_TEST: %s (PCRE2 %s, match rc=%d, group 1 at %d..%d)\n",
          ok ? "PASS" : "FAIL", (char *) ver, rc, rc > 1 ? (int) ov[2] : -1,
          rc > 1 ? (int) ov[3] : -1);
  pcre2_match_data_free (md);
  pcre2_code_free (re);
  return ok ? 0 : 1;
}
