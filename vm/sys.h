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

/* The named constants of POSIX: errno values, signals, the flags of open,
   the bits of a file mode, and the rest. -1 when the name is not known. */
int64_t sys_const(const char *name);

/* Processes and their environment. A call that fails gives -1. */
int sys_fork(void);
int sys_exec(const char *path, char *const argv[], char *const envp[], int search);
/* Wait for a child: out[] gets the process, then 0 exited, 1 signalled or
   2 stopped, then the status or the signal. */
int sys_waitpid(int64_t pid, int flags, int64_t out[3]);
int sys_kill(int64_t pid, int signal);
int sys_alarm(int seconds);
int sys_pause(void);
int64_t sys_getpid(void);
int64_t sys_getppid(void);
int64_t sys_getuid(void);
int64_t sys_geteuid(void);
int64_t sys_getgid(void);
int64_t sys_getegid(void);
int sys_setuid(int64_t uid);
int sys_setgid(int64_t gid);
int sys_getgroups(int64_t *out, int n);        /* how many, or -1 */
const char *sys_getlogin(void);
int64_t sys_getpgrp(void);
int64_t sys_setsid(void);
int sys_setpgid(int64_t pid, int64_t pgid);
/* The five strings of uname, each NUL-terminated, one after another. */
const char *sys_uname(void);
int sys_times(int64_t out[5]);                 /* elapsed, user, system, child user, child system */
const char *sys_environ(void);                 /* the variables, each NUL-terminated, then an empty one */
const char *sys_ctermid(void);
const char *sys_ttyname(int fd);
int sys_isatty(int fd);
int64_t sys_sysconf(const char *name);

/* Descriptors, as the numbers the system gives them rather than the handles
   of the VM's table. A call that fails gives -1. */
int sys_openf(const char *path, int flags, int mode);
int sys_close_fd(int fd);
int sys_dup(int fd);
int sys_dup2(int fd, int to);
int sys_pipe(int out[2]);
/* Read into buf, or write from it; the number of bytes, or -1. */
int64_t sys_read_fd(int fd, char *buf, int64_t n);
int64_t sys_write_fd(int fd, const char *buf, int64_t n);
int64_t sys_lseek_fd(int fd, int64_t offset, int whence);
int sys_fsync(int fd);
int sys_fcntl(int fd, int command, int argument);
int sys_ftruncate(int fd, int64_t length);
/* The fields of stat: kind, mode, inode, device, links, user, group, size,
   access time, modification time, change time. */
int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]);
int sys_chmod(const char *path, int fd, int mode);
int sys_chown(const char *path, int fd, int64_t uid, int64_t gid);
int sys_link(const char *from, const char *to);
int sys_symlink(const char *from, const char *to);
int sys_mkfifo(const char *path, int mode);
int sys_umask(int mask);
/* The fields of a user: name, password, home, shell, then the ids in out[].
   The names come back one after another, as for uname. */
const char *sys_getpw(const char *name, int64_t uid, int64_t out[2]);
const char *sys_getgr(const char *name, int64_t gid, int64_t *id);
const char *sys_group_members(void);

/* Processes. */
int sys_system(const char *command);            /* the exit status, or -1 */
const char *sys_getenv(const char *name);       /* NULL when it is not set */

#endif
