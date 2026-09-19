/* The system layer on POSIX. */
#define _POSIX_C_SOURCE 200809L
#include "sys.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* POSIX declares it, but only under _GNU_SOURCE in some libraries. */
extern char **environ;
#include <dirent.h>
#include <poll.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/times.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <pwd.h>
#include <grp.h>
#include <limits.h>
#include <sys/stat.h>
#include <utime.h>

int sys_errno(void) { return errno; }
void sys_set_errno(int e) { errno = e; }
const char *sys_error_msg(int e) { return strerror(e); }

/* The errno values of POSIX.1 that OS.errorName and OS.syserror know. */
static const struct { int value; const char *name; } error_names[] = {
#define E(n) { n, #n },
    E(E2BIG) E(EACCES) E(EADDRINUSE) E(EADDRNOTAVAIL) E(EAFNOSUPPORT) E(EAGAIN)
    E(EALREADY) E(EBADF) E(EBADMSG) E(EBUSY) E(ECANCELED) E(ECHILD) E(ECONNABORTED)
    E(ECONNREFUSED) E(ECONNRESET) E(EDEADLK) E(EDESTADDRREQ) E(EDOM) E(EDQUOT)
    E(EEXIST) E(EFAULT) E(EFBIG) E(EHOSTUNREACH) E(EIDRM) E(EILSEQ) E(EINPROGRESS)
    E(EINTR) E(EINVAL) E(EIO) E(EISCONN) E(EISDIR) E(ELOOP) E(EMFILE) E(EMLINK)
    E(EMSGSIZE) E(EMULTIHOP) E(ENAMETOOLONG) E(ENETDOWN) E(ENETRESET) E(ENETUNREACH)
    E(ENFILE) E(ENOBUFS) E(ENODEV) E(ENOENT) E(ENOEXEC) E(ENOLCK) E(ENOLINK) E(ENOMEM)
    E(ENOMSG) E(ENOPROTOOPT) E(ENOSPC) E(ENOSYS) E(ENOTCONN) E(ENOTDIR) E(ENOTEMPTY)
    E(ENOTSOCK) E(ENOTSUP) E(ENOTTY) E(ENXIO) E(EOVERFLOW) E(EPERM) E(EPIPE)
    E(EPROTO) E(EPROTONOSUPPORT) E(EPROTOTYPE) E(ERANGE) E(EROFS) E(ESPIPE) E(ESRCH)
    E(ESTALE) E(ETIMEDOUT) E(ETXTBSY) E(EXDEV)
#undef E
};
static const size_t n_error_names = sizeof error_names / sizeof error_names[0];

const char *sys_error_name(int e) {
    for (size_t i = 0; i < n_error_names; i++)
        if (error_names[i].value == e) return error_names[i].name;
    return "";
}

int sys_error_of_name(const char *name) {
    for (size_t i = 0; i < n_error_names; i++)
        if (strcmp(error_names[i].name, name) == 0) return error_names[i].value;
    return -1;
}

int64_t sys_time_now(void) {
    struct timeval tv;
    if (gettimeofday(&tv, NULL) != 0) return 0;
    return (int64_t)tv.tv_sec * 1000000 + tv.tv_usec;
}

static int64_t microseconds(const struct timeval *tv) {
    return (int64_t)tv->tv_sec * 1000000 + tv->tv_usec;
}

int64_t sys_time_user(void) {
    struct rusage ru;
    if (getrusage(RUSAGE_SELF, &ru) != 0) return 0;
    return microseconds(&ru.ru_utime);
}

int64_t sys_time_sys(void) {
    struct rusage ru;
    if (getrusage(RUSAGE_SELF, &ru) != 0) return 0;
    return microseconds(&ru.ru_stime);
}

void sys_time_sleep(int64_t microseconds) {
    if (microseconds <= 0) return;
    struct timespec ts;
    ts.tv_sec = (time_t)(microseconds / 1000000);
    ts.tv_nsec = (long)(microseconds % 1000000) * 1000;
    while (nanosleep(&ts, &ts) != 0 && errno == EINTR) { }
}

static void from_tm(const struct tm *tm, int32_t parts[9]) {
    parts[0] = tm->tm_sec;  parts[1] = tm->tm_min;   parts[2] = tm->tm_hour;
    parts[3] = tm->tm_mday; parts[4] = tm->tm_mon;   parts[5] = tm->tm_year;
    parts[6] = tm->tm_wday; parts[7] = tm->tm_yday;  parts[8] = tm->tm_isdst;
}

static void to_tm(const int32_t parts[9], struct tm *tm) {
    memset(tm, 0, sizeof *tm);
    tm->tm_sec = parts[0];  tm->tm_min = parts[1];   tm->tm_hour = parts[2];
    tm->tm_mday = parts[3]; tm->tm_mon = parts[4];   tm->tm_year = parts[5];
    tm->tm_isdst = parts[8];
}

int sys_date_parts(int64_t seconds, int local, int32_t parts[9]) {
    time_t t = (time_t)seconds;
    struct tm tm;
    if ((local ? localtime_r(&t, &tm) : gmtime_r(&t, &tm)) == NULL) return -1;
    from_tm(&tm, parts);
    return 0;
}

/* Days from 1970-01-01 to y-m-d of the proleptic Gregorian calendar, for
   m in 1..12 and any d (Howard Hinnant's days_from_civil). */
static int64_t days_from_civil(int64_t y, int64_t m, int64_t d) {
    y -= m <= 2;
    int64_t era = (y >= 0 ? y : y - 399) / 400;
    int64_t yoe = y - era * 400;
    int64_t doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    int64_t doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

int64_t sys_date_seconds(int32_t parts[9], int local) {
    struct tm tm;
    time_t t;
    if (local) {
        to_tm(parts, &tm);
        t = mktime(&tm);       /* which knows the time zone and its daylight saving */
        if (t == (time_t)-1) return -1;
    } else {
        /* timegm is not in POSIX.1-2008, and mktime cannot be made to work
           without a time zone, so the calendar arithmetic is done here. The
           fields may be out of range and are carried. */
        int64_t months = (int64_t)parts[5] + 1900;
        months = months * 12 + parts[4];
        int64_t year = months >= 0 ? months / 12 : -((-months + 11) / 12);
        int64_t month = months - year * 12;      /* 0..11 */
        int64_t days = days_from_civil(year, month + 1, parts[3]);
        int64_t seconds = days * 86400 + (int64_t)parts[2] * 3600 + (int64_t)parts[1] * 60 + parts[0];
        t = (time_t)seconds;
        if ((int64_t)t != seconds) return -1;
    }
    if (gmtime_r(&t, &tm) == NULL) return -1;
    if (local && localtime_r(&t, &tm) == NULL) return -1;
    from_tm(&tm, parts);
    return (int64_t)t;
}

int sys_date_offset(int64_t seconds, int32_t *offset) {
    time_t t = (time_t)seconds;
    struct tm local, utc;
    if (localtime_r(&t, &local) == NULL || gmtime_r(&t, &utc) == NULL) return -1;
    local.tm_isdst = 0;
    utc.tm_isdst = 0;
    time_t a = mktime(&local), b = mktime(&utc);
    if (a == (time_t)-1 || b == (time_t)-1) return -1;
    *offset = (int32_t)(a - b);
    return 0;
}

int sys_date_format(const char *format, const int32_t parts[9], int local, char *out, size_t n) {
    struct tm tm;
    to_tm(parts, &tm);
    tm.tm_wday = parts[6];
    tm.tm_yday = parts[7];
    if (!local) tm.tm_isdst = 0;
    size_t k = strftime(out, n, format, &tm);
    if (k == 0 && format[0] != 0) { out[0] = 0; return 0; }
    return (int)k;
}

/* The status a shell would report: what the command exited with, or 128
   plus the signal that ended it. */
int sys_system(const char *command) {
    int status = system(command);
    if (status == -1) return -1;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return status;
}

const char *sys_getenv(const char *name) { return getenv(name); }

/* ---------------------------------------------------------------- files */
int sys_mkdir(const char *path) { return mkdir(path, 0777); }
int sys_rmdir(const char *path) { return rmdir(path); }
int sys_chdir(const char *path) { return chdir(path); }

static char path_buffer[4096];

const char *sys_getcwd(void) {
    return getcwd(path_buffer, sizeof path_buffer);
}

int sys_remove(const char *path) { return unlink(path); }
int sys_rename(const char *from, const char *to) { return rename(from, to); }

int sys_access(const char *path, int read, int write, int exec) {
    int mode = 0;
    if (read) mode |= R_OK;
    if (write) mode |= W_OK;
    if (exec) mode |= X_OK;
    if (mode == 0) mode = F_OK;
    return access(path, mode) == 0 ? 1 : 0;
}

static int kind_of(mode_t mode) {
    if (S_ISREG(mode)) return 0;
    if (S_ISDIR(mode)) return 1;
    if (S_ISLNK(mode)) return 2;
    return 3;
}

int sys_file_kind(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    return kind_of(st.st_mode);
}

int sys_link_kind(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) return -1;
    return kind_of(st.st_mode);
}

int64_t sys_file_size(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    return (int64_t)st.st_size;
}

int64_t sys_mod_time(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    return (int64_t)st.st_mtime;
}

int sys_set_time(const char *path, int64_t seconds, int now) {
    if (now) return utime(path, NULL);
    struct utimbuf times;
    times.actime = (time_t)seconds;
    times.modtime = (time_t)seconds;
    return utime(path, &times);
}

const char *sys_read_link(const char *path) {
    ssize_t n = readlink(path, path_buffer, sizeof path_buffer - 1);
    if (n < 0) return NULL;
    path_buffer[n] = 0;
    return path_buffer;
}

const char *sys_real_path(const char *path) {
    return realpath(path, path_buffer);
}

const char *sys_tmp_name(void) {
    const char *dir = getenv("TMPDIR");
    if (!dir || !*dir) dir = "/tmp";
    snprintf(path_buffer, sizeof path_buffer, "%s/runeXXXXXX", dir);
    int fd = mkstemp(path_buffer);
    if (fd < 0) return NULL;
    close(fd);
    return path_buffer;
}

int sys_file_id(const char *path, int64_t *device, int64_t *inode) {
    struct stat st;
    if (stat(path, &st) != 0) return -1;
    *device = (int64_t)st.st_dev;
    *inode = (int64_t)st.st_ino;
    return 0;
}

/* The open directory streams, indexed by the number the library holds. */
static DIR **dirs = NULL;
static int dirs_length = 0;

int sys_open_dir(const char *path) {
    DIR *d = opendir(path);
    if (!d) return -1;
    for (int i = 0; i < dirs_length; i++)
        if (dirs[i] == NULL) { dirs[i] = d; return i; }
    DIR **grown = realloc(dirs, (size_t)(dirs_length + 1) * sizeof(DIR *));
    if (!grown) { closedir(d); errno = ENOMEM; return -1; }
    dirs = grown;
    dirs[dirs_length] = d;
    return dirs_length++;
}

static DIR *dir_of(int dir) {
    if (dir < 0 || dir >= dirs_length) { errno = EBADF; return NULL; }
    if (dirs[dir] == NULL) { errno = EBADF; return NULL; }
    return dirs[dir];
}

/* The entries "." and ".." are left out, as OS.FileSys.readDir prescribes. */
const char *sys_read_dir(int dir) {
    DIR *d = dir_of(dir);
    if (!d) return NULL;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(d);
        if (!entry) return NULL;
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            snprintf(path_buffer, sizeof path_buffer, "%s", entry->d_name);
            return path_buffer;
        }
    }
}

int sys_rewind_dir(int dir) {
    DIR *d = dir_of(dir);
    if (!d) return -1;
    rewinddir(d);
    return 0;
}

int sys_close_dir(int dir) {
    DIR *d = dir_of(dir);
    if (!d) return -1;
    dirs[dir] = NULL;
    return closedir(d);
}

/* ---------------------------------------------------------------- descriptors */
int sys_fileno(FILE *file) { return file ? fileno(file) : -1; }

int sys_desc_kind(int fd) {
    struct stat st;
    if (fstat(fd, &st) != 0) return -1;
    if (isatty(fd)) return 3;
    if (S_ISREG(st.st_mode)) return 0;
    if (S_ISDIR(st.st_mode)) return 1;
    if (S_ISLNK(st.st_mode)) return 2;
    if (S_ISFIFO(st.st_mode)) return 4;
    if (S_ISSOCK(st.st_mode)) return 5;
    return 6;
}

int sys_poll(const int *fds, int *events, int n, int64_t microseconds) {
    if (n < 0) { errno = EINVAL; return -1; }
    struct pollfd *items = malloc((size_t)(n > 0 ? n : 1) * sizeof *items);
    if (!items) { errno = ENOMEM; return -1; }
    for (int i = 0; i < n; i++) {
        items[i].fd = fds[i];
        items[i].events = (short)(((events[i] & 1) ? POLLIN : 0) |
                                  ((events[i] & 2) ? POLLOUT : 0) |
                                  ((events[i] & 4) ? POLLPRI : 0));
        items[i].revents = 0;
    }
    int timeout = microseconds < 0 ? -1 : (int)((microseconds + 999) / 1000);
    int ready;
    do { ready = poll(items, (nfds_t)n, timeout); } while (ready < 0 && errno == EINTR);
    if (ready >= 0)
        for (int i = 0; i < n; i++)
            events[i] = ((items[i].revents & (POLLIN | POLLHUP)) ? 1 : 0) |
                        ((items[i].revents & POLLOUT) ? 2 : 0) |
                        ((items[i].revents & POLLPRI) ? 4 : 0);
    free(items);
    return ready;
}

/* ---------------------------------------------------------------- constants */
static const struct { const char *name; int64_t value; } constants[] = {
#define C(n) { #n, (int64_t)n },
    /* the errors of POSIX.1 */
    C(E2BIG) C(EACCES) C(EADDRINUSE) C(EADDRNOTAVAIL) C(EAFNOSUPPORT) C(EAGAIN)
    C(EALREADY) C(EBADF) C(EBADMSG) C(EBUSY) C(ECANCELED) C(ECHILD) C(ECONNABORTED)
    C(ECONNREFUSED) C(ECONNRESET) C(EDEADLK) C(EDESTADDRREQ) C(EDOM) C(EDQUOT)
    C(EEXIST) C(EFAULT) C(EFBIG) C(EHOSTUNREACH) C(EIDRM) C(EILSEQ) C(EINPROGRESS)
    C(EINTR) C(EINVAL) C(EIO) C(EISCONN) C(EISDIR) C(ELOOP) C(EMFILE) C(EMLINK)
    C(EMSGSIZE) C(EMULTIHOP) C(ENAMETOOLONG) C(ENETDOWN) C(ENETRESET) C(ENETUNREACH)
    C(ENFILE) C(ENOBUFS) C(ENODEV) C(ENOENT) C(ENOEXEC) C(ENOLCK) C(ENOLINK) C(ENOMEM)
    C(ENOMSG) C(ENOPROTOOPT) C(ENOSPC) C(ENOSYS) C(ENOTCONN) C(ENOTDIR) C(ENOTEMPTY)
    C(ENOTSOCK) C(ENOTSUP) C(ENOTTY) C(ENXIO) C(EOVERFLOW) C(EPERM) C(EPIPE)
    C(EPROTO) C(EPROTONOSUPPORT) C(EPROTOTYPE) C(ERANGE) C(EROFS) C(ESPIPE) C(ESRCH)
    C(ESTALE) C(ETIMEDOUT) C(ETXTBSY) C(EXDEV)
    /* signals */
    C(SIGABRT) C(SIGALRM) C(SIGBUS) C(SIGCHLD) C(SIGCONT) C(SIGFPE) C(SIGHUP)
    C(SIGILL) C(SIGINT) C(SIGKILL) C(SIGPIPE) C(SIGQUIT) C(SIGSEGV) C(SIGSTOP)
    C(SIGTERM) C(SIGTSTP) C(SIGTTIN) C(SIGTTOU) C(SIGUSR1) C(SIGUSR2)
    /* opening a file */
    C(O_RDONLY) C(O_WRONLY) C(O_RDWR) C(O_APPEND) C(O_CREAT) C(O_EXCL) C(O_NOCTTY)
    C(O_NONBLOCK) C(O_SYNC) C(O_TRUNC)
    /* the bits of a file mode */
    C(S_IRUSR) C(S_IWUSR) C(S_IXUSR) C(S_IRWXU) C(S_IRGRP) C(S_IWGRP) C(S_IXGRP)
    C(S_IRWXG) C(S_IROTH) C(S_IWOTH) C(S_IXOTH) C(S_IRWXO) C(S_ISUID) C(S_ISGID)
    /* where a seek starts, what fcntl does, how to wait */
    C(SEEK_SET) C(SEEK_CUR) C(SEEK_END)
    C(F_DUPFD) C(F_GETFD) C(F_SETFD) C(F_GETFL) C(F_SETFL) C(FD_CLOEXEC)
    C(WNOHANG) C(WUNTRACED)
#undef C
};
static const size_t n_constants = sizeof constants / sizeof constants[0];

int64_t sys_const(const char *name) {
    for (size_t i = 0; i < n_constants; i++)
        if (strcmp(constants[i].name, name) == 0) return constants[i].value;
    return -1;
}

/* ---------------------------------------------------------------- processes */
int sys_fork(void) { return (int)fork(); }

int sys_exec(const char *path, char *const argv[], char *const envp[], int search) {
    if (search) {
        if (envp) environ = (char **)envp;
        execvp(path, argv);
    } else {
        execve(path, argv, envp ? envp : environ);
    }
    return -1;
}

int sys_waitpid(int64_t pid, int flags, int64_t out[3]) {
    int status = 0;
    pid_t got = waitpid((pid_t)pid, &status, flags);
    if (got < 0) return -1;
    out[0] = (int64_t)got;
    if (WIFEXITED(status)) { out[1] = 0; out[2] = WEXITSTATUS(status); }
    else if (WIFSIGNALED(status)) { out[1] = 1; out[2] = WTERMSIG(status); }
    else if (WIFSTOPPED(status)) { out[1] = 2; out[2] = WSTOPSIG(status); }
    else { out[1] = 0; out[2] = 0; }
    return 0;
}

int sys_kill(int64_t pid, int signal) { return kill((pid_t)pid, signal); }
int sys_alarm(int seconds) { return (int)alarm((unsigned)seconds); }
int sys_pause(void) { pause(); return 0; }
int64_t sys_getpid(void) { return (int64_t)getpid(); }
int64_t sys_getppid(void) { return (int64_t)getppid(); }
int64_t sys_getuid(void) { return (int64_t)getuid(); }
int64_t sys_geteuid(void) { return (int64_t)geteuid(); }
int64_t sys_getgid(void) { return (int64_t)getgid(); }
int64_t sys_getegid(void) { return (int64_t)getegid(); }
int sys_setuid(int64_t uid) { return setuid((uid_t)uid); }
int sys_setgid(int64_t gid) { return setgid((gid_t)gid); }

int sys_getgroups(int64_t *out, int n) {
    gid_t buffer[256];
    int k = getgroups(n > 256 ? 256 : n, buffer);
    if (k < 0) return -1;
    for (int i = 0; i < k; i++) out[i] = (int64_t)buffer[i];
    return k;
}

const char *sys_getlogin(void) { return getlogin(); }
int64_t sys_getpgrp(void) { return (int64_t)getpgrp(); }
int64_t sys_setsid(void) { return (int64_t)setsid(); }
int sys_setpgid(int64_t pid, int64_t pgid) { return setpgid((pid_t)pid, (pid_t)pgid); }

/* The strings of a call, one after another, each ending with a NUL. */
static char strings[8192];

const char *sys_uname(void) {
    struct utsname u;
    if (uname(&u) != 0) return NULL;
    const char *parts[5] = { u.sysname, u.nodename, u.release, u.version, u.machine };
    size_t at = 0;
    for (int i = 0; i < 5; i++) {
        size_t n = strlen(parts[i]);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, parts[i], n);
        at += n;
        strings[at++] = 0;
    }
    strings[at] = 0;
    return strings;
}

int sys_times(int64_t out[5]) {
    struct tms t;
    clock_t elapsed = times(&t);
    if (elapsed == (clock_t)-1) return -1;
    long per = sysconf(_SC_CLK_TCK);
    if (per <= 0) per = 100;
    int64_t micros = 1000000 / per;
    out[0] = (int64_t)elapsed * micros;
    out[1] = (int64_t)t.tms_utime * micros;
    out[2] = (int64_t)t.tms_stime * micros;
    out[3] = (int64_t)t.tms_cutime * micros;
    out[4] = (int64_t)t.tms_cstime * micros;
    return 0;
}

const char *sys_environ(void) {
    size_t at = 0;
    for (char **e = environ; *e; e++) {
        size_t n = strlen(*e);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, *e, n);
        at += n;
        strings[at++] = 0;
    }
    strings[at] = 0;
    return strings;
}

const char *sys_ctermid(void) { return ctermid(path_buffer); }
const char *sys_ttyname(int fd) { return ttyname(fd); }
int sys_isatty(int fd) { return isatty(fd) ? 1 : 0; }

int64_t sys_sysconf(const char *name) {
    int which;
    if (strcmp(name, "ARG_MAX") == 0) which = _SC_ARG_MAX;
    else if (strcmp(name, "CHILD_MAX") == 0) which = _SC_CHILD_MAX;
    else if (strcmp(name, "CLK_TCK") == 0) which = _SC_CLK_TCK;
    else if (strcmp(name, "NGROUPS_MAX") == 0) which = _SC_NGROUPS_MAX;
    else if (strcmp(name, "OPEN_MAX") == 0) which = _SC_OPEN_MAX;
    else if (strcmp(name, "STREAM_MAX") == 0) which = _SC_STREAM_MAX;
    else if (strcmp(name, "TZNAME_MAX") == 0) which = _SC_TZNAME_MAX;
    else if (strcmp(name, "JOB_CONTROL") == 0) which = _SC_JOB_CONTROL;
    else if (strcmp(name, "SAVED_IDS") == 0) which = _SC_SAVED_IDS;
    else if (strcmp(name, "VERSION") == 0) which = _SC_VERSION;
    else if (strcmp(name, "PAGESIZE") == 0) which = _SC_PAGESIZE;
    else { errno = EINVAL; return -1; }
    errno = 0;
    return (int64_t)sysconf(which);
}

/* ---------------------------------------------------------------- descriptors */
int sys_openf(const char *path, int flags, int mode) { return open(path, flags, (mode_t)mode); }
int sys_close_fd(int fd) { return close(fd); }
int sys_dup(int fd) { return dup(fd); }
int sys_dup2(int fd, int to) { return dup2(fd, to); }
int sys_pipe(int out[2]) { return pipe(out); }

int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    ssize_t k;
    do { k = read(fd, buf, (size_t)n); } while (k < 0 && errno == EINTR);
    return (int64_t)k;
}

int64_t sys_write_fd(int fd, const char *buf, int64_t n) {
    ssize_t k;
    do { k = write(fd, buf, (size_t)n); } while (k < 0 && errno == EINTR);
    return (int64_t)k;
}

int64_t sys_lseek_fd(int fd, int64_t offset, int whence) {
    return (int64_t)lseek(fd, (off_t)offset, whence);
}

int sys_fsync(int fd) { return fsync(fd); }
int sys_fcntl(int fd, int command, int argument) { return fcntl(fd, command, argument); }
int sys_ftruncate(int fd, int64_t length) { return ftruncate(fd, (off_t)length); }

int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]) {
    struct stat st;
    int ok = path ? (follow ? stat(path, &st) : lstat(path, &st)) : fstat(fd, &st);
    if (ok != 0) return -1;
    out[0] = kind_of(st.st_mode);
    out[1] = (int64_t)(st.st_mode & 07777);
    out[2] = (int64_t)st.st_ino;
    out[3] = (int64_t)st.st_dev;
    out[4] = (int64_t)st.st_nlink;
    out[5] = (int64_t)st.st_uid;
    out[6] = (int64_t)st.st_gid;
    out[7] = (int64_t)st.st_size;
    out[8] = (int64_t)st.st_atime;
    out[9] = (int64_t)st.st_mtime;
    out[10] = (int64_t)st.st_ctime;
    return 0;
}

int sys_chmod(const char *path, int fd, int mode) {
    return path ? chmod(path, (mode_t)mode) : fchmod(fd, (mode_t)mode);
}

int sys_chown(const char *path, int fd, int64_t uid, int64_t gid) {
    return path ? chown(path, (uid_t)uid, (gid_t)gid) : fchown(fd, (uid_t)uid, (gid_t)gid);
}

int sys_link(const char *from, const char *to) { return link(from, to); }
int sys_symlink(const char *from, const char *to) { return symlink(from, to); }
int sys_mkfifo(const char *path, int mode) { return mkfifo(path, (mode_t)mode); }
int sys_umask(int mask) { return (int)umask((mode_t)mask); }

static char members[8192];

const char *sys_getpw(const char *name, int64_t uid, int64_t out[2]) {
    struct passwd *pw = name ? getpwnam(name) : getpwuid((uid_t)uid);
    if (!pw) return NULL;
    out[0] = (int64_t)pw->pw_uid;
    out[1] = (int64_t)pw->pw_gid;
    const char *parts[3] = { pw->pw_name, pw->pw_dir, pw->pw_shell };
    size_t at = 0;
    for (int i = 0; i < 3; i++) {
        size_t n = strlen(parts[i]);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, parts[i], n);
        at += n;
        strings[at++] = 0;
    }
    strings[at] = 0;
    return strings;
}

const char *sys_getgr(const char *name, int64_t gid, int64_t *id) {
    struct group *gr = name ? getgrnam(name) : getgrgid((gid_t)gid);
    if (!gr) return NULL;
    *id = (int64_t)gr->gr_gid;
    size_t at = 0;
    for (char **m = gr->gr_mem; m && *m; m++) {
        size_t n = strlen(*m);
        if (at + n + 2 >= sizeof members) break;
        memcpy(members + at, *m, n);
        at += n;
        members[at++] = 0;
    }
    members[at] = 0;
    snprintf(strings, sizeof strings, "%s", gr->gr_name);
    strings[strlen(gr->gr_name) + 1] = 0;
    return strings;
}

const char *sys_group_members(void) { return members; }
