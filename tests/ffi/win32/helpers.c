/* Independent original-SDK oracle for Win32Values. */
#include <Windows.h>
#include <windowsx.h>
#include <stdint.h>
#define CHECK(value) do { if (!(value)) return __LINE__; } while (0)
int main(void) {
    uint64_t bits = UINT64_C(0xfedcba9876543210);
    CHECK(LOWORD(0) == 0);
    CHECK(LOWORD(UINT64_MAX) == 0xffff);
    CHECK(LOWORD(bits) == 0x3210);
    CHECK(HIWORD(bits) == 0x7654);
    CHECK(RGB(0x12,0x34,0x56) == 0x563412);
    CHECK(RGB(0x112,0x134,0x156) == 0x563412);
    CHECK(RGB(0,0,0) == 0);
    CHECK(RGB(255,255,255) == 0xffffff);
    CHECK(GetRValue(0xfedcba98) == 0x98);
    CHECK(GetGValue(0xfedcba98) == 0xba);
    CHECK(GetBValue(0xfedcba98) == 0xdc);
    CHECK(GET_X_LPARAM((LPARAM)32768) == -32768);
    CHECK(GET_X_LPARAM((LPARAM)-1) == -1);
    CHECK(GET_X_LPARAM((LPARAM)32767) == 32767);
    CHECK(GET_Y_LPARAM((LPARAM)UINT64_C(2147483648)) == -32768);
    CHECK(GET_Y_LPARAM((LPARAM)UINT64_C(4294934528)) == -1);
    CHECK(GET_Y_LPARAM((LPARAM)UINT64_C(2147418112)) == 32767);
    return 0;
}
