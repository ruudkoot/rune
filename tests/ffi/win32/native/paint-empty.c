/* Independent original-SDK oracle: a WM_PAINT message need not carry a
   nonempty update region. Never infer positive paint area from visibility. */
#include <Windows.h>
static int expect_empty, observed, failed;
static LRESULT CALLBACK procedure(HWND window, UINT message, WPARAM w, LPARAM l) {
    if (message == WM_PAINT) {
        PAINTSTRUCT paint;
        HDC dc = BeginPaint(window,&paint);
        if (!dc) failed = 1;
        if (expect_empty) {
            observed++;
            if (paint.rcPaint.right > paint.rcPaint.left && paint.rcPaint.bottom > paint.rcPaint.top) failed = 2;
        }
        if (dc && !EndPaint(window,&paint)) failed = 3;
        return 0;
    }
    return DefWindowProcW(window,message,w,l);
}
int main(void) {
    WNDCLASSEXW klass = {0};
    klass.cbSize = sizeof klass;
    klass.lpfnWndProc = procedure;
    klass.hInstance = GetModuleHandleW(NULL);
    klass.lpszClassName = L"Runeffi.Native.EmptyPaintOracle";
    if (!RegisterClassExW(&klass)) return 4;
    HWND window = CreateWindowExW(0,klass.lpszClassName,L"Runeffi native paint oracle",WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,CW_USEDEFAULT,160,120,NULL,NULL,klass.hInstance,NULL);
    if (!window) return 5;
    ShowWindow(window,SW_SHOWNA);
    UpdateWindow(window);
    if (!ValidateRect(window,NULL)) return 6;
    expect_empty = 1;
    SendMessageW(window,WM_PAINT,0,0);
    expect_empty = 0;
    if (!DestroyWindow(window) || !UnregisterClassW(klass.lpszClassName,klass.hInstance)) return 7;
    return observed == 1 ? failed : 8;
}
