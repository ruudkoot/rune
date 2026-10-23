/* Independent callback ABI and lifecycle subject. No Rune runtime API. */
#include "fixture.h"
#include <stdlib.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <pthread.h>
#endif

RF_EXPORT int rf_cb_apply(rf_callback callback, void *context, int value) {
    return callback(context, value);
}
RF_EXPORT double rf_cb_real(double (*callback)(double), double value) {
    return callback(value);
}
RF_EXPORT int8_t rf_cb_narrow(int8_t (*callback)(int8_t), int8_t value) {
    return callback(value);
}
typedef intptr_t (RF_STDCALL *window_callback)(void *, uint32_t, uintptr_t, intptr_t);
RF_EXPORT intptr_t rf_cb_message(window_callback callback, void *window, uint32_t message) {
    return callback(window, message, 0, 0);
}
typedef struct { rf_callback callback; void *context; int value, result, count; } ThreadCall;
#if defined(_WIN32)
static DWORD WINAPI thread_call(void *opaque) {
    ThreadCall *call = opaque;
    for (int i = 0; i < call->count; i++) call->result += call->callback(call->context, call->value);
    return 0;
}
#else
static void *thread_call(void *opaque) {
    ThreadCall *call = opaque;
    for (int i = 0; i < call->count; i++) call->result += call->callback(call->context, call->value);
    return NULL;
}
#endif
RF_EXPORT int rf_cb_thread(rf_callback callback, void *context, int value) {
    ThreadCall call = {callback, context, value, 0, 1};
#if defined(_WIN32)
    HANDLE thread = CreateThread(NULL, 0, thread_call, &call, 0, NULL);
    if (!thread) return -999;
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
#else
    pthread_t thread;
    if (pthread_create(&thread, NULL, thread_call, &call)) return -999;
    if (pthread_join(thread, NULL)) return -999;
#endif
    return call.result;
}
RF_EXPORT int rf_cb_threads(rf_callback callback, void *context, int value) {
    ThreadCall calls[4];
#if defined(_WIN32)
    HANDLE threads[4];
#else
    pthread_t threads[4];
#endif
    int started = 0, result = 0;
    for (int i = 0; i < 4; i++) {
        calls[i] = (ThreadCall){callback, context, value, 0, 64};
#if defined(_WIN32)
        threads[i] = CreateThread(NULL, 0, thread_call, &calls[i], 0, NULL);
        if (!threads[i]) break;
#else
        if (pthread_create(&threads[i], NULL, thread_call, &calls[i])) break;
#endif
        started++;
    }
    for (int i = 0; i < started; i++) {
#if defined(_WIN32)
        WaitForSingleObject(threads[i], INFINITE); CloseHandle(threads[i]);
#else
        if (pthread_join(threads[i], NULL)) return -999;
#endif
        result += calls[i].result;
    }
    return started == 4 ? result : -999;
}
static ThreadCall remembered;
RF_EXPORT int rf_cb_remember(rf_callback callback, void *context, int value) {
    remembered = (ThreadCall){callback, context, value, 0, 1}; return 0;
}
/* A direct C oracle calls this outside the generic native-call delimiter. */
RF_EXPORT int rf_cb_outside(void) { return remembered.callback(remembered.context, remembered.value); }
/* Calls back with a handle before returning that same native pointer. */
RF_EXPORT void *rf_cb_create(rf_callback callback) {
    void *handle = malloc(1);
    if (!handle) return NULL;
    if (!callback(handle, 129)) { free(handle); return NULL; }
    return handle;
}
RF_EXPORT void rf_cb_destroy(void *handle) { free(handle); }

RF_EXPORT void rf_cb_destroy_notify(void *handle, rf_callback callback) {
    (void)callback(handle, 2);
    free(handle);
}
RF_EXPORT int rf_cb_handle_use(void *handle) { return handle != NULL; }

RF_EXPORT int rf_cb_twice(rf_callback callback, void *context) {
    int first = callback(context, 1);
    int second = callback(context, 129);
    return first * 100 + second;
}
RF_EXPORT void *rf_cb_owned(rf_callback callback, void *context) {
    char *result = rf_copy("owned-result");
    (void)callback(context, 7);
    return result;
}
RF_EXPORT void *rf_cb_pointer(rf_callback callback, void *context) {
    (void)callback(context, 7);
    return context;
}

RF_EXPORT void *rf_cb_pointer_result(void *(*callback)(void *), void *context) {
    return callback(context);
}
