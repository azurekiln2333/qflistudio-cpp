#include <math.h>
#include <stdio.h>

int main(void) {
    double value;
    if (scanf("%lf", &value) != 1) return 2;
    const double result = sin(value) + exp(value);
    printf("%.6f\n", result);
    return isfinite(result) ? 0 : 1;
}
