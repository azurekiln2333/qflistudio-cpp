#include <stdio.h>
#include <string.h>

int main(void) {
  char text[32];
  FILE *input = fopen("data/input.txt", "r");
  if (!input || !fgets(text, sizeof(text), input)) return 1;
  fclose(input);
  FILE *output = fopen("output.txt", "w");
  if (!output) return 2;
  if (fwrite(text, 1, strlen(text), output) != strlen(text)) return 3;
  if (fclose(output)) return 4;
  printf("file=%s", text);
  return 0;
}
