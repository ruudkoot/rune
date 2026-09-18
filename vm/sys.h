/* The system layer: what the primitives need from the operating system.
   The core VM is ISO C99; everything that is not lives behind this header,
   in sys_posix.c or, where POSIX is not available, in sys_none.c
   (`make vm SYS=none`), which fails every call with ENOSYS.

   A function that can fail returns a negative value, or NULL, and leaves the
   reason in sys_errno(). The strings a function returns belong to the layer
   and are valid until the next call of the same function. */
#ifndef RUNE_SYS_H
#define RUNE_SYS_H

#include <stdint.h>
#include <stddef.h>

/* The last failure, as an errno value, and its text and name. */
int sys_errno(void);
void sys_set_errno(int e);
const char *sys_error_msg(int e);
const char *sys_error_name(int e);      /* "ENOENT"; "" when it has no name here */
int sys_error_of_name(const char *name); /* the number, or -1 */

/* Time. Wall clock and processor time in microseconds. */
int64_t sys_time_now(void);
int64_t sys_time_user(void);
int64_t sys_time_sys(void);
void sys_time_sleep(int64_t microseconds);

/* Broken-down time. parts[] is
   [second, minute, hour, day of month, month (0-11), year - 1900,
    day of week (0-6), day of year (0-365), daylight saving (-1, 0, 1)].
   sys_date_parts fills it from a time; sys_date_seconds does the reverse and
   normalises parts[] on the way. Both return -1 on failure. */
int sys_date_parts(int64_t seconds, int local, int32_t parts[9]);
int64_t sys_date_seconds(int32_t parts[9], int local);
/* The offset of the local time zone from UTC in seconds, east of Greenwich. */
int sys_date_offset(int64_t seconds, int32_t *offset);
/* strftime; returns the length written, or -1. */
int sys_date_format(const char *format, const int32_t parts[9], int local, char *out, size_t n);

/* Processes. */
int sys_system(const char *command);            /* the exit status, or -1 */
const char *sys_getenv(const char *name);       /* NULL when it is not set */

#endif
