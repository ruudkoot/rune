/* The system layer on POSIX. */
#define _POSIX_C_SOURCE 200809L
/* `realpath` is POSIX.1-2008, and a glibc new enough declares it for the line
   above; an older one wants this as well, which a cross compiler's headers
   showed (make test-portability). */
#define _XOPEN_SOURCE 700
/* off_t of 64 bits on a 32-bit system as well: file positions, sizes */
#define _FILE_OFFSET_BITS 64
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
#include <sys/mman.h>

/* POSIX declares it, but only under _GNU_SOURCE in some libraries. */
extern char **environ;
#include <dirent.h>
#include <poll.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/times.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <pwd.h>
#include <grp.h>
#include <limits.h>
#include <stddef.h>
#include <sys/stat.h>
#include <utime.h>
#include <termios.h>
#include <sys/ioctl.h>

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

/* An OS.Process.status: what the command exited with, or 256 plus the
   signal that ended it (Posix.Process.fromStatus tells them apart). */
int sys_system(const char *command) {
    int status = system(command);
    if (status == -1) return -1;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 256 + WTERMSIG(status);
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

/* 0 regular file, 1 directory, 2 symbolic link, 4 FIFO, 5 socket,
   6 character device, 7 block device, 3 anything else */
static int kind_of(mode_t mode) {
    if (S_ISREG(mode)) return 0;
    if (S_ISDIR(mode)) return 1;
    if (S_ISLNK(mode)) return 2;
    if (S_ISFIFO(mode)) return 4;
    if (S_ISSOCK(mode)) return 5;
    if (S_ISCHR(mode)) return 6;
    if (S_ISBLK(mode)) return 7;
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

int sys_utime(const char *path, int64_t access, int64_t modification) {
    struct utimbuf times;
    times.actime = (time_t)access;
    times.modtime = (time_t)modification;
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

/* The open directory streams, indexed by the number the library holds,
   and how many entries each has read, which a fork by a second VM reads
   again (sys_resume). */
static DIR **dirs = NULL;
static long *dir_reads = NULL;
static int dirs_length = 0;

static int grow_dirs(int length) {
    if (length <= dirs_length) return 0;
    DIR **grown = realloc(dirs, (size_t)length * sizeof(DIR *));
    if (grown) dirs = grown;
    long *reads = grown ? realloc(dir_reads, (size_t)length * sizeof(long)) : NULL;
    if (reads) dir_reads = reads;
    if (!grown || !reads) { errno = ENOMEM; return -1; }
    for (int i = dirs_length; i < length; i++) { dirs[i] = NULL; dir_reads[i] = 0; }
    dirs_length = length;
    return 0;
}

int sys_open_dir(const char *path) {
    DIR *d = opendir(path);
    if (!d) return -1;
    int i;
    for (i = 0; i < dirs_length; i++) if (dirs[i] == NULL) break;
    if (i == dirs_length && grow_dirs(dirs_length + 1) != 0) { closedir(d); return -1; }
    dirs[i] = d;
    dir_reads[i] = 0;
    return i;
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
        dir_reads[dir]++;
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
    dir_reads[dir] = 0;
    return 0;
}

int sys_close_dir(int dir) {
    DIR *d = dir_of(dir);
    if (!d) return -1;
    dirs[dir] = NULL;
    return closedir(d);
}

/* ---------------------------------------------------------------- descriptors */
FILE *sys_fopen(const char *path, const char *mode) { return fopen(path, mode); }
int sys_fileno(FILE *file) { return file ? fileno(file) : -1; }
int64_t sys_ftell(FILE *file) { off_t r = ftello(file); return r < 0 ? -1 : (int64_t)r; }
int sys_fseek(FILE *file, int64_t offset, int whence) {
    return fseeko(file, (off_t)offset, whence) == 0 ? 0 : -1;
}

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
    C(E2BIG) C(EACCES) C(EADDRINUSE) C(EADDRNOTAVAIL) C(EAFNOSUPPORT) C(EAGAIN) C(EWOULDBLOCK)
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
    C(F_GETLK) C(F_SETLK) C(F_SETLKW) C(F_RDLCK) C(F_WRLCK) C(F_UNLCK)
    /* the terminal (Posix.TTY) */
    C(BRKINT) C(ICRNL) C(IGNBRK) C(IGNCR) C(IGNPAR) C(INLCR) C(INPCK) C(ISTRIP)
    C(IXOFF) C(IXON) C(PARMRK) C(OPOST) C(CLOCAL) C(CREAD) C(CS5) C(CS6) C(CS7)
    C(CS8) C(CSIZE) C(CSTOPB) C(HUPCL) C(PARENB) C(PARODD) C(ECHO) C(ECHOE)
    C(ECHOK) C(ECHONL) C(ICANON) C(IEXTEN) C(ISIG) C(NOFLSH) C(TOSTOP)
    C(VEOF) C(VEOL) C(VERASE) C(VINTR) C(VKILL) C(VMIN) C(VQUIT) C(VSUSP)
    C(VTIME) C(VSTART) C(VSTOP) C(NCCS)
    C(B0) C(B50) C(B75) C(B110) C(B134) C(B150) C(B200) C(B300) C(B600) C(B1200)
    C(B1800) C(B2400) C(B4800) C(B9600) C(B19200) C(B38400)
    C(TCSANOW) C(TCSADRAIN) C(TCSAFLUSH) C(TCOOFF) C(TCOON) C(TCIOFF) C(TCION)
    C(TCIFLUSH) C(TCOFLUSH) C(TCIOFLUSH)
    /* the limits of pathconf */
    C(_PC_LINK_MAX) C(_PC_MAX_CANON) C(_PC_MAX_INPUT) C(_PC_NAME_MAX) C(_PC_PATH_MAX)
    C(_PC_PIPE_BUF) C(_PC_CHOWN_RESTRICTED) C(_PC_NO_TRUNC) C(_PC_VDISABLE)
    C(_PC_SYNC_IO) C(_PC_ASYNC_IO) C(_PC_PRIO_IO) C(_PC_FILESIZEBITS)
    C(WNOHANG) C(WUNTRACED)
    /* sockets */
    C(AF_INET) C(AF_INET6) C(AF_UNIX) C(SOCK_STREAM) C(SOCK_DGRAM) C(SOL_SOCKET)
    C(SO_DEBUG) C(SO_REUSEADDR) C(SO_KEEPALIVE) C(SO_DONTROUTE) C(SO_LINGER)
    C(SO_BROADCAST) C(SO_OOBINLINE) C(SO_SNDBUF) C(SO_RCVBUF) C(SO_TYPE) C(SO_ERROR)
    C(MSG_OOB) C(MSG_PEEK) C(MSG_DONTROUTE)
    C(SHUT_RD) C(SHUT_WR) C(SHUT_RDWR)
    C(IPPROTO_TCP) C(TCP_NODELAY)
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

/* fork by a second VM (vm/image.c): POSIX has fork, and this is only taken
   under runevm --emulate-fork, to test on POSIX what Windows has to do.
   The child is this process forked and made runevm again from
   /proc/self/exe (so Linux alone), which keeps the descriptors, the
   working directory and the umask. What exec loses is carried: each
   descriptor's close-on-exec is cleared before it and set again in the
   child, and each directory stream is opened anew there and read on to
   where the parent's stood. */
int sys_has_fork(void) { return 1; }
static pid_t fork_child = -1;
static struct sigaction fork_pipe_action;
FILE *sys_fork_start(void) {
    long limit = sysconf(_SC_OPEN_MAX);
    if (limit < 0 || limit > 65536) limit = 65536;
    int *cloexec = malloc((size_t)limit * sizeof(int));
    if (!cloexec) { errno = ENOMEM; return NULL; }
    uint32_t n = 0;
    for (int fd = 0; fd < limit; fd++) {
        int flags = fcntl(fd, F_GETFD);
        if (flags >= 0 && (flags & FD_CLOEXEC)) cloexec[n++] = fd;
    }
    int p[2];
    if (pipe(p) != 0) { free(cloexec); return NULL; }
    fcntl(p[1], F_SETFD, FD_CLOEXEC);
    char token[32];
    snprintf(token, sizeof token, "%d", p[0]);
    pid_t pid = fork();
    if (pid < 0) { int e = errno; close(p[0]); close(p[1]); free(cloexec); errno = e; return NULL; }
    if (pid == 0) {
        for (uint32_t i = 0; i < n; i++) fcntl(cloexec[i], F_SETFD, 0);
        execl("/proc/self/exe", "runevm", "--resume", token, (char *)NULL);
        _exit(127);
    }
    close(p[0]);
    /* a child that is gone before it has read everything must not end
       this process by SIGPIPE */
    struct sigaction ignore;
    memset(&ignore, 0, sizeof ignore);
    ignore.sa_handler = SIG_IGN;
    sigemptyset(&ignore.sa_mask);
    sigaction(SIGPIPE, &ignore, &fork_pipe_action);
    FILE *out = fdopen(p[1], "wb");
    if (!out) {
        int e = errno;
        close(p[1]);
        waitpid(pid, NULL, 0);
        sigaction(SIGPIPE, &fork_pipe_action, NULL);
        free(cloexec);
        errno = e;
        return NULL;
    }
    fork_child = pid;
    setvbuf(out, NULL, _IOFBF, 1 << 20);   /* the image is the whole heap */
    fwrite(&n, sizeof n, 1, out);
    fwrite(cloexec, sizeof(int), n, out);
    free(cloexec);
    uint32_t ndirs = 0;
    for (int i = 0; i < dirs_length; i++) if (dirs[i]) ndirs++;
    fwrite(&ndirs, sizeof ndirs, 1, out);
    for (int i = 0; i < dirs_length; i++) {
        if (!dirs[i]) continue;
        int fd = dirfd(dirs[i]);
        fwrite(&i, sizeof i, 1, out);
        fwrite(&fd, sizeof fd, 1, out);
        fwrite(&dir_reads[i], sizeof dir_reads[i], 1, out);
    }
    return out;
}
int64_t sys_fork_finish(FILE *image) {
    fclose(image);
    sigaction(SIGPIPE, &fork_pipe_action, NULL);
    return fork_child;
}
FILE *sys_resume(const char *token) {
    char *end;
    errno = 0;
    long fd = strtol(token, &end, 10);
    if (errno != 0 || end == token || *end != 0 || fd < 0 || fd > INT_MAX) { errno = EINVAL; return NULL; }
    FILE *in = fdopen((int)fd, "rb");
    if (!in) return NULL;
    setvbuf(in, NULL, _IOFBF, 1 << 20);
    uint32_t n = 0;
    if (fread(&n, sizeof n, 1, in) != 1) { fclose(in); errno = EIO; return NULL; }
    for (uint32_t i = 0; i < n; i++) {
        int cloexec;
        if (fread(&cloexec, sizeof cloexec, 1, in) != 1) { fclose(in); errno = EIO; return NULL; }
        fcntl(cloexec, F_SETFD, FD_CLOEXEC);
    }
    uint32_t ndirs = 0;
    if (fread(&ndirs, sizeof ndirs, 1, in) != 1) { fclose(in); errno = EIO; return NULL; }
    for (uint32_t k = 0; k < ndirs; k++) {
        int i, dfd;
        long reads;
        if (fread(&i, sizeof i, 1, in) != 1 || fread(&dfd, sizeof dfd, 1, in) != 1 ||
            fread(&reads, sizeof reads, 1, in) != 1 || i < 0) { fclose(in); errno = EIO; return NULL; }
        char proc[64];
        snprintf(proc, sizeof proc, "/proc/self/fd/%d", dfd);
        int again = open(proc, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        DIR *d = again >= 0 ? fdopendir(again) : NULL;
        if (!d && again >= 0) close(again);
        close(dfd);
        if (!d || grow_dirs(i + 1) != 0) continue;
        long r = 0;
        while (r < reads && readdir(d)) r++;
        dirs[i] = d;
        dir_reads[i] = r;
    }
    return in;
}
FILE *sys_fdopen(int fd, const char *mode) { return fdopen(fd, mode); }

int sys_exec(const char *path, char *const argv[], char *const envp[], int search) {
    if (search) {
        if (envp) environ = (char **)envp;
        execvp(path, argv);
    } else {
        execve(path, argv, envp ? envp : environ);
    }
    return -1;
}

/* fork, then in the child the descriptors dup2'ed onto 0, 1 and 2 (and
   closed where they were others), then exec, and 126 if that fails, as a
   shell has it. */
int64_t sys_spawn(const char *path, char *const argv[], char *const envp[], int search, const int fds[3]) {
    pid_t pid = fork();
    if (pid != 0) return pid < 0 ? -1 : (int64_t)pid;
    for (int i = 0; i < 3; i++)
        if (fds[i] >= 0 && fds[i] != i && dup2(fds[i], i) < 0) _exit(126);
    for (int i = 0; i < 3; i++) {
        int later = 0;
        for (int j = i + 1; j < 3; j++) later |= fds[j] == fds[i];
        if (fds[i] > 2 && !later) close(fds[i]);
    }
    sys_exec(path, argv, envp, search);
    _exit(126);
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
void sys_exit_now(int status) { _exit(status); }
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

/* errno is cleared first, as for sys_recv: nothing read is the end of the
   file when it is still 0 afterwards. */
int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    ssize_t k;
    do { errno = 0; k = read(fd, buf, (size_t)n); } while (k < 0 && errno == EINTR);
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

/* The terminal settings of fd as numbers: iflag, oflag, cflag, lflag, input
   speed, output speed, then the NCCS control characters. -1 on failure. */
int sys_tcgetattr(int fd, int64_t *out) {
    struct termios t;
    if (tcgetattr(fd, &t) != 0) return -1;
    out[0] = t.c_iflag; out[1] = t.c_oflag; out[2] = t.c_cflag; out[3] = t.c_lflag;
    out[4] = (int64_t)cfgetispeed(&t); out[5] = (int64_t)cfgetospeed(&t);
    for (int i = 0; i < NCCS; i++) out[6 + i] = t.c_cc[i];
    return 0;
}

/* The inverse, with the action TCSANOW, TCSADRAIN or TCSAFLUSH; in holds
   6 + NCCS numbers. The fields the numbers do not describe stay as they are. */
int sys_tcsetattr(int fd, int action, const int64_t *in) {
    struct termios t;
    if (tcgetattr(fd, &t) != 0) return -1;
    t.c_iflag = (tcflag_t)in[0]; t.c_oflag = (tcflag_t)in[1];
    t.c_cflag = (tcflag_t)in[2]; t.c_lflag = (tcflag_t)in[3];
    if (cfsetispeed(&t, (speed_t)in[4]) != 0 || cfsetospeed(&t, (speed_t)in[5]) != 0) return -1;
    for (int i = 0; i < NCCS; i++) t.c_cc[i] = (cc_t)in[6 + i];
    return tcsetattr(fd, action, &t);
}

/* The other calls on a terminal: 0 tcdrain, 1 tcflush (argument: the queue),
   2 tcflow (the action), 3 tcsendbreak (the duration), 4 tcgetpgrp (gives
   the group), 5 tcsetpgrp (the group). -1 on failure. */
int64_t sys_tcop(int op, int fd, int64_t argument) {
    switch (op) {
    case 0: return tcdrain(fd);
    case 1: return tcflush(fd, (int)argument);
    case 2: return tcflow(fd, (int)argument);
    case 3: return tcsendbreak(fd, (int)argument);
    case 4: return (int64_t)tcgetpgrp(fd);
    case 5: return tcsetpgrp(fd, (pid_t)argument);
    default: errno = EINVAL; return -1;
    }
}

int sys_nccs(void) { return NCCS; }

/* fcntl with a struct flock: F_GETLK, F_SETLK or F_SETLKW. out is the lock
   afterwards: type, whence, start, length, pid. */
int sys_lock(int fd, int command, int type, int whence, int64_t start, int64_t length, int64_t out[5]) {
    struct flock lock;
    memset(&lock, 0, sizeof lock);
    lock.l_type = (short)type;
    lock.l_whence = (short)whence;
    lock.l_start = (off_t)start;
    lock.l_len = (off_t)length;
    int r;
    do { r = fcntl(fd, command, &lock); } while (r < 0 && errno == EINTR);
    if (r < 0) return -1;
    out[0] = lock.l_type;
    out[1] = lock.l_whence;
    out[2] = (int64_t)lock.l_start;
    out[3] = (int64_t)lock.l_len;
    out[4] = (int64_t)lock.l_pid;
    return 0;
}

/* pathconf of the path, or fpathconf of fd when path is NULL, for the name
   of a limit without its prefix ("LINK_MAX" is _PC_LINK_MAX). 0 and the value
   in *out, -1 in *out when there is no limit; -1 on failure. */
int sys_pathconf(const char *path, int fd, const char *name, int64_t *out) {
    char full[64];
    if (strlen(name) + 5 > sizeof full) { errno = EINVAL; return -1; }
    strcpy(full, "_PC_");
    strcat(full, name);
    int64_t which = sys_const(full);
    if (which < 0) { errno = EINVAL; return -1; }
    errno = 0;
    long v = path ? pathconf(path, (int)which) : fpathconf(fd, (int)which);
    if (v < 0 && errno != 0) return -1;
    *out = v < 0 ? -1 : (int64_t)v;
    return 0;
}
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

/* ---------------------------------------------------------------- sockets */
static char address[128];
static int address_length = 0;

const char *sys_last_addr(void) { return address; }
int sys_last_addr_len(void) { return address_length; }

int sys_socket(int domain, int type, int protocol) { return socket(domain, type, protocol); }

int sys_socketpair(int domain, int type, int protocol, int out[2]) {
    return socketpair(domain, type, protocol, out);
}

int sys_bind(int fd, const char *addr, int n) {
    return bind(fd, (const struct sockaddr *)addr, (socklen_t)n);
}

int sys_connect(int fd, const char *addr, int n) {
    return connect(fd, (const struct sockaddr *)addr, (socklen_t)n);
}

int sys_listen(int fd, int backlog) { return listen(fd, backlog); }
int sys_accept(int fd) { return accept(fd, NULL, NULL); }

/* A send to a peer that has gone fails with EPIPE (MSG_NOSIGNAL) instead of
   ending the program with SIGPIPE. */
#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0
#endif
int64_t sys_send(int fd, const char *buf, int64_t n, int flags) {
    return (int64_t)send(fd, buf, (size_t)n, flags | MSG_NOSIGNAL);
}

int64_t sys_sendto(int fd, const char *buf, int64_t n, int flags, const char *addr, int addrlen) {
    return (int64_t)sendto(fd, buf, (size_t)n, flags | MSG_NOSIGNAL, (const struct sockaddr *)addr, (socklen_t)addrlen);
}

/* errno is cleared first: nothing received is the end of the stream when it
   is still 0 afterwards, a failure otherwise. */
int64_t sys_recv(int fd, char *buf, int64_t n, int flags) {
    errno = 0;
    return (int64_t)recv(fd, buf, (size_t)n, flags);
}

int64_t sys_recvfrom(int fd, char *buf, int64_t n, int flags) {
    socklen_t len = sizeof address;
    errno = 0;
    ssize_t got = recvfrom(fd, buf, (size_t)n, flags, (struct sockaddr *)address, &len);
    address_length = got < 0 ? 0 : (int)len;
    return (int64_t)got;
}

int sys_shutdown(int fd, int how) { return shutdown(fd, how); }

int sys_sock_name(int fd) {
    socklen_t len = sizeof address;
    if (getsockname(fd, (struct sockaddr *)address, &len) != 0) return -1;
    address_length = (int)len;
    return 0;
}

int sys_sock_peer(int fd) {
    socklen_t len = sizeof address;
    if (getpeername(fd, (struct sockaddr *)address, &len) != 0) return -1;
    address_length = (int)len;
    return 0;
}

int sys_getsockopt(int fd, int level, int name) {
    int value = 0;
    socklen_t len = sizeof value;
    if (getsockopt(fd, level, name, &value, &len) != 0) return -1;
    return value;
}

int sys_setsockopt(int fd, int level, int name, int value) {
    return setsockopt(fd, level, name, &value, sizeof value);
}

/* SO_LINGER, a struct linger: set it when set is 1 (seconds < 0 turns
   lingering off); *seconds is what it is afterwards, -1 when off. */
int sys_linger(int fd, int set, int *seconds) {
    struct linger l;
    socklen_t len = sizeof l;
    if (set) {
        l.l_onoff = *seconds >= 0;
        l.l_linger = *seconds >= 0 ? *seconds : 0;
        if (setsockopt(fd, SOL_SOCKET, SO_LINGER, &l, sizeof l) != 0) return -1;
    }
    if (getsockopt(fd, SOL_SOCKET, SO_LINGER, &l, &len) != 0) return -1;
    *seconds = l.l_onoff ? l.l_linger : -1;
    return 0;
}

/* 0: the bytes that can be read at once (FIONREAD); 1: whether the socket
   is at the out-of-band mark. -1 on failure. */
int sys_socket_query(int fd, int what) {
    if (what == 0) {
        int n = 0;
        return ioctl(fd, FIONREAD, &n) == 0 ? n : -1;
    }
    if (what == 1) return sockatmark(fd);
    errno = EINVAL;
    return -1;
}

int sys_inet_addr(const char *host, int port) {
    struct sockaddr_in in;
    memset(&in, 0, sizeof in);
    in.sin_family = AF_INET;
    in.sin_port = htons((unsigned short)port);
    if (!host || !*host) in.sin_addr.s_addr = htonl(INADDR_ANY);
    else if (inet_pton(AF_INET, host, &in.sin_addr) != 1) { errno = EINVAL; return -1; }
    memcpy(address, &in, sizeof in);
    address_length = (int)sizeof in;
    return 0;
}

/* An IPv6 address, in the text form of inet_pton: "::1", "fe80::1%eth0" is
   not taken (no scope id). An empty host is the address of no interface. */
int sys_inet6_addr(const char *host, int port) {
    struct sockaddr_in6 in6;
    memset(&in6, 0, sizeof in6);
    in6.sin6_family = AF_INET6;
    in6.sin6_port = htons((unsigned short)port);
    if (!host || !*host) in6.sin6_addr = in6addr_any;
    else if (inet_pton(AF_INET6, host, &in6.sin6_addr) != 1) { errno = EINVAL; return -1; }
    memcpy(address, &in6, sizeof in6);
    address_length = (int)sizeof in6;
    return 0;
}

int sys_unix_addr(const char *path) {
    struct sockaddr_un un;
    memset(&un, 0, sizeof un);
    un.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof un.sun_path) { errno = ENAMETOOLONG; return -1; }
    strcpy(un.sun_path, path);
    size_t n = offsetof(struct sockaddr_un, sun_path) + strlen(path) + 1;
    memcpy(address, &un, n);
    address_length = (int)n;
    return 0;
}

int sys_addr_family(const char *addr, int n) {
    if (n < (int)sizeof(sa_family_t)) return -1;
    struct sockaddr sa;
    memcpy(&sa, addr, sizeof sa < (size_t)n ? sizeof sa : (size_t)n);
    return sa.sa_family;
}

const char *sys_inet_parts(const char *addr, int n, int *port) {
    if (n < (int)sizeof(struct sockaddr_in)) return NULL;
    struct sockaddr_in in;
    memcpy(&in, addr, sizeof in);
    if (in.sin_family != AF_INET) return NULL;
    if (!inet_ntop(AF_INET, &in.sin_addr, path_buffer, sizeof path_buffer)) return NULL;
    *port = ntohs(in.sin_port);
    return path_buffer;
}

const char *sys_inet6_parts(const char *addr, int n, int *port) {
    if (n < (int)sizeof(struct sockaddr_in6)) return NULL;
    struct sockaddr_in6 in6;
    memcpy(&in6, addr, sizeof in6);
    if (in6.sin6_family != AF_INET6) return NULL;
    if (!inet_ntop(AF_INET6, &in6.sin6_addr, path_buffer, sizeof path_buffer)) return NULL;
    *port = ntohs(in6.sin6_port);
    return path_buffer;
}

const char *sys_unix_path(const char *addr, int n) {
    if (n < (int)offsetof(struct sockaddr_un, sun_path)) return NULL;
    struct sockaddr_un un;
    memset(&un, 0, sizeof un);
    memcpy(&un, addr, (size_t)n < sizeof un ? (size_t)n : sizeof un);
    if (un.sun_family != AF_UNIX) return NULL;
    snprintf(path_buffer, sizeof path_buffer, "%s", un.sun_path);
    return path_buffer;
}

/* name, then the addresses or numbers, then the other names. */
static const char *pack(const char *first, char **rest, const char *second) {
    size_t at = 0;
    const char *parts[2] = { first, second };
    for (int i = 0; i < 2; i++) {
        if (!parts[i]) continue;
        size_t n = strlen(parts[i]);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, parts[i], n);
        at += n;
        strings[at++] = 0;
    }
    for (char **p = rest; p && *p; p++) {
        size_t n = strlen(*p);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, *p, n);
        at += n;
        strings[at++] = 0;
    }
    strings[at] = 0;
    return strings;
}

/* The addresses of a host go in one part, separated by spaces. */
static const char *pack_host(struct hostent *h) {
    if (!h) return NULL;
    char dotted[1024] = "";
    size_t at = 0;
    if (h->h_addrtype == AF_INET && h->h_addr_list)
        for (char **a = h->h_addr_list; *a; a++) {
            char one[INET_ADDRSTRLEN];
            if (!inet_ntop(AF_INET, *a, one, sizeof one)) continue;
            size_t n = strlen(one);
            if (at + n + 2 >= sizeof dotted) break;
            if (at > 0) dotted[at++] = ' ';
            memcpy(dotted + at, one, n + 1);
            at += n;
        }
    return pack(h->h_name, h->h_aliases, dotted);
}

const char *sys_host_byname(const char *name) { return pack_host(gethostbyname(name)); }

const char *sys_host_byaddr(const char *dotted) {
    struct in_addr in;
    if (inet_pton(AF_INET, dotted, &in) != 1) { errno = EINVAL; return NULL; }
    return pack_host(gethostbyaddr(&in, sizeof in, AF_INET));
}

const char *sys_hostname(void) {
    if (gethostname(path_buffer, sizeof path_buffer) != 0) return NULL;
    return path_buffer;
}

static const char *pack_proto(struct protoent *p) {
    if (!p) return NULL;
    char number[32];
    snprintf(number, sizeof number, "%d", p->p_proto);
    return pack(p->p_name, p->p_aliases, number);
}

const char *sys_proto_byname(const char *name) { return pack_proto(getprotobyname(name)); }
const char *sys_proto_bynumber(int number) { return pack_proto(getprotobynumber(number)); }

static const char *pack_serv(struct servent *s) {
    if (!s) return NULL;
    char number[32];
    snprintf(number, sizeof number, "%d", ntohs((unsigned short)s->s_port));
    /* the name, the port, the protocol, then the other names */
    size_t at = 0;
    const char *parts[3] = { s->s_name, number, s->s_proto };
    for (int i = 0; i < 3; i++) {
        size_t n = strlen(parts[i]);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, parts[i], n);
        at += n;
        strings[at++] = 0;
    }
    for (char **p = s->s_aliases; p && *p; p++) {
        size_t n = strlen(*p);
        if (at + n + 2 >= sizeof strings) break;
        memcpy(strings + at, *p, n);
        at += n;
        strings[at++] = 0;
    }
    strings[at] = 0;
    return strings;
}

const char *sys_serv_byname(const char *name, const char *protocol) {
    return pack_serv(getservbyname(name, protocol && *protocol ? protocol : NULL));
}

const char *sys_serv_byport(int port, const char *protocol) {
    return pack_serv(getservbyport(htons((unsigned short)port), protocol && *protocol ? protocol : NULL));
}

static int nosys(void) { errno = ENOSYS; return -1; }
#define NOSYS_INT nosys()
/* The structure Windows: Windows' own. */
int sys_win_reg_open(int key, const char *name, int access, int create, int64_t out[2]) {
    (void)key; (void)name; (void)access; (void)create; (void)out; return NOSYS_INT;
}
int sys_win_reg_close(int key) { (void)key; return NOSYS_INT; }
int sys_win_reg_delete(int key, const char *name, int value) { (void)key; (void)name; (void)value; return NOSYS_INT; }
const char *sys_win_reg_enum(int key, int index, int value) { (void)key; (void)index; (void)value; NOSYS_INT; return NULL; }
const char *sys_win_reg_query(int key, const char *name, int *type, int64_t *length) {
    (void)key; (void)name; (void)type; (void)length; NOSYS_INT; return NULL;
}
int sys_win_reg_set(int key, const char *name, int type, const char *data, int64_t length) {
    (void)key; (void)name; (void)type; (void)data; (void)length; return NOSYS_INT;
}
const char *sys_win_config(int what) { (void)what; NOSYS_INT; return NULL; }
const char *sys_win_version(int64_t out[4]) { (void)out; NOSYS_INT; return NULL; }
const char *sys_win_volume(const char *root, int64_t out[2]) { (void)root; (void)out; NOSYS_INT; return NULL; }
const char *sys_win_find_executable(const char *name) { (void)name; NOSYS_INT; return NULL; }
int sys_win_shell_execute(const char *file, const char *arg, int document) { (void)file; (void)arg; (void)document; return NOSYS_INT; }
int64_t sys_win_spawn(const char *command, const char *arg, const int fds[3]) { (void)command; (void)arg; (void)fds; return NOSYS_INT; }
int sys_win_wait(int64_t pid, int64_t *code) { (void)pid; (void)code; return NOSYS_INT; }
int sys_win_dde_start(const char *service, const char *topic) { (void)service; (void)topic; return NOSYS_INT; }
int sys_win_dde_execute(int info, const char *command, int retries, int64_t delay_ms) {
    (void)info; (void)command; (void)retries; (void)delay_ms; return NOSYS_INT;
}
int sys_win_dde_stop(int info) { (void)info; return NOSYS_INT; }

/* ---------------------------------------------------------- executable memory */
void *sys_code_alloc(size_t size) {
    void *p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    return p == MAP_FAILED ? NULL : p;
}
int sys_code_protect(void *code, size_t size, int executable) {
    return mprotect(code, size, executable ? PROT_READ | PROT_EXEC : PROT_READ | PROT_WRITE) == 0;
}
void sys_code_flush(void *code, size_t size) {
#if defined(__GNUC__)
    __builtin___clear_cache((char *)code, (char *)code + size);
#else
    (void)code; (void)size;
#endif
}
void sys_code_free(void *code, size_t size) { munmap(code, size); }
