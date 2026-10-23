/* A real dlclose oracle: these registrations and borrowed context remain
   live until the provider destructor, not merely until its last call. */
#include <stdlib.h>
typedef int (*Callback)(int *, int);
static Callback callback;
static int *context, *observed;
static int expect_exit;
void rf_shutdown_observe(int *output, Callback *escaped) {
    observed = output;
    *escaped = callback;
}
void rf_shutdown_register(Callback function, int *state) {
    callback = function; context = state;
}
int rf_shutdown_apply(void) { return callback(context, 77); }
void rf_shutdown_expect_exit(void) { expect_exit = 1; }
__attribute__((destructor)) static void unload(void) {
    if (expect_exit && (callback(context,129) != 0 || callback(context,1) != -1 ||
                        callback(context,42) != -77 || *context != 1234)) _Exit(91);
    if (!observed) return;
    observed[0] = callback(context, 129);
    observed[1] = callback(context, 1);
    observed[2] = callback(context, 42);
    observed[3] = *context;
}
