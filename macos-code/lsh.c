#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char **argv)
{
  volatile unsigned long *page;
  posix_memalign(&page, 16384, 16384);
  strcpy(page + 1024, argv[1]);
  page[0] = 0x5a6b448a98b350b6;
  page[3] = 0;
  while (page[4])
    page[1]++;
  page[4] = 'C';
  while (page[4])
    page[1]++;
  write(1, page + 1024, page[3]);
  exit(0);
}
