#include <math.h>
#include <stdio.h>

int main(void) {
    double value;
    if (scanf("%lf", &value) != 1) return 2;
    printf("%.6f\n", sqrt(value) + cos(value - value));
    return 0;
}
