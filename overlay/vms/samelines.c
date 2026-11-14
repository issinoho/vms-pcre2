/* samelines.c - used by RUN_TESTS_NOPERL.COM where VSI Perl is missing
   (OpenVMS Alpha).  Usage: samelines GOT EXPECTED
   Exit 0 if the two text files hold the same lines, else print the first
   difference and exit 44.  Like run_tests.pl, a trailing CR is ignored; files
   are read in text mode, so a record-format file (pcre2test's output) and a
   Stream_LF file (the expected output) compare by their lines.  */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char **
slurp (const char *name, long *count)
{
  FILE *f = fopen (name, "r");
  char **lines = NULL;
  long n = 0, cap = 0;
  char *buf = NULL;
  size_t len = 0, bcap = 0;
  int c;

  *count = -1;
  if (f == NULL)
    return NULL;
  *count = 0;
  for (;;)
    {
      c = getc (f);
      if (c == EOF || c == '\n')
        {
          if (c == EOF && len == 0)
            break;
          if (len > 0 && buf[len - 1] == '\r')
            len--;
          if (n == cap)
            {
              cap = cap ? cap * 2 : 1024;
              lines = realloc (lines, cap * sizeof (char *));
              if (lines == NULL)
                exit (45);
            }
          lines[n] = malloc (len + 1);
          if (lines[n] == NULL)
            exit (45);
          if (len > 0)
            memcpy (lines[n], buf, len);
          lines[n][len] = 0;
          n++;
          len = 0;
          if (c == EOF)
            break;
          continue;
        }
      if (len + 1 >= bcap)
        {
          bcap = bcap ? bcap * 2 : 256;
          buf = realloc (buf, bcap);
          if (buf == NULL)
            exit (45);
        }
      buf[len++] = (char) c;
    }
  fclose (f);
  *count = n;
  return lines;
}

int
main (int argc, char **argv)
{
  long ng, nx, i, n;
  char **g, **x;

  if (argc != 3)
    exit (44);
  g = slurp (argv[1], &ng);
  x = slurp (argv[2], &nx);
  if (ng < 0 || nx < 0)
    {
      printf ("      cannot read %s\n", ng < 0 ? argv[1] : argv[2]);
      exit (44);
    }
  n = ng > nx ? ng : nx;
  for (i = 0; i < n; i++)
    if (i >= ng || i >= nx || strcmp (g[i], x[i]) != 0)
      {
        printf ("      first difference at line %ld of %s:\n      want: %s\n      got:  %s\n",
                i + 1, argv[2], i < nx ? x[i] : "<end of file>",
                i < ng ? g[i] : "<end of file>");
        exit (44);
      }
  return 0;
}
