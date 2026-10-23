/* Independent IEEE conversions under the delivery nearest/even contract. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
static void narrow(uint64_t bits) {
    double input; float output; uint32_t result;
    memcpy(&input, &bits, sizeof input);
    output = (float)input;
    memcpy(&result, &output, sizeof result);
    if (isnan(output)) result = (result & UINT32_C(0x80000000)) | UINT32_C(0x7fc00000);
    printf("narrow|%llu|%lu\n", (unsigned long long)bits, (unsigned long)result);
}
static void widen(uint32_t bits) {
    float input; double output; uint64_t result;
    memcpy(&input, &bits, sizeof input);
    if (isnan(input)) return; /* C may quiet a signalling NaN on conversion. */
    output = (double)input;
    memcpy(&result, &output, sizeof result);
    printf("widen|%lu|%llu\n", (unsigned long)bits, (unsigned long long)result);
}
int main(void) {
    static const uint64_t edges[] = {
        UINT64_C(0), UINT64_C(0x8000000000000000), UINT64_C(0x3ff0000000000000),
        UINT64_C(0x3ff0000010000000), UINT64_C(0x3ff0000030000000),
        UINT64_C(0x3690000000000000), UINT64_C(0x3690000000000001),
        UINT64_C(0x36a0000000000000), UINT64_C(0x380fffffe0000000),
        UINT64_C(0x3810000000000000), UINT64_C(0x47efffffe0000000),
        UINT64_C(0x47effffff0000000), UINT64_C(0x47f0000000000000),
        UINT64_C(0x7ff0000000000000), UINT64_C(0xfff0000000000000),
        UINT64_C(0x7ff8000000000001), UINT64_C(0xfff8000000000001), UINT64_C(1)
    };
    for (unsigned i=0; i<sizeof edges/sizeof *edges; i++) narrow(edges[i]);
    uint64_t state = UINT64_C(0x6a09e667f3bcc909);
    for (unsigned i=0;i<512;i++) {
        state = state * UINT64_C(6364136223846793005) + UINT64_C(1442695040888963407);
        narrow(state); widen((uint32_t)(state >> 32));
    }
    return 0;
}
