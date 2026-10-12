#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <time.h>

int main(void) {
  long milliseconds = 30000;
  if (scanf("%ld", &milliseconds) != 1) milliseconds = 30000;
  if (milliseconds < 0 || milliseconds > 30000) return 1;
  const struct timespec delay = {
      milliseconds / 1000, (milliseconds % 1000) * 1000000};
  struct timespec before, after;
  if (clock_gettime(CLOCK_MONOTONIC, &before)) return 2;
  puts("ready");
  fflush(stdout);
  if (nanosleep(&delay, NULL)) return 3;
  if (clock_gettime(CLOCK_MONOTONIC, &after)) return 4;
  const int64_t elapsed = (int64_t)(after.tv_sec - before.tv_sec) * 1000000000 +
                          after.tv_nsec - before.tv_nsec;
  if (elapsed < (int64_t)milliseconds * 1000000) return 5;
  puts("slept");
  return 0;
}
