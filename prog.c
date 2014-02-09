#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdbool.h>
#include <unistd.h> // for read
#include <pthread.h>
#define MAX_THREADS 8

//#include <openssl/sha.h>
#include <CommonCrypto/CommonDigest.h>
#ifndef SHA_DIGEST_LENGTH
  #define SHA1 CC_SHA1
  #define SHA_DIGEST_LENGTH CC_SHA1_DIGEST_LENGTH
#endif

#define MAX_MESSAGE 17

int headerLen, commitLen, authOffset, commOffset, authDate, commDate;
char message[MAX_MESSAGE];
bool dry_run = false;
bool found = false;
int count=0;

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

  //advance commit past header
  ptr += headerLen;

  int len = strlen(ptr);
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

bool shacmp(char *goal, unsigned char *sha) {
  int len = strlen(goal);
  char current[3];
  for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
    sprintf(current, "%02x", sha[i]);
    for(int j=0; j<2; j++) {
      if (goal[i*2 + j] != current[j]) { return false; }
      if ( i*2 +j+1 >= len) { return true; }
    }
  }
  puts("something went wrong with shacmp");
  exit(1);
}

void spiral_pair(int n, int *x, int *y) {
  // http://2000clicks.com/mathhelp/CountingRationalsSquareSpiral1.aspx
  int s = (sqrt(n)+1)/2;
  int lt = n-( ((2*s)-1) * ((2*s)-1) );
  int l = lt / (2*s);
  int e = lt - (2*s*l) - s+1;

  switch (l) {
  case 0:  *x =  s; *y =  e; break;
  case 1:  *x = -e; *y =  s; break;
  case 2:  *x = -s; *y = -e; break;
  default: *x =  e; *y = -s;
  }
}

int spiral_max(int max_side) {
  return  (max_side*2+1) * (max_side*2+1) - 1;
}



void ammend_commit(char *newCommit, unsigned char *sha, int da, int dc) {
  char progHash[SHA_DIGEST_LENGTH*2];
  for(int i=0; i<SHA_DIGEST_LENGTH; i++) {
    sprintf(progHash+i*2, "%02x", sha[i]);
  }
  printf("da: %d, dc: %d, khash: %d\n%s\n",da,dc, count/1000, progHash);

  if (dry_run) { return; }

  //verify git agrees
  FILE *fp;
  fp = fopen("/tmp/commit", "wb");
  fwrite(newCommit+headerLen, 1, commitLen-headerLen, fp);
  fclose(fp);

  fp = popen("git hash-object -t commit /tmp/commit", "r");
  if (fp == NULL) {
    puts("Failed to run git hash-object");
    exit(1);
  }
  char gitHash[SHA_DIGEST_LENGTH*2+1] = "";
  while (fgets(gitHash, 80, fp) != NULL) { }
  gitHash[SHA_DIGEST_LENGTH*2] = '\0';
  pclose(fp);

  if (strcmp(gitHash,progHash)) {
    puts("prepared commit hash differs from what git thinks") ;
    printf("us: %s\ngit: %s\n",gitHash,progHash);
    exit(1);
  }



}

typedef struct {
  int start;
  int skip;
  char* commit;
} searchArgs;

void *Search(void* argsptr){
  searchArgs args = *((searchArgs*)(argsptr));

  char newCommit[commitLen+1];
  memcpy(newCommit,args.commit,commitLen);
  newCommit[commitLen+1]='\0';

  unsigned char hash[SHA_DIGEST_LENGTH];

  int da, dc;
  int max = spiral_max(3600);
  for(int n=args.start; n < max; n=n+args.skip) {
    if (count++ % 5000 == 0) {
      printf("khash: %d\r", count/1000);
    }
    if (found) { return NULL; }

    spiral_pair(n, &da, &dc);
    alter(newCommit, authOffset, authDate+da, commOffset, commDate+dc);

    SHA1(newCommit, commitLen, hash);

    if (shacmp(message, hash)) {
      found = true;
      ammend_commit(newCommit, hash, da, dc);

    }
  }
  return NULL;
}

int main(int argc, char *argv[]) {
  for(int i = 0; i < MAX_MESSAGE; i++) { message[i] = '\0'; }
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


  char * commit = getCommit();
  char * commitMsg = commit;
  //advance commit past header
  for (; *commitMsg != '\0'; commitMsg++) { }
  commitMsg++;
  headerLen = commitMsg - commit;
  commitLen = strlen(commit) + 1 + strlen(commitMsg);


  authOffset = getTimeOffset("\nauthor ",   commit);
  commOffset = getTimeOffset("\ncommitter ",commit);
  authDate = dateAtOffset(authOffset, commit);
  commDate = dateAtOffset(commOffset, commit);

 // printf("a: %d, o: %d, ad: %d, od: %d\n", authOffset, commOffset, authDate, commDate);
 // printf("args: %d, message: %s, dry: %d \n", argc, message, dry_run);
  printf("searching for: %s\n", message);

  pthread_t threads[MAX_THREADS];
  searchArgs thread_args[MAX_THREADS];
  for(int i=0; i<MAX_THREADS; i++) {
    searchArgs args = { i+1,MAX_THREADS, commit};
    thread_args[i] = args;
    pthread_create(&threads[i], NULL, Search, (void *) &thread_args[i]);
  }
  for(int i=0; i<MAX_THREADS; i++) {
    pthread_join(threads[i], NULL);
  }

  return 0;
}

