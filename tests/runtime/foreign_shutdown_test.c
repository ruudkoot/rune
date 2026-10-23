#include "foreign.h"
#include "sys/sys.h"
#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static unsigned checks, entries, frees;
static Foreign *context;
static ForeignId memory;
static void *provider;
static int fail_close, refused_active;
typedef int (*Callback)(int *, int);
#define CHECK(test) do { checks++; if (!(test)) { fprintf(stderr,"FAIL shutdown runtime at %d\n",__LINE__); return 1; } } while (0)
static void *open_provider(const char *path, size_t length) {
    provider = sys_library_open(path, length); return provider;
}
static int close_provider(void *library) {
    if (fail_close) { fail_close = 0; errno = EIO; return -1; }
    return sys_library_close(library);
}
static int enter(void *state, const ForeignValue *args, size_t count, ForeignValue *result) {
    (void)state; (void)args; (void)count;
    entries++;
    size_t live = foreign_live(context);
    int value = 0;
    refused_active = foreign_destroy(context) == -1 && foreign_error(context)->error_number == EBUSY &&
        foreign_live(context) == live && foreign_read(context, memory, 0, &value, sizeof value) == 0 && value == 1234;
    result->type = FOREIGN_I32; result->value.integer = 78; return 0;
}
static void release(void *state) { (void)state; frees++; }
static ForeignId prepare(ForeignId library, const char *name, ForeignType result, const ForeignType *args, size_t count) {
    ForeignId symbol = foreign_symbol(context, library, name, strlen(name));
    return symbol ? foreign_prepare(context, symbol, 0, result, args, count) : 0;
}
static void *late_thread(void *state) {
    Callback *callback = state;
    for (unsigned i = 0; i < 10000; i++) if ((*callback)(NULL,129) != 0 || (*callback)(NULL,1) != -1) return (void *)(uintptr_t)1;
    return NULL;
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    ForeignSystem system = {open_provider,sys_library_symbol,close_provider,sys_library_error,sys_foreign_capture};
    context = foreign_create(&system);
    CHECK(context != NULL && foreign_quarantined() == 0);
    ForeignType args[] = {FOREIGN_POINTER, FOREIGN_I32};
    ForeignValue failure = {FOREIGN_I32,{.integer=-77}};
    ForeignCallbackFailure cases[] = {{1,129,{FOREIGN_I32,{.integer=0}}},{1,1,{FOREIGN_I32,{.integer=-1}}}};
    ForeignId explicit = foreign_callback(context,0,FOREIGN_I32,args,2,failure,cases,2,enter,release,NULL);
    CHECK(explicit && foreign_release(context,explicit) == 0 && frees == 1 && foreign_quarantined() == 0);
    ForeignId library = foreign_library(context,argv[1],strlen(argv[1]));
    CHECK(library != 0);
    ForeignId callback = foreign_callback(context,0,FOREIGN_I32,args,2,failure,cases,2,enter,release,NULL);
    CHECK(callback != 0);
    memory = foreign_memory(context,sizeof(int));
    int value = 1234;
    CHECK(memory && foreign_write(context,memory,0,&value,sizeof value) == 0);
    ForeignType pointers[] = {FOREIGN_POINTER,FOREIGN_POINTER};
    ForeignId setup = prepare(library,"rf_shutdown_register",FOREIGN_VOID,pointers,2);
    ForeignId apply = prepare(library,"rf_shutdown_apply",FOREIGN_I32,NULL,0);
    CHECK(setup && apply);
    ForeignValue values[] = {{FOREIGN_POINTER,{.pointer=callback}},{FOREIGN_POINTER,{.pointer=memory}}}, result;
    ForeignError captured;
    CHECK(foreign_call(context,setup,values,2,&result,&captured) == 0);
    int observed[] = {999,999,999,999}; Callback escaped = NULL;
    void (*observe)(int *, Callback *);
    void *symbol = dlsym(provider,"rf_shutdown_observe");
    memcpy(&observe,&symbol,sizeof observe);
    CHECK(observe != NULL);
    observe(observed,&escaped);
    CHECK(escaped != NULL);
    CHECK(foreign_call(context,apply,NULL,0,&result,&captured) == 0 && result.value.integer == 78 && refused_active && entries == 1);
    fail_close = 1;
    CHECK(foreign_destroy(context) == -1 && frees == 1 && observed[0] == 999);
    CHECK(foreign_memory(context,1) == 0 && foreign_error(context)->error_number == EBUSY);
    CHECK(escaped(NULL,129) == 0 && escaped(NULL,1) == -1 && entries == 1);
    CHECK(foreign_destroy(context) == 0);
    CHECK(observed[0] == 0 && observed[1] == -1 && observed[2] == -77 && observed[3] == 1234);
    CHECK(entries == 1 && frees == 2 && foreign_quarantined() == 1);
    CHECK(escaped(NULL,129) == 0 && escaped(NULL,1) == -1 && escaped(NULL,42) == -77);
    pthread_t thread; void *thread_result = NULL;
    CHECK(pthread_create(&thread,NULL,late_thread,&escaped) == 0);
    CHECK(pthread_join(thread,&thread_result) == 0 && thread_result == NULL && entries == 1);
    uint64_t floor = foreign_identity_floor();
    CHECK(foreign_restore_identity_floor(0) == -1 && errno == EINVAL && foreign_identity_floor() == floor);
    CHECK(foreign_restore_identity_floor(1) == 0 && foreign_identity_floor() == floor);
    CHECK(foreign_restore_identity_floor(UINT64_MAX - 1) == 0);
    context = foreign_create(&system);
    CHECK(context && foreign_memory(context,1) == UINT64_MAX - 1 && foreign_identity_floor() == UINT64_MAX);
    CHECK(foreign_memory(context,1) == 0 && foreign_error(context)->error_number == ENOSPC && foreign_identity_floor() == UINT64_MAX);
    CHECK(foreign_destroy(context) == 0);
    printf("PASS foreign shutdown: %u unload, retained-memory, active-close and late-thread checks\n",checks);
    return 0;
}
