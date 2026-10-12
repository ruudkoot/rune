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
/* Clocks for measuring the runtime itself (runevm --gc-log): a monotonic
   clock and the calling thread's processor time, in nanoseconds; 0 where
   the system has none. */
int64_t sys_clock_ns(void);
int64_t sys_thread_time_ns(void);
/* The process's memory in bytes: what is resident now, the most that has
   been resident, and the most address space it has held (Linux's VmPeak,
   Windows's peak commit); 0 for what the system does not say. */
void sys_mem_usage(uint64_t *resident, uint64_t *peak_resident, uint64_t *peak_virtual);

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

/* fopen, for the files the core opens (TextIO and BinIO, the bytecode): a
   system whose paths are not those of the library translates them here.
   NULL on failure, with the reason in errno, as fopen leaves it. */
FILE *sys_fopen(const char *path, const char *mode);

/* I/O descriptors. The descriptor of an open file, which is what the two
   calls below take; -1 when there is none. */
int sys_fileno(FILE *file);
/* The position of an open file in bytes, and moving it, with offsets of 64
   bits even where the C library's long has 32 (Windows). -1 on failure,
   with the reason in errno, as ftell and fseek leave it. */
int64_t sys_ftell(FILE *file);
int sys_fseek(FILE *file, int64_t offset, int whence);
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
/* fork where the system has none (Windows), or where runevm is given
   --emulate-fork: a second VM is started as `runevm --resume TOKEN` and
   handed this one's state (runtime/image.c). sys_has_fork says whether sys_fork
   is the system's own. sys_fork_start starts the child, gives it the
   descriptors and sockets and writes it this layer's own state (directory
   streams, close-on-exec), and returns the stream the core writes its
   image to, or NULL; sys_fork_finish closes that stream and returns the
   child's process, or -1. In the child, sys_resume takes the TOKEN,
   rebuilds this layer's state and returns the stream the core's image is
   read from, or NULL. sys_fdopen is fdopen, for the files of the core that
   the child opens again on the same descriptors. */
int sys_has_fork(void);
FILE *sys_fork_start(void);
int64_t sys_fork_finish(FILE *image);
FILE *sys_resume(const char *token);
FILE *sys_fdopen(int fd, const char *mode);
int sys_exec(const char *path, char *const argv[], char *const envp[], int search);
/* Wait for a child: out[] gets the process, then 0 exited, 1 signalled or
   2 stopped, then the status or the signal. */
int sys_waitpid(int64_t pid, int flags, int64_t out[3]);
/* Start a program as fork, dup2 and exec would, without the fork, which not
   every system has: fds[] are the descriptors that become its standard
   input, output and error (-1: this process's own), and search looks for
   the program on PATH. The process, or -1. A program that cannot be run is
   a child that exits with 126 where the child is forked first (POSIX), and
   -1 where the system knows at once (Windows). */
int64_t sys_spawn(const char *path, char *const argv[], char *const envp[], int search, const int fds[3]);
int sys_kill(int64_t pid, int signal);
/* What a test runner needs of its children (docs/plans/unit-testing.md,
   M2): sys_spawn with a directory to start in (NULL: this process's), a
   process group of its own (POSIX) or a job (Windows) when group is 1, the
   signals at their default actions when defaults is 1, and limits[] -- the
   bytes of address space, the seconds of processor time, the bytes of a
   file written and of a core dump, -1 leaving one as it is. Windows has a
   job's limits of memory and processor time and no others. */
int64_t sys_spawn_with(const char *path, char *const argv[], char *const envp[], int search, const int fds[3],
                       const char *dir, int group, int defaults, const int64_t limits[4]);
/* sys_waitpid (flags: bit 0 does not wait, and says 0 when nothing ended)
   that also says what the child cost: out[3] and out[4] its user and
   system processor time in microseconds, out[5] the most memory it held
   resident, in kilobytes (0 where the system does not say). */
int sys_wait_usage(int64_t pid, int flags, int64_t out[6]);
/* A signal to the child's process group (POSIX), or the end of its job
   (Windows, for a child sys_spawn_with started in a group; otherwise
   sys_kill). */
int sys_kill_group(int64_t pid, int signal);
/* The processors this process may run on: at least 1. */
int sys_processors(void);
int sys_alarm(int seconds);
int sys_pause(void);
/* End the process at once with the status, flushing nothing and running
   nothing registered to run at exit (Posix.Process.exit). */
void sys_exit_now(int status);
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
int sys_lock(int fd, int command, int type, int whence, int64_t start, int64_t length, int64_t out[5]);
int sys_pathconf(const char *path, int fd, const char *name, int64_t *out);
int sys_utime(const char *path, int64_t access, int64_t modification);
/* the terminal: sys_nccs () control characters; the arrays hold 6 + that */
int sys_nccs(void);
int sys_tcgetattr(int fd, int64_t *out);
int sys_tcsetattr(int fd, int action, const int64_t *in);
int64_t sys_tcop(int op, int fd, int64_t argument);
/* sockets: SO_LINGER, FIONREAD and sockatmark */
int sys_linger(int fd, int set, int *seconds);
int sys_socket_query(int fd, int what);
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

/* Sockets. An address is the bytes of a sockaddr, which the library keeps
   as a string; a call that fails gives -1. */
int sys_socket(int domain, int type, int protocol);
int sys_socketpair(int domain, int type, int protocol, int out[2]);
int sys_bind(int fd, const char *addr, int n);
int sys_connect(int fd, const char *addr, int n);
int sys_listen(int fd, int backlog);
int sys_accept(int fd);
int64_t sys_send(int fd, const char *buf, int64_t n, int flags);
int64_t sys_sendto(int fd, const char *buf, int64_t n, int flags, const char *addr, int addrlen);
int64_t sys_recv(int fd, char *buf, int64_t n, int flags);
/* recvfrom leaves the address in sys_last_addr, of sys_last_addr_len bytes. */
int64_t sys_recvfrom(int fd, char *buf, int64_t n, int flags);
int sys_shutdown(int fd, int how);
/* getsockname and getpeername, likewise. */
int sys_sock_name(int fd);
int sys_sock_peer(int fd);
const char *sys_last_addr(void);
int sys_last_addr_len(void);
int sys_getsockopt(int fd, int level, int name);
int sys_setsockopt(int fd, int level, int name, int value);
/* Building and taking apart the addresses. */
int sys_inet_addr(const char *host, int port);      /* into sys_last_addr */
int sys_inet6_addr(const char *host, int port);     /* the same, for IPv6 */
int sys_unix_addr(const char *path);
int sys_addr_family(const char *addr, int n);
/* The host of an INET address, dotted, and its port; NULL when it is not one. */
const char *sys_inet_parts(const char *addr, int n, int *port);
const char *sys_inet6_parts(const char *addr, int n, int *port);
const char *sys_unix_path(const char *addr, int n);
/* The databases: the entries come back as strings one after another, as for
   uname, and NULL when there is none. */
const char *sys_host_byname(const char *name);
const char *sys_host_byaddr(const char *dotted);
const char *sys_hostname(void);
const char *sys_proto_byname(const char *name);
const char *sys_proto_bynumber(int number);
const char *sys_serv_byname(const char *name, const char *protocol);
const char *sys_serv_byport(int port, const char *protocol);

/* The structure Windows (lib/basis/windows.sml): Windows' own, which every
   other system fails with ENOSYS. A key of the registry is a number, the
   seven at its roots 0 to 6; a failure is -1 or NULL, and a lookup that
   finds nothing is NULL with the error cleared. */
int sys_win_reg_open(int key, const char *name, int access, int create, int64_t out[2]);
int sys_win_reg_close(int key);
int sys_win_reg_delete(int key, const char *name, int value);
const char *sys_win_reg_enum(int key, int index, int value);
/* a value's bytes, its type in *type and its length in *length (-1: none) */
const char *sys_win_reg_query(int key, const char *name, int *type, int64_t *length);
int sys_win_reg_set(int key, const char *name, int type, const char *data, int64_t length);
const char *sys_win_config(int what);
/* major, minor, build and platform in out[], and the service pack */
const char *sys_win_version(int64_t out[4]);
/* the name of the volume and of its file system, one after the other; the
   serial and the longest name in out[] */
const char *sys_win_volume(const char *root, int64_t out[2]);
const char *sys_win_find_executable(const char *name);
int sys_win_shell_execute(const char *file, const char *arg, int document);
int64_t sys_win_spawn(const char *command, const char *arg, const int fds[3]);
int sys_win_wait(int64_t pid, int64_t *code);
int sys_win_dde_start(const char *service, const char *topic);
int sys_win_dde_execute(int info, const char *command, int retries, int64_t delay_ms);
int sys_win_dde_stop(int info);

/* Processes. */
int sys_system(const char *command);            /* the exit status, or -1 */
const char *sys_getenv(const char *name);       /* NULL when it is not set */

/* Executable memory, for the code a JIT makes (runtime/register; docs/plans/jit.md).
   sys_code_alloc gives size bytes, page-aligned, readable and writable, or
   NULL; sys_code_protect makes them executable and no longer writable
   (executable 1), or writable again (0), and gives 0 on failure;
   sys_code_flush is what a machine needs between writing code and running
   it (its instruction cache), and nothing on x86; sys_code_free gives the
   memory back; sys_code_page is the page, the unit sys_code_protect works
   in, so that a caller can protect the pages it wrote alone. sys_none
   fails the first with ENOSYS. */
void *sys_code_alloc(size_t size);
size_t sys_code_page(void);
int sys_code_protect(void *code, size_t size, int executable);
void sys_code_flush(void *code, size_t size);
void sys_code_free(void *code, size_t size);

/* Interrupts (docs/runtime.md, Interrupts; the incremental roadmap's D11):
   from now on, the user's interrupt -- SIGINT, Ctrl-C at a console -- sets
   *flag to 1 instead of ending the process, and the VM raises an exception
   where it next polls the flag; a terminal's read it comes during fails,
   EINTR (sys_read_fd). NULL: the interrupt ends the process again. 0, or
   -1 and the error (ENOSYS in sys_none, which has no interrupt). */
int sys_interrupt_catch(volatile int *flag);
/* An interrupt from another process on Windows, which has no SIGINT to
   send one (docs/repl.md; the REPL roadmap's M13): sys_event_new makes an
   event a child inherits, by its handle's number, and sys_event_set sets
   it; a process that catches the interrupt watches the events the
   variables RUNE_INTERRUPT_EVENT and JPY_INTERRUPT_EVENT (Jupyter's) name
   by number, and each that is set is the user's interrupt. -1 and ENOSYS
   where there are none (POSIX has SIGINT). */
int64_t sys_event_new(void);
int sys_event_set(int64_t handle);
/* n bytes of the system's randomness at out: 0, or -1 and the error */
int sys_random(void *out, size_t n);

/* The terminal of a program that edits what is typed (Terminal;
   docs/plans/repl.md, D4 and D5), named by descriptors: in, where keys are
   read, and out, where the program draws.
   sys_term_size: the columns and rows of the window, 0 or -1.
   sys_term_resizes: how many times the window has changed its size since
   the first call, which starts the count (SIGWINCH; a console's size
   records, which sys_term_read reads); -1 where it cannot be counted.
   sys_term_enter: in's terminal in raw mode -- every byte as it is typed,
   no echo, no signal from a key, output still translated (\n is \r\n);
   on Windows, the console's records with VT input. What the terminal was
   is saved at the first call; undo (n bytes) is what to write to out to
   take back what the program turned on itself (bracketed paste, a hidden
   cursor), written when the terminal is put back: by sys_term_leave, at
   exit, at a fatal error, and at the signals that end the process
   (SIGTERM, SIGHUP, SIGQUIT), all safe in a signal handler. A stop
   (SIGTSTP) puts it back and a continue (SIGCONT) raw again, counted as a
   resize, since the screen may have changed meanwhile. With quiet, the
   terminal is not raw but quiet: nothing echoed and keys kept for the next
   read, while keys still make their signals (Ctrl-C) and lines are not
   edited -- what a REPL wants while the code it runs may be interrupted --
   and put back in all the same ways. 0, or -1 and the error (ENOTTY;
   ENOTSUP from a console that has no VT input).
   sys_term_leave: the terminal as it was, and undo written; 0 or -1.
   sys_term_read: at most n bytes typed, as UTF-8, waiting at most ms
   milliseconds (-1: as long as it takes); 0 when the time is up or a
   resize or the user's interrupt ended the wait, -2 at the end of the
   input, -1 and the error. */
int sys_term_size(int fd, int *cols, int *rows);
int64_t sys_term_resizes(void);
int sys_term_enter(int in, int out, const char *undo, int64_t n, int quiet);
int sys_term_leave(void);
int64_t sys_term_read(int in, char *buf, int64_t n, int64_t ms);

/* Memory for the heap (runtime/gc/chunk.c): sys_mem_reserve gives size
   bytes at an address aligned to align (a power of two, a multiple of the
   page), readable and writable, or NULL; size is a multiple of align. It
   asks for the bytes at hint first, where they are aligned when hint is
   (the end of the last block: a heap's blocks come out side by side, as
   GHC's do), and makes room for the alignment only when they come back
   elsewhere (docs/plans/garbage-collector-v2.md, D10). sys_mem_release
   gives them back. */
void *sys_mem_reserve(size_t size, size_t align, void *hint);
void sys_mem_release(void *p, size_t size);

#endif
