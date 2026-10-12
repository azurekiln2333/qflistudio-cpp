#include <stdio.h>

int main(void) {
    int value;
    if (scanf("%d", &value) != 1) return 2;
    printf("input=%d\n", value * 2);
    fprintf(stderr, "input accepted\n");
    return 0;
}
