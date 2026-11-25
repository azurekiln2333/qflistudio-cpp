#include <stdio.h>

int main(void) {
    puts("before exit");
    fprintf(stderr, "intentional failure\n");
    return 7;
}
