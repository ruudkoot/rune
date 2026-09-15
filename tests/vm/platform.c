/* Check the target actually executing the portability suite. */
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if !defined(RUNE_EXPECT_POINTER_BITS) || !defined(RUNE_EXPECT_BIG_ENDIAN)
#error "Specify the expected pointer width and byte order"
#endif

int main(void) {
    const uint32_t value = UINT32_C(0x01020304);
    const unsigned char big[] = {1, 2, 3, 4}, little[] = {4, 3, 2, 1};
    const unsigned char *expected = RUNE_EXPECT_BIG_ENDIAN ? big : little;
    if (CHAR_BIT != 8 || sizeof(void *) * CHAR_BIT != RUNE_EXPECT_POINTER_BITS ||
        sizeof(value) != 4 || memcmp(&value, expected, sizeof(value))) {
        fputs("portability: unexpected pointer width or byte order\n", stderr);
        return 1;
    }
    printf("pointer bits: %u; byte order: %s\n", (unsigned)(sizeof(void *) * CHAR_BIT),
           RUNE_EXPECT_BIG_ENDIAN ? "big" : "little");
    return 0;
}
