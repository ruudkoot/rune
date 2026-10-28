/* A moving allocator with one failed call, shared by the encoder tests.
   Track ownership independently of the system allocator and sanitizers. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { void *pointer; size_t size; } Allocation;
static Allocation allocations[128];
static int calls, fail_at, bad_free;

static void *probe_realloc(void *pointer, size_t size) {
    if (++calls == fail_at) return NULL;
    int old = -1, slot = -1;
    for (int i = 0; i < 128; i++) {
        if (pointer && allocations[i].pointer == pointer) old = i;
        if (!allocations[i].pointer && slot < 0) slot = i;
    }
    if ((pointer && old < 0) || slot < 0) abort();
    void *next = malloc(size);
    if (!next) abort();
    if (pointer) {
        size_t copied = allocations[old].size < size ? allocations[old].size : size;
        memcpy(next, pointer, copied);
        free(pointer);
        allocations[old].pointer = NULL;
    }
    allocations[slot] = (Allocation){next, size};
    return next;
}

static void probe_free(void *pointer) {
    if (!pointer) return;
    for (int i = 0; i < 128; i++)
        if (allocations[i].pointer == pointer) {
            allocations[i].pointer = NULL;
            free(pointer);
            return;
        }
    bad_free++;
}

static void probe_start(int fail) { calls = bad_free = 0; fail_at = fail; }
static int probe_finish(void) {
    int failed = bad_free || (fail_at && calls != fail_at);
    for (int i = 0; i < 128; i++)
        if (allocations[i].pointer) {
            free(allocations[i].pointer);
            allocations[i].pointer = NULL;
            failed = 1;
        }
    return failed;
}
