#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/select.h>
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
  page[4] = '|';
  while (page[4]) {
    page[1]++;
    page[5] = time(NULL);
  }
  while (true) {
    fcntl(0, F_SETFL, O_NONBLOCK);
    while (page[4]) {
      page[1]++;
      page[5] = time(NULL);
    }
    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(0, &readfds);
    struct timeval timeout = { 0, };
    printf("select\n");
    if (select(1, &readfds, NULL, NULL, &timeout)) {
      printf("local -> remote\n");
      ssize_t ret = read(0, page + 1024, 8192);
      if (ret > 0) {
	page[3] = ret;
	page[4] = '>';
	while (page[4]) {
	  page[1]++;
	  page[5] = time(NULL);
	}
	continue;
      }
    }
    printf("remote -> local\n");
    page[3] = 0;
    page[4] = '<';
    while (page[4]) {
      page[1]++;
      page[5] = time(NULL);
    }
    if (page[3])
      write(1, page + 1024, page[3]);
  }
  exit(0);
}
