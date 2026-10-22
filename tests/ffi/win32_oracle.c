/* Win32's own messages, not an emulator, establish the creation/reentry
   contract used by the SML/native/SDL/mock implementations. No window is shown. */
#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>

static int failed, created, destroyed, nested, depth;
static HWND active;
#define CHECK(label, condition) do { if (!(condition)) { \
    fprintf(stderr, "FAIL ffi/win32/%s at %d: %lu\n", label, __LINE__, (unsigned long)GetLastError()); failed = 1; } } while (0)
static LRESULT CALLBACK procedure(HWND window, UINT message, WPARAM w, LPARAM l) {
    switch (message) {
    case WM_NCCREATE:
        CHECK("nccreate-before-return", !created && !active);
        return TRUE;
    case WM_CREATE:
        CHECK("create-before-return", !created && !active);
        created++;
        return 0;
    case WM_APP + 1:
        depth++;
        CHECK("outer-send-depth", depth == 1);
        CHECK("nested-send-result", SendMessageW(window, WM_APP + 2, w, l) == 42);
        depth--;
        return 42;
    case WM_APP + 2:
        depth++;
        CHECK("nested-send-depth", depth == 2);
        nested++;
        depth--;
        return (LRESULT)(w + (WPARAM)l);
    case WM_DESTROY: destroyed++; return 0;
    default: return DefWindowProcW(window, message, w, l);
    }
}
int main(void) {
    HINSTANCE module = GetModuleHandleW(NULL);
    WNDCLASSEXW cls = {0};
    cls.cbSize = sizeof cls;
    cls.lpfnWndProc = procedure;
    cls.hInstance = module;
    cls.lpszClassName = L"RuneffiContractOracle";
    ATOM atom = RegisterClassExW(&cls);
    CHECK("register", atom != 0);
    if (!atom) return 1;
    active = CreateWindowExW(0, cls.lpszClassName, L"Runeffi \x03bb \xd83d\xde00", WS_OVERLAPPEDWINDOW,
                            0, 0, 320, 200, NULL, NULL, module, NULL);
    CHECK("create", active && created == 1);
    if (active) {
        CHECK("send", SendMessageW(active, WM_APP + 1, 19, 23) == 42 && nested == 1 && depth == 0);
        RECT rect;
        CHECK("client-rect", GetClientRect(active, &rect) && rect.right > 0 && rect.bottom > 0);
        UINT_PTR timer = SetTimer(active, 7, 1000, NULL);
        CHECK("timer", timer != 0 && KillTimer(active, timer));
        HBRUSH brush = CreateSolidBrush(RGB(1, 2, 3));
        CHECK("brush", brush && DeleteObject(brush));
        CHECK("stock-borrowed", GetStockObject(BLACK_BRUSH) != NULL);
        CHECK("destroy", DestroyWindow(active) && destroyed == 1);
        active = NULL;
    }
    CHECK("unregister", UnregisterClassW(cls.lpszClassName, module));
    if (!failed) printf("PASS ffi/win32: creation, nested sends, resources, timer, destruction (%zu-bit)\n", sizeof(void *) * 8);
    return failed;
}
