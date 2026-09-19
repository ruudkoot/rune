/* The system layer where there is no POSIX (`make vm SYS=none`): every call
   fails with ENOSYS, which the library turns into OS.SysErr. */
#include "sys.h"

#include <errno.h>
#include <string.h>
#include <stdio.h>
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

int sys_mkdir(const char *path) { (void)path; return fail(); }
int sys_rmdir(const char *path) { (void)path; return fail(); }
int sys_chdir(const char *path) { (void)path; return fail(); }
const char *sys_getcwd(void) { fail(); return NULL; }
int sys_remove(const char *path) { return remove(path) == 0 ? 0 : fail(); }
int sys_rename(const char *from, const char *to) { return rename(from, to) == 0 ? 0 : fail(); }
int sys_access(const char *path, int read, int write, int exec) {
    (void)path; (void)read; (void)write; (void)exec; return fail();
}
int sys_file_kind(const char *path) { (void)path; return fail(); }
int sys_link_kind(const char *path) { (void)path; return fail(); }
int64_t sys_file_size(const char *path) { (void)path; return fail(); }
int64_t sys_mod_time(const char *path) { (void)path; return fail(); }
int sys_set_time(const char *path, int64_t seconds, int now) {
    (void)path; (void)seconds; (void)now; return fail();
}
const char *sys_read_link(const char *path) { (void)path; fail(); return NULL; }
const char *sys_real_path(const char *path) { (void)path; fail(); return NULL; }
const char *sys_tmp_name(void) { return tmpnam(NULL); }
int sys_file_id(const char *path, int64_t *device, int64_t *inode) {
    (void)path; (void)device; (void)inode; return fail();
}
int sys_open_dir(const char *path) { (void)path; return fail(); }
const char *sys_read_dir(int dir) { (void)dir; fail(); return NULL; }
int sys_rewind_dir(int dir) { (void)dir; return fail(); }
int sys_close_dir(int dir) { (void)dir; return fail(); }

int sys_fileno(FILE *file) { (void)file; return fail(); }
int sys_desc_kind(int fd) { (void)fd; return fail(); }
int sys_poll(const int *fds, int *events, int n, int64_t microseconds) {
    (void)fds; (void)events; (void)n; (void)microseconds; return fail();
}

int64_t sys_const(const char *name) { (void)name; return -1; }
int sys_fork(void) { return fail(); }
int sys_exec(const char *path, char *const argv[], char *const envp[], int search) {
    (void)path; (void)argv; (void)envp; (void)search; return fail();
}
int sys_waitpid(int64_t pid, int flags, int64_t out[3]) { (void)pid; (void)flags; (void)out; return fail(); }
int sys_kill(int64_t pid, int signal) { (void)pid; (void)signal; return fail(); }
int sys_alarm(int seconds) { (void)seconds; return fail(); }
int sys_pause(void) { return fail(); }
int64_t sys_getpid(void) { return fail(); }
int64_t sys_getppid(void) { return fail(); }
int64_t sys_getuid(void) { return fail(); }
int64_t sys_geteuid(void) { return fail(); }
int64_t sys_getgid(void) { return fail(); }
int64_t sys_getegid(void) { return fail(); }
int sys_setuid(int64_t uid) { (void)uid; return fail(); }
int sys_setgid(int64_t gid) { (void)gid; return fail(); }
int sys_getgroups(int64_t *out, int n) { (void)out; (void)n; return fail(); }
const char *sys_getlogin(void) { fail(); return NULL; }
int64_t sys_getpgrp(void) { return fail(); }
int64_t sys_setsid(void) { return fail(); }
int sys_setpgid(int64_t pid, int64_t pgid) { (void)pid; (void)pgid; return fail(); }
const char *sys_uname(void) { fail(); return NULL; }
int sys_times(int64_t out[5]) { (void)out; return fail(); }
const char *sys_environ(void) { fail(); return NULL; }
const char *sys_ctermid(void) { fail(); return NULL; }
const char *sys_ttyname(int fd) { (void)fd; fail(); return NULL; }
int sys_isatty(int fd) { (void)fd; return fail(); }
int64_t sys_sysconf(const char *name) { (void)name; return fail(); }

int sys_openf(const char *path, int flags, int mode) { (void)path; (void)flags; (void)mode; return fail(); }
int sys_close_fd(int fd) { (void)fd; return fail(); }
int sys_dup(int fd) { (void)fd; return fail(); }
int sys_dup2(int fd, int to) { (void)fd; (void)to; return fail(); }
int sys_pipe(int out[2]) { (void)out; return fail(); }
int64_t sys_read_fd(int fd, char *buf, int64_t n) { (void)fd; (void)buf; (void)n; return fail(); }
int64_t sys_write_fd(int fd, const char *buf, int64_t n) { (void)fd; (void)buf; (void)n; return fail(); }
int64_t sys_lseek_fd(int fd, int64_t offset, int whence) { (void)fd; (void)offset; (void)whence; return fail(); }
int sys_fsync(int fd) { (void)fd; return fail(); }
int sys_fcntl(int fd, int command, int argument) { (void)fd; (void)command; (void)argument; return fail(); }
int sys_lock(int fd, int command, int type, int whence, int64_t start, int64_t length, int64_t out[5]) {
    (void)fd; (void)command; (void)type; (void)whence; (void)start; (void)length; (void)out; return fail();
}
int sys_pathconf(const char *path, int fd, const char *name, int64_t *out) {
    (void)path; (void)fd; (void)name; (void)out; return fail();
}
int sys_tcgetattr(int fd, int64_t *out) { (void)fd; (void)out; return fail(); }
int sys_tcsetattr(int fd, int action, const int64_t *in) { (void)fd; (void)action; (void)in; return fail(); }
int64_t sys_tcop(int op, int fd, int64_t argument) { (void)op; (void)fd; (void)argument; return fail(); }
int sys_nccs(void) { return 0; }
int sys_linger(int fd, int set, int *seconds) { (void)fd; (void)set; (void)seconds; return fail(); }
int sys_socket_query(int fd, int what) { (void)fd; (void)what; return fail(); }
int sys_utime(const char *path, int64_t access, int64_t modification) {
    (void)path; (void)access; (void)modification; return fail();
}
int sys_ftruncate(int fd, int64_t length) { (void)fd; (void)length; return fail(); }
int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]) {
    (void)path; (void)follow; (void)fd; (void)out; return fail();
}
int sys_chmod(const char *path, int fd, int mode) { (void)path; (void)fd; (void)mode; return fail(); }
int sys_chown(const char *path, int fd, int64_t uid, int64_t gid) {
    (void)path; (void)fd; (void)uid; (void)gid; return fail();
}
int sys_link(const char *from, const char *to) { (void)from; (void)to; return fail(); }
int sys_symlink(const char *from, const char *to) { (void)from; (void)to; return fail(); }
int sys_mkfifo(const char *path, int mode) { (void)path; (void)mode; return fail(); }
int sys_umask(int mask) { (void)mask; return fail(); }
const char *sys_getpw(const char *name, int64_t uid, int64_t out[2]) {
    (void)name; (void)uid; (void)out; fail(); return NULL;
}
const char *sys_getgr(const char *name, int64_t gid, int64_t *id) {
    (void)name; (void)gid; (void)id; fail(); return NULL;
}
const char *sys_group_members(void) { return ""; }

int sys_socket(int d, int t, int p) { (void)d; (void)t; (void)p; return fail(); }
int sys_socketpair(int d, int t, int p, int out[2]) { (void)d; (void)t; (void)p; (void)out; return fail(); }
int sys_bind(int fd, const char *a, int n) { (void)fd; (void)a; (void)n; return fail(); }
int sys_connect(int fd, const char *a, int n) { (void)fd; (void)a; (void)n; return fail(); }
int sys_listen(int fd, int b) { (void)fd; (void)b; return fail(); }
int sys_accept(int fd) { (void)fd; return fail(); }
int64_t sys_send(int fd, const char *b, int64_t n, int f) { (void)fd; (void)b; (void)n; (void)f; return fail(); }
int64_t sys_sendto(int fd, const char *b, int64_t n, int f, const char *a, int al) {
    (void)fd; (void)b; (void)n; (void)f; (void)a; (void)al; return fail();
}
int64_t sys_recv(int fd, char *b, int64_t n, int f) { (void)fd; (void)b; (void)n; (void)f; return fail(); }
int64_t sys_recvfrom(int fd, char *b, int64_t n, int f) { (void)fd; (void)b; (void)n; (void)f; return fail(); }
int sys_shutdown(int fd, int how) { (void)fd; (void)how; return fail(); }
int sys_sock_name(int fd) { (void)fd; return fail(); }
int sys_sock_peer(int fd) { (void)fd; return fail(); }
const char *sys_last_addr(void) { return ""; }
int sys_last_addr_len(void) { return 0; }
int sys_getsockopt(int fd, int l, int n) { (void)fd; (void)l; (void)n; return fail(); }
int sys_setsockopt(int fd, int l, int n, int v) { (void)fd; (void)l; (void)n; (void)v; return fail(); }
int sys_inet_addr(const char *h, int p) { (void)h; (void)p; return fail(); }
int sys_unix_addr(const char *p) { (void)p; return fail(); }
int sys_addr_family(const char *a, int n) { (void)a; (void)n; return fail(); }
const char *sys_inet_parts(const char *a, int n, int *p) { (void)a; (void)n; (void)p; fail(); return NULL; }
const char *sys_unix_path(const char *a, int n) { (void)a; (void)n; fail(); return NULL; }
const char *sys_host_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_host_byaddr(const char *d) { (void)d; fail(); return NULL; }
const char *sys_hostname(void) { fail(); return NULL; }
const char *sys_proto_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_proto_bynumber(int n) { (void)n; fail(); return NULL; }
const char *sys_serv_byname(const char *n, const char *p) { (void)n; (void)p; fail(); return NULL; }
const char *sys_serv_byport(int p, const char *pr) { (void)p; (void)pr; fail(); return NULL; }
