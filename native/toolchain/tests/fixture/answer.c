#include <answer.h>
#include <stdlib.h>

int answer(void) {
    int *value = malloc(sizeof(*value));
    if (value == NULL) return -1;
    *value = 42;
    const int result = *value;
    free(value);
    return result;
}
