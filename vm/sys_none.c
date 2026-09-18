/* The system layer where there is no POSIX (`make vm SYS=none`): every call
   fails with ENOSYS, which the library turns into OS.SysErr. */
#include "sys.h"

#include <errno.h>
#include <string.h>
#include <time.h>

static int last = 0;
static int fail(void) { last = ENOSYS; return -1; }

int sys_errno(void) { return last; }
void sys_set_errno(int e) { last = e; }
const char *sys_error_msg(int e) { return strerror(e); }
const char *sys_error_name(int e) { return e == ENOSYS ? "ENOSYS" : ""; }
int sys_error_of_name(const char *name) { return strcmp(name, "ENOSYS") == 0 ? ENOSYS : -1; }

/* time() is ISO C, so the clock works even here; the rest does not. */
int64_t sys_time_now(void) { return (int64_t)time(NULL) * 1000000; }
int64_t sys_time_user(void) { return (int64_t)clock() * 1000000 / CLOCKS_PER_SEC; }
int64_t sys_time_sys(void) { return 0; }
void sys_time_sleep(int64_t microseconds) { (void)microseconds; }

int sys_date_parts(int64_t seconds, int local, int32_t parts[9]) {
    time_t t = (time_t)seconds;
    struct tm *tm = local ? localtime(&t) : gmtime(&t);
    if (tm == NULL) return -1;
    parts[0] = tm->tm_sec;  parts[1] = tm->tm_min;   parts[2] = tm->tm_hour;
    parts[3] = tm->tm_mday; parts[4] = tm->tm_mon;   parts[5] = tm->tm_year;
    parts[6] = tm->tm_wday; parts[7] = tm->tm_yday;  parts[8] = tm->tm_isdst;
    return 0;
}
int64_t sys_date_seconds(int32_t parts[9], int local) { (void)parts; (void)local; return fail(); }
int sys_date_offset(int64_t seconds, int32_t *offset) { (void)seconds; (void)offset; return fail(); }
int sys_date_format(const char *format, const int32_t parts[9], int local, char *out, size_t n) {
    (void)format; (void)parts; (void)local; (void)n;
    out[0] = 0;
    return fail();
}

int sys_system(const char *command) { (void)command; return fail(); }
const char *sys_getenv(const char *name) { (void)name; return NULL; }
