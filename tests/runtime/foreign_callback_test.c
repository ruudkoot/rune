#include "foreign.h"
#include "sys/sys.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

static unsigned checks, entries, frees;
static long remaining = -1;
void *__real_calloc(size_t, size_t);
void *__wrap_calloc(size_t n, size_t size) {
    if (!remaining) { errno = ENOMEM; return NULL; }
    if (remaining > 0) remaining--;
    return __real_calloc(n, size);
}
#define CHECK(test) do { checks++; if (!(test)) { fprintf(stderr,"FAIL callback runtime at %d\n",__LINE__); return 1; } } while (0)
static int echo(void *state, const ForeignValue *args, size_t n, ForeignValue *result) {
    (void)state;
    entries++;
    if (n != 2 || args[0].type != FOREIGN_POINTER || args[1].type != FOREIGN_I32) return -1;
    result->type = FOREIGN_I32; result->value.integer = args[1].value.integer + 1;
    return 0;
}
static void release(void *state) { (void)state; frees++; }
typedef struct { Foreign *foreign; ForeignId callback; int status, number; } Query;
static void *wrong_query(void *opaque) {
    Query *q=opaque; uint64_t count; ForeignCallbackFault first;
    q->status=foreign_callback_status(q->foreign,q->callback,1,&count,&first);
    q->number=errno; return NULL;
}
static ForeignId prepare(Foreign *f, ForeignId library, const char *name) {
    ForeignId symbol = foreign_symbol(f, library, name, strlen(name));
    ForeignType args[] = {FOREIGN_POINTER, FOREIGN_POINTER, FOREIGN_I32};
    return symbol ? foreign_prepare(f, symbol, 0, FOREIGN_I32, args, 3) : 0;
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    ForeignSystem system = {sys_library_open,sys_library_symbol,sys_library_close,sys_library_error,sys_foreign_capture};
    Foreign *f = foreign_create(&system);
    CHECK(f != NULL);
    ForeignId library = foreign_library(f, argv[1], strlen(argv[1]));
    CHECK(library != 0);
    ForeignId apply = prepare(f,library,"rf_cb_apply"), thread = prepare(f,library,"rf_cb_thread");
    CHECK(apply && thread);
    ForeignType types[] = {FOREIGN_POINTER, FOREIGN_I32};
    ForeignValue failure = {FOREIGN_I32,{.integer=-77}};
    ForeignCallbackFailure cases[] = {{1,129,{FOREIGN_I32,{.integer=0}}},{1,1,{FOREIGN_I32,{.integer=-1}}}};
    size_t live = foreign_live(f);
    for (long i = 0; i < 4; i++) {
        remaining = i;
        ForeignId failed = foreign_callback(f,0,FOREIGN_I32,types,2,failure,cases,2,echo,release,NULL);
        remaining = -1;
        CHECK(failed == 0 && foreign_error(f)->error_number == ENOMEM && foreign_live(f) == live && frees == 0);
    }
    ForeignId callback = foreign_callback(f,0,FOREIGN_I32,types,2,failure,cases,2,echo,release,NULL);
    CHECK(callback != 0);
    uint64_t rejected; ForeignCallbackFault first;
    CHECK(foreign_callback_status(f,callback,0,&rejected,&first)==0 && !rejected && first==FOREIGN_CALLBACK_NONE);
    ForeignValue args[] = {{FOREIGN_POINTER,{.pointer=callback}},{FOREIGN_POINTER,{.pointer=0}},{FOREIGN_I32,{.integer=41}}};
    ForeignValue result; ForeignError captured;
    CHECK(foreign_call(f,apply,args,3,&result,&captured) == 0 && result.value.integer == 42 && entries == 1);
    args[2].value.integer = 129;
    CHECK(foreign_call(f,thread,args,3,&result,&captured) == 0 && result.value.integer == 0 && entries == 1);
    args[2].value.integer = 1;
    CHECK(foreign_call(f,thread,args,3,&result,&captured) == 0 && result.value.integer == -1 && entries == 1);
    args[2].value.integer = 5;
    CHECK(foreign_call(f,thread,args,3,&result,&captured) == 0 && result.value.integer == -77 && entries == 1);
    CHECK(foreign_callback_status(f,callback,0,&rejected,&first)==0 && rejected==3 && first==FOREIGN_CALLBACK_WRONG_THREAD);
    CHECK(foreign_callback_status(f,callback,1,&rejected,&first)==0 && rejected==3 && first==FOREIGN_CALLBACK_WRONG_THREAD);
    CHECK(foreign_callback_status(f,callback,0,&rejected,&first)==0 && !rejected && first==FOREIGN_CALLBACK_NONE);
    ForeignId parallel=prepare(f,library,"rf_cb_threads");
    CHECK(parallel && foreign_call(f,parallel,args,3,&result,&captured)==0 && result.value.integer==-19712 && entries==1);
    CHECK(foreign_callback_status(f,callback,1,&rejected,&first)==0 && rejected==256 && first==FOREIGN_CALLBACK_WRONG_THREAD);
    ForeignError previous=*foreign_error(f);
    Query query={f,callback,0,0}; pthread_t query_thread;
    CHECK(pthread_create(&query_thread,NULL,wrong_query,&query)==0 && pthread_join(query_thread,NULL)==0);
    CHECK(query.status==-1 && query.number==EPERM && memcmp(&previous,foreign_error(f),sizeof previous)==0);
    ForeignId remember=prepare(f,library,"rf_cb_remember");
    CHECK(remember && foreign_call(f,remember,args,3,&result,&captured)==0);
    void *native=system.open(argv[1],strlen(argv[1]));
    CHECK(native!=NULL);
    void *address=system.symbol(native,"rf_cb_outside",13); int (*outside)(void)=NULL;
    CHECK(address!=NULL && sizeof outside==sizeof address);
    memcpy(&outside,&address,sizeof outside);
    CHECK(outside()==-77 && entries==1);
    CHECK(foreign_callback_status(f,callback,1,&rejected,&first)==0 && rejected==1 && first==FOREIGN_CALLBACK_NO_ACTIVATION);
    CHECK(system.close(native)==0);
    CHECK(foreign_callback_status(f,apply,0,&rejected,&first)!=0);
    CHECK(foreign_release(f,callback) == 0 && frees == 1);
    CHECK(foreign_callback_status(f,callback,0,&rejected,&first)!=0);
    CHECK(foreign_release(f,callback) != 0 && frees == 1);
    failure.value.integer = 128;
    failure.type = FOREIGN_I8;
    CHECK(foreign_callback(f,0,FOREIGN_I8,types,2,failure,NULL,0,echo,release,NULL) == 0 && foreign_error(f)->error_number == ERANGE);
    foreign_destroy(f);
    printf("PASS foreign callbacks C: %u allocation, ownership and native-thread checks\n",checks);
    return 0;
}
