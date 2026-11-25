#include <stdio.h>
#include <stdlib.h>

int main(void) {
  void *large = malloc(300u * 1024u * 1024u);
  if (large) {
    free(large);
    return 1;
  }
  puts("memory bounded");
  return 0;
}
