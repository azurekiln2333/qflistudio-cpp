#include <answer.h>
#include <stdint.h>
#include <stdio.h>

int main(void) {
    const int32_t value = answer();
    printf("%d\n", (int)value);
    return value == 42 ? 0 : 1;
}
