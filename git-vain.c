#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#define MAX_MESSAGE 16


int main(int argc, char *argv[]) {
  char message[MAX_MESSAGE+1];
  bool dry_run = false;
  if (argc==2) {
    if (!strncmp(argv[1], "--dry-run", sizeof("--dry-run"))) { dry_run = true; }
    else { strlcpy(message, argv[1], MAX_MESSAGE+1); }
  } else if (argc==3) {
    strlcpy(message, argv[1], MAX_MESSAGE+1);
    if (!strncmp(argv[2], "--dry-run", sizeof("--dry-run"))) { dry_run = true; }
    else { puts("incorrect arguments"); return 1; }
  } else if (argc>3) {
    puts("too many arguments");
    return 1;
  }
  printf("args: %d, message: %s, dry: %d \n", argc, message, dry_run);
  return 0;
}

