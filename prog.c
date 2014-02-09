#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h> // for read

//#include <openssl/sha.h>
#include <CommonCrypto/CommonDigest.h>
#ifndef SHA_DIGEST_LENGTH
  #define SHA1 CC_SHA1
  #define SHA_DIGEST_LENGTH CC_SHA1_DIGEST_LENGTH
#endif

#define MAX_MESSAGE 17

void setFromGitConfig(char *message) {
  FILE *fp;
  fp = popen("git config vain.default", "r");
  if (fp == NULL) {
    puts("Failed to run git config vain.default");
    exit(1);
  }
  while (fgets(message, MAX_MESSAGE-1, fp) != NULL) { }
  int len = strlen(message);
  if (message[len-1] == '\n') { message[len-1] = '\0'; }
  pclose(fp);
}

bool allHex(char *message) {
  int i = 0;
  while (i < MAX_MESSAGE && message[i] != '\0') {
    char c = message[i];

    if (c >= 'A' && c <= 'F') {
      message[i] = message[i] + 32;
      c = message[i];
    }

    if (! ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) ) {
      return false;
    }
    i++;
  }
  return true;
}

char* getCommit() {
  FILE *fp;
  char buffer[1024];
  char commitbuff[10*1024];
  commitbuff[0]='\0';

  fp = popen("git cat-file -p HEAD", "r");
  if (fp == NULL) {
    puts("Failed to run git cat-file");
    exit(1);
  }

  while (fgets(buffer, sizeof(buffer), fp) != NULL) {
    strcat(commitbuff, buffer);
  }
  pclose(fp);

  int len = strlen(commitbuff);
  char header[20];
  sprintf(header, "commit %d", len);
  int headlen = strlen(header);
  len += headlen+1;

  char * commit = malloc(len+2);
  memcpy(commit, header, headlen);
  commit[headlen+1] = '\0';
  memcpy(commit+headlen+1, commitbuff, len);
  commit[len+1] = '\n';
  commit[len+2] = '\0';

  return commit;
}

int getTimeOffset(char *search, char *commit) {
  char * ptr = commit;
  int len = sizeof(commit);
  int searchlen = strlen(search);

  for( ; ptr < commit+len-searchlen; ptr++) {
    if (!strncmp(ptr, search, searchlen)) {
      break;
    }
  }
  ptr+=searchlen;
  for( ; ptr < commit+len-2; ptr++) {
    if (!strncmp(ptr, "> ", 2)) {
      break;
    }
  }
  ptr+=2;
  return ptr-commit;
}

int dateAtOffset(int offset, char *commit) {
  char * ptr = commit + offset;
  char sub[17];
  for(int i = 0; i < 17; i++) {
    if(*ptr == ' ') {
      sub[i] = '\0';
      break;
    }
    sub[i] = *ptr;
    ptr++;
  }
  return atoi(sub);
}

void alter(char *newCommit, int authOffset, int authDate, int commOffset, int commDate) {
  char datestr[20];
  sprintf(datestr, "%d", authDate);
  for(int i = 0; datestr[i] != '\0'; i++) {
    newCommit[authOffset+i] = datestr[i];
  }
  sprintf(datestr, "%d", commDate);
  for(int i = 0; datestr[i] != '\0'; i++) {
    newCommit[commOffset+i] = datestr[i];
  }
}

int main(int argc, char *argv[]) {
  char message[MAX_MESSAGE];
  for(int i = 0; i < MAX_MESSAGE; i++) { message[i] = '\0'; }
  bool dry_run = false;
  if (argc==2) {
    if (!strncmp(argv[1], "--dry-run", sizeof("--dry-run"))) { dry_run = true; }
    else { strlcpy(message, argv[1], MAX_MESSAGE); }
  } else if (argc==3) {
    strlcpy(message, argv[1], MAX_MESSAGE);
    if (!strncmp(argv[2], "--dry-run", sizeof("--dry-run"))) { dry_run = true; }
    else { puts("incorrect arguments"); exit(1); }
  } else if (argc>3) {
    puts("too many arguments");
    exit(1);
  }

  if (message[0] == '\0') { setFromGitConfig(message); }
  if (!allHex(message)) { printf("message \"%s\" must be all hex", message); exit(1); }


  char * commitWithHeader = getCommit();
  char * commit = commitWithHeader;
  //advance commit past header:w
  for (; *commit != '\0'; commit++) { }
  commit++;
  int commitLen = strlen(commitWithHeader) + 1 + strlen(commit);


  int authOffset = getTimeOffset("\nauthor ",   commit);
  int commOffset = getTimeOffset("\ncommitter ",commit);
  int authDate = dateAtOffset(authOffset, commit);
  int commDate = dateAtOffset(commOffset, commit);
  printf("a: %d, o: %d, ad: %d, od: %d\n", authOffset, commOffset, authDate, commDate);
  printf("args: %d, message: %s, dry: %d \n", argc, message, dry_run);


  char newCommit[strlen(commit)];
  strcpy(newCommit,commit);
  alter(newCommit, authOffset, authDate+52, commOffset, commDate-190);
  printf("===before:\n%s\n===altered:\n%s\n", commit, newCommit);


  unsigned char hash[SHA_DIGEST_LENGTH];
  SHA1(commitWithHeader, commitLen, hash);
  for(int i=0; i<SHA_DIGEST_LENGTH; i++) {
    printf("%02x", hash[i]);
  }
  printf("\n");

  return 0;
}

