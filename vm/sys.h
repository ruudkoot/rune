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
#include <stdio.h>

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

/* Files and directories. A function that returns int gives 0 or -1. */
int sys_mkdir(const char *path);
int sys_rmdir(const char *path);
int sys_chdir(const char *path);
const char *sys_getcwd(void);                 /* NULL on failure */
int sys_remove(const char *path);
int sys_rename(const char *from, const char *to);
int sys_access(const char *path, int read, int write, int exec);   /* 1, 0, or -1 */
/* The kind of a file: 0 regular, 1 directory, 2 symbolic link, 3 other;
   -1 on failure. sys_file_kind follows links, sys_link_kind does not. */
int sys_file_kind(const char *path);
int sys_link_kind(const char *path);
int64_t sys_file_size(const char *path);      /* -1 on failure */
int64_t sys_mod_time(const char *path);       /* seconds since the epoch, -1 on failure */
int sys_set_time(const char *path, int64_t seconds, int now);
const char *sys_read_link(const char *path);  /* NULL on failure */
const char *sys_real_path(const char *path);  /* NULL on failure */
const char *sys_tmp_name(void);               /* NULL on failure */
/* The device and inode of a file, which identify it. */
int sys_file_id(const char *path, int64_t *device, int64_t *inode);

/* Directories. A stream is an int; -1 means the call failed. */
int sys_open_dir(const char *path);
const char *sys_read_dir(int dir);            /* NULL at the end and on failure */
int sys_rewind_dir(int dir);
int sys_close_dir(int dir);

/* I/O descriptors. The descriptor of an open file, which is what the two
   calls below take; -1 when there is none. */
int sys_fileno(FILE *file);
/* The kind of a descriptor: 0 file, 1 directory, 2 symbolic link,
   3 terminal, 4 pipe, 5 socket, 6 device; -1 on failure. */
int sys_desc_kind(int fd);
/* Wait until one of n descriptors is ready, for at most `microseconds` (a
   negative time waits without a limit). fds[] holds the descriptors and
   events[] their events, as bits: 1 read, 2 write, 4 urgent. On return
   events[] holds what happened. The number of ready descriptors, or -1. */
int sys_poll(const int *fds, int *events, int n, int64_t microseconds);

/* Processes. */
int sys_system(const char *command);            /* the exit status, or -1 */
const char *sys_getenv(const char *name);       /* NULL when it is not set */

#endif
