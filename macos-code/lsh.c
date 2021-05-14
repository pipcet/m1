#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

int main(int argc, char **argv)
{
  volatile unsigned long *page;
  posix_memalign(&page, 16384, 16384);
  strcpy(page + 1024, argv[1]);
  page[0] = 0x5a6b448a98b350b6;
  page[3] = 0;
  while (page[4]) {
    page[1]++;
    page[5] = time(NULL);
  }
  page[4] = 'C';
  while (page[4]) {
    page[1]++;
    page[5] = time(NULL);
  }
  write(1, page + 1024, page[3]);
  page[0] = 0;
  exit(0);
}
