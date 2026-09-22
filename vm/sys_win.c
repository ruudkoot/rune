/* The system layer for Windows (`make windows`, built with mingw-w64). It is
   not part of any other build: `make check` never compiles this file, and
   nothing else in the tree depends on it.

   What Windows has, this gives: the clock, the calendar, files and
   directories, descriptors, the environment, and running a command. What
   belongs to POSIX and has no Windows counterpart worth faking -- fork,
   signals, the terminal settings, users and groups, and the sockets -- fails
   with ENOSYS, as it does in `make vm SYS=none`, and the library turns that
   into OS.SysErr. A program of the language suite that only reads and writes
   files and asks the time runs here.

   Paths come to and from the library as the library writes them; the CRT of
   mingw takes both separators. */
#include "sys.h"

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include <io.h>
#include <direct.h>
#include <sys/stat.h>
#include <sys/utime.h>
#include <windows.h>

static int last = 0;
/* Rune's strings are bytes, and a program that writes "\n" means one byte:
   the C runtime of Windows would turn it into two on a stream opened in text
   mode, so every standard stream is put in binary mode before main runs. The
   files the library opens are opened binary already (sys_openf). */
__attribute__((constructor))
static void rune_binary_streams(void) {
    _setmode(_fileno(stdin), _O_BINARY);
    _setmode(_fileno(stdout), _O_BINARY);
    _setmode(_fileno(stderr), _O_BINARY);
}

static char path_buffer[MAX_PATH * 4];
/* Rune's OS.Path is the one of POSIX: it separates with "/" and knows no
   drive letter. Windows takes "/" everywhere the CRT is used, so every path
   this layer hands back is written that way and the library's own path
   operations work on it. A path the program gives is passed on as it is. */
static const char *forward(char *p) {
    for (char *c = p; *c; c++) if (*c == '\\') *c = '/';
    return p;
}
static int fail(void) { last = ENOSYS; return -1; }
/* the CRT left the reason in errno */
static int failed(void) { last = errno; return -1; }

int sys_errno(void) { return last; }
void sys_set_errno(int e) { last = e; }
const char *sys_error_msg(int e) { return strerror(e); }

/* The errno values mingw's CRT has, by name. */
#define ERRORS(E) \
    E(E2BIG) E(EACCES) E(EAGAIN) E(EBADF) E(EBUSY) E(ECHILD) E(EDEADLK) E(EDOM) \
    E(EEXIST) E(EFAULT) E(EFBIG) E(EILSEQ) E(EINTR) E(EINVAL) E(EIO) E(EISDIR) \
    E(EMFILE) E(EMLINK) E(ENAMETOOLONG) E(ENFILE) E(ENODEV) E(ENOENT) E(ENOEXEC) \
    E(ENOLCK) E(ENOMEM) E(ENOSPC) E(ENOSYS) E(ENOTDIR) E(ENOTEMPTY) E(ENOTTY) \
    E(ENXIO) E(EPERM) E(EPIPE) E(ERANGE) E(EROFS) E(ESPIPE) E(ESRCH) E(EXDEV)

const char *sys_error_name(int e) {
#define NAME(x) if (e == x) return #x;
    ERRORS(NAME)
#undef NAME
    return "";
}
int sys_error_of_name(const char *name) {
#define OF(x) if (strcmp(name, #x) == 0) return x;
    ERRORS(OF)
#undef OF
    return -1;
}

int64_t sys_time_now(void) {
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    /* 100-nanosecond ticks since 1601; 11644473600 seconds to 1970 */
    uint64_t ticks = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    return (int64_t)(ticks / 10) - 11644473600LL * 1000000;
}
static int64_t of_filetime(FILETIME ft) {
    uint64_t ticks = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    return (int64_t)(ticks / 10);
}
int64_t sys_time_user(void) {
    FILETIME creation, exited, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &creation, &exited, &kernel, &user))
        return (int64_t)clock() * 1000000 / CLOCKS_PER_SEC;
    return of_filetime(user);
}
int64_t sys_time_sys(void) {
    FILETIME creation, exited, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &creation, &exited, &kernel, &user)) return 0;
    return of_filetime(kernel);
}
void sys_time_sleep(int64_t microseconds) {
    if (microseconds <= 0) return;
    Sleep((DWORD)((microseconds + 999) / 1000));
}

int sys_date_parts(int64_t seconds, int local, int32_t parts[9]) {
    time_t t = (time_t)seconds;
    struct tm *tm = local ? localtime(&t) : gmtime(&t);
    if (tm == NULL) return -1;
    parts[0] = tm->tm_sec;  parts[1] = tm->tm_min;   parts[2] = tm->tm_hour;
    parts[3] = tm->tm_mday; parts[4] = tm->tm_mon;   parts[5] = tm->tm_year;
    parts[6] = tm->tm_wday; parts[7] = tm->tm_yday;  parts[8] = tm->tm_isdst;
    return 0;
}
int64_t sys_date_seconds(int32_t parts[9], int local) {
    struct tm tm;
    memset(&tm, 0, sizeof tm);
    tm.tm_sec = parts[0]; tm.tm_min = parts[1]; tm.tm_hour = parts[2];
    tm.tm_mday = parts[3]; tm.tm_mon = parts[4]; tm.tm_year = parts[5];
    tm.tm_isdst = local ? parts[8] : 0;
    time_t t = local ? mktime(&tm) : _mkgmtime(&tm);
    if (t == (time_t)-1) return failed();
    parts[0] = tm.tm_sec;  parts[1] = tm.tm_min;   parts[2] = tm.tm_hour;
    parts[3] = tm.tm_mday; parts[4] = tm.tm_mon;   parts[5] = tm.tm_year;
    parts[6] = tm.tm_wday; parts[7] = tm.tm_yday;  parts[8] = tm.tm_isdst;
    return (int64_t)t;
}
int sys_date_offset(int64_t seconds, int32_t *offset) {
    time_t t = (time_t)seconds;
    struct tm local, utc;
    if (localtime_s(&local, &t) != 0 || gmtime_s(&utc, &t) != 0) return failed();
    local.tm_isdst = 0; utc.tm_isdst = 0;
    time_t a = mktime(&local), b = mktime(&utc);
    if (a == (time_t)-1 || b == (time_t)-1) return failed();
    *offset = (int32_t)(a - b);
    return 0;
}
int sys_date_format(const char *format, const int32_t parts[9], int local, char *out, size_t n) {
    (void)local;
    struct tm tm;
    memset(&tm, 0, sizeof tm);
    tm.tm_sec = parts[0];  tm.tm_min = parts[1];   tm.tm_hour = parts[2];
    tm.tm_mday = parts[3]; tm.tm_mon = parts[4];   tm.tm_year = parts[5];
    tm.tm_wday = parts[6]; tm.tm_yday = parts[7];  tm.tm_isdst = parts[8];
    size_t k = strftime(out, n, format, &tm);
    if (k == 0 && format[0] != 0) { out[0] = 0; return 0; }
    return (int)k;
}

int sys_system(const char *command) {
    int r = system(command);
    return r < 0 ? failed() : r;
}
const char *sys_getenv(const char *name) { return getenv(name); }

int sys_mkdir(const char *path) { return _mkdir(path) == 0 ? 0 : failed(); }
int sys_rmdir(const char *path) { return _rmdir(path) == 0 ? 0 : failed(); }
int sys_chdir(const char *path) { return _chdir(path) == 0 ? 0 : failed(); }
const char *sys_getcwd(void) {
    if (!_getcwd(path_buffer, (int)sizeof path_buffer)) { failed(); return NULL; }
    return forward(path_buffer);
}
int sys_remove(const char *path) { return remove(path) == 0 ? 0 : failed(); }
int sys_rename(const char *from, const char *to) {
    /* rename() will not replace an existing file on Windows */
    if (MoveFileExA(from, to, MOVEFILE_REPLACE_EXISTING | MOVEFILE_COPY_ALLOWED)) return 0;
    errno = EACCES;
    return failed();
}
int sys_access(const char *path, int read, int write, int exec) {
    /* Windows has no execute bit: a file that exists is executable here */
    int mode = 0;
    if (read) mode |= 4;
    if (write) mode |= 2;
    (void)exec;
    return _access(path, mode) == 0 ? 1 : 0;
}
/* 0 regular, 1 directory, 2 symbolic link, 3 other. Windows reparse points
   are reported as links; _stat follows them, so both calls agree unless the
   file is one. */
int sys_file_kind(const char *path) {
    DWORD a = GetFileAttributesA(path);
    if (a == INVALID_FILE_ATTRIBUTES) { errno = ENOENT; return failed(); }
    if (a & FILE_ATTRIBUTE_DIRECTORY) return 1;
    return 0;
}
int sys_link_kind(const char *path) {
    DWORD a = GetFileAttributesA(path);
    if (a == INVALID_FILE_ATTRIBUTES) { errno = ENOENT; return failed(); }
    if (a & FILE_ATTRIBUTE_REPARSE_POINT) return 2;
    if (a & FILE_ATTRIBUTE_DIRECTORY) return 1;
    return 0;
}
int64_t sys_file_size(const char *path) {
    struct __stat64 st;
    if (_stat64(path, &st) != 0) return failed();
    return (int64_t)st.st_size;
}
int64_t sys_mod_time(const char *path) {
    struct __stat64 st;
    if (_stat64(path, &st) != 0) return failed();
    return (int64_t)st.st_mtime;
}
int sys_set_time(const char *path, int64_t seconds, int now) {
    struct __utimbuf64 t;
    if (now) seconds = sys_time_now() / 1000000;
    t.actime = (__time64_t)seconds;
    t.modtime = (__time64_t)seconds;
    return _utime64(path, &t) == 0 ? 0 : failed();
}
const char *sys_read_link(const char *path) { (void)path; fail(); return NULL; }
const char *sys_real_path(const char *path) {
    if (!_fullpath(path_buffer, path, sizeof path_buffer)) { failed(); return NULL; }
    if (GetFileAttributesA(path_buffer) == INVALID_FILE_ATTRIBUTES) { errno = ENOENT; failed(); return NULL; }
    return forward(path_buffer);
}
/* As mkstemp does for POSIX: a name in the directory Windows keeps for
   temporary files, and the file made so that the name is taken. tmpnam gives
   a name at the root of the current drive, which is usually not writable. */
const char *sys_tmp_name(void) {
    char dir[MAX_PATH + 1];
    DWORD n = GetTempPathA(sizeof dir, dir);
    if (n == 0 || n > MAX_PATH) { errno = ENOENT; failed(); return NULL; }
    char name[MAX_PATH + 1];
    if (GetTempFileNameA(dir, "rune", 0, name) == 0) { errno = EACCES; failed(); return NULL; }
    snprintf(path_buffer, sizeof path_buffer, "%s", name);
    return forward(path_buffer);
}
/* Windows has no inode: the volume and the file index of the handle name a
   file, which is what BY_HANDLE_FILE_INFORMATION gives. */
int sys_file_id(const char *path, int64_t *device, int64_t *inode) {
    HANDLE h = CreateFileA(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (h == INVALID_HANDLE_VALUE) { errno = ENOENT; return failed(); }
    BY_HANDLE_FILE_INFORMATION info;
    int ok = GetFileInformationByHandle(h, &info);
    CloseHandle(h);
    if (!ok) { errno = EIO; return failed(); }
    *device = (int64_t)info.dwVolumeSerialNumber;
    *inode = (int64_t)(((uint64_t)info.nFileIndexHigh << 32) | info.nFileIndexLow);
    return 0;
}
/* Directories, on FindFirstFile: a stream is a slot of this table. "." and
   ".." are left out, as readdir's caller expects of OS.FileSys.readDir. */
#define DIRS 64
static struct { int used; HANDLE find; WIN32_FIND_DATAA data; int pending; char pattern[MAX_PATH * 4]; } dirs[DIRS];

static int dir_start(int i) {
    dirs[i].find = FindFirstFileA(dirs[i].pattern, &dirs[i].data);
    if (dirs[i].find == INVALID_HANDLE_VALUE) { errno = ENOENT; return -1; }
    dirs[i].pending = 1;
    return 0;
}
int sys_open_dir(const char *path) {
    int i;
    for (i = 0; i < DIRS; i++) if (!dirs[i].used) break;
    if (i == DIRS) { errno = EMFILE; return failed(); }
    if (GetFileAttributesA(path) == INVALID_FILE_ATTRIBUTES) { errno = ENOENT; return failed(); }
    snprintf(dirs[i].pattern, sizeof dirs[i].pattern, "%s\\*", path);
    if (dir_start(i) != 0) return failed();
    dirs[i].used = 1;
    return i;
}
const char *sys_read_dir(int dir) {
    if (dir < 0 || dir >= DIRS || !dirs[dir].used) { errno = EBADF; failed(); return NULL; }
    for (;;) {
        if (!dirs[dir].pending) {
            if (!FindNextFileA(dirs[dir].find, &dirs[dir].data)) return NULL;
        }
        dirs[dir].pending = 0;
        const char *name = dirs[dir].data.cFileName;
        if (strcmp(name, ".") != 0 && strcmp(name, "..") != 0) return name;
    }
}
int sys_rewind_dir(int dir) {
    if (dir < 0 || dir >= DIRS || !dirs[dir].used) { errno = EBADF; return failed(); }
    FindClose(dirs[dir].find);
    return dir_start(dir) == 0 ? 0 : failed();
}
int sys_close_dir(int dir) {
    if (dir < 0 || dir >= DIRS || !dirs[dir].used) { errno = EBADF; return failed(); }
    FindClose(dirs[dir].find);
    dirs[dir].used = 0;
    return 0;
}

int sys_fileno(FILE *file) { return _fileno(file); }
int64_t sys_ftell(FILE *file) { __int64 r = _ftelli64(file); return r < 0 ? -1 : (int64_t)r; }
int sys_fseek(FILE *file, int64_t offset, int whence) {
    return _fseeki64(file, (__int64)offset, whence) == 0 ? 0 : -1;
}
/* 0 file, 1 directory, 2 symbolic link, 3 terminal, 4 pipe, 5 socket, 6 device */
int sys_desc_kind(int fd) {
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (h == INVALID_HANDLE_VALUE) { errno = EBADF; return failed(); }
    switch (GetFileType(h)) {
        case FILE_TYPE_DISK: return 0;
        case FILE_TYPE_CHAR: return _isatty(fd) ? 3 : 6;
        case FILE_TYPE_PIPE: return 4;
        default: return 6;
    }
}
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
/* the variables, each NUL-terminated, then an empty one */
static char environ_buffer[64 * 1024];
const char *sys_environ(void) {
    char *block = GetEnvironmentStringsA();
    if (!block) { errno = ENOMEM; failed(); return NULL; }
    size_t at = 0;
    for (char *v = block; *v; v += strlen(v) + 1) {
        size_t n = strlen(v);
        /* Windows keeps "=C:" and the like at the front: they are not variables */
        if (v[0] == '=') continue;
        if (at + n + 2 >= sizeof environ_buffer) break;
        memcpy(environ_buffer + at, v, n);
        at += n;
        environ_buffer[at++] = 0;
    }
    environ_buffer[at] = 0;
    FreeEnvironmentStringsA(block);
    return environ_buffer;
}
const char *sys_ctermid(void) { fail(); return NULL; }
const char *sys_ttyname(int fd) { (void)fd; fail(); return NULL; }
int sys_isatty(int fd) { return _isatty(fd) ? 1 : 0; }
int64_t sys_sysconf(const char *name) { (void)name; return fail(); }

/* The flags the library passes are POSIX's; mingw's CRT has the ones that
   mean anything here, and every file is opened in binary mode, because a
   stream of the library counts bytes. */
int sys_openf(const char *path, int flags, int mode) {
    int f = _O_BINARY;
    if (flags & 1) f |= _O_WRONLY;
    else if (flags & 2) f |= _O_RDWR;
    else f |= _O_RDONLY;
    if (flags & 0100) f |= _O_CREAT;
    if (flags & 01000) f |= _O_TRUNC;
    if (flags & 02000) f |= _O_APPEND;
    if (flags & 0200) f |= _O_EXCL;
    int fd = _open(path, f, mode ? mode : _S_IREAD | _S_IWRITE);
    return fd < 0 ? failed() : fd;
}
int sys_close_fd(int fd) { return _close(fd) == 0 ? 0 : failed(); }
int sys_dup(int fd) { int r = _dup(fd); return r < 0 ? failed() : r; }
int sys_dup2(int fd, int to) { return _dup2(fd, to) == 0 ? to : failed(); }
int sys_pipe(int out[2]) { return _pipe(out, 65536, _O_BINARY) == 0 ? 0 : failed(); }
int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    int r = _read(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    return r < 0 ? failed() : r;
}
int64_t sys_write_fd(int fd, const char *buf, int64_t n) {
    int r = _write(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    return r < 0 ? failed() : r;
}
int64_t sys_lseek_fd(int fd, int64_t offset, int whence) {
    __int64 r = _lseeki64(fd, offset, whence);
    return r < 0 ? failed() : (int64_t)r;
}
int sys_fsync(int fd) { return _commit(fd) == 0 ? 0 : failed(); }
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
    struct __utimbuf64 t;
    t.actime = (__time64_t)access;
    t.modtime = (__time64_t)modification;
    return _utime64(path, &t) == 0 ? 0 : failed();
}
int sys_ftruncate(int fd, int64_t length) { return _chsize_s(fd, length) == 0 ? 0 : failed(); }
/* kind, mode, inode, device, links, user, group, size, access, modification,
   change. Windows has no inode, user or group: they are 0. */
int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]) {
    (void)follow;
    struct __stat64 st;
    if (path ? _stat64(path, &st) != 0 : _fstat64(fd, &st) != 0) return failed();
    int kind = (st.st_mode & _S_IFDIR) ? 1 : (st.st_mode & _S_IFCHR) ? 6 : 0;
    out[0] = kind;
    out[1] = (int64_t)(st.st_mode & 0777);
    out[2] = 0;
    out[3] = (int64_t)st.st_dev;
    out[4] = (int64_t)st.st_nlink;
    out[5] = 0;
    out[6] = 0;
    out[7] = (int64_t)st.st_size;
    out[8] = (int64_t)st.st_atime;
    out[9] = (int64_t)st.st_mtime;
    out[10] = (int64_t)st.st_ctime;
    return 0;
}
/* Windows has only the read-only bit of a file mode. */
int sys_chmod(const char *path, int fd, int mode) {
    (void)fd;
    if (!path) { errno = ENOSYS; return failed(); }
    return _chmod(path, (mode & 0200) ? _S_IREAD | _S_IWRITE : _S_IREAD) == 0 ? 0 : failed();
}
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
int sys_inet6_addr(const char *h, int p) { (void)h; (void)p; return fail(); }
int sys_unix_addr(const char *p) { (void)p; return fail(); }
int sys_addr_family(const char *a, int n) { (void)a; (void)n; return fail(); }
const char *sys_inet_parts(const char *a, int n, int *p) { (void)a; (void)n; (void)p; fail(); return NULL; }
const char *sys_inet6_parts(const char *a, int n, int *p) { (void)a; (void)n; (void)p; fail(); return NULL; }
const char *sys_unix_path(const char *a, int n) { (void)a; (void)n; fail(); return NULL; }
const char *sys_host_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_host_byaddr(const char *d) { (void)d; fail(); return NULL; }
const char *sys_hostname(void) { fail(); return NULL; }
const char *sys_proto_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_proto_bynumber(int n) { (void)n; fail(); return NULL; }
const char *sys_serv_byname(const char *n, const char *p) { (void)n; (void)p; fail(); return NULL; }
const char *sys_serv_byport(int p, const char *pr) { (void)p; (void)pr; fail(); return NULL; }
