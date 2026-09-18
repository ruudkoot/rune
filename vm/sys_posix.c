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
#include <dirent.h>
#include <poll.h>
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
