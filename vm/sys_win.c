/* The system layer for Windows (`make windows`, built with mingw-w64). It is
   not part of any other build: `make check` never compiles this file, and
   nothing else in the tree depends on it.

   What Windows has, this gives: the clock, the calendar, files and
   directories, descriptors, the environment, running a command, the named
   constants and errors of POSIX (numbered as Linux numbers them where this
   layer decodes them itself, as Winsock does where they go to Winsock), and
   the addresses of sockets. What it does not do yet fails with ENOSYS, as in
   `make vm SYS=none`, and the library turns that into OS.SysErr;
   docs/plans/windows.md says which milestone takes what, and
   tests/basis/deviations.txt which checks of the suite fail meanwhile.

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
/* Winsock before windows.h, which would bring in its first version */
#include <winsock2.h>
#include <ws2tcpip.h>
#include <afunix.h>
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
/* The errors of POSIX, as mingw numbers them: msvcrt's own below 100, the
   rest (the sockets' among them) from 100 as the later runtime of Microsoft
   has them. Three that mingw does not name get numbers of their own. The
   texts are glibc's, so that OS.errorMsg says the same as on Linux: msvcrt
   has none from 100 on. */
#ifndef EDQUOT
#define EDQUOT 150
#endif
#ifndef EMULTIHOP
#define EMULTIHOP 151
#endif
#ifndef ESTALE
#define ESTALE 152
#endif
static const struct { const char *name; int number; const char *text; } errors[] = {
#define E(n, t) { #n, n, t },
    E(E2BIG, "Argument list too long") E(EACCES, "Permission denied")
    E(EADDRINUSE, "Address already in use") E(EADDRNOTAVAIL, "Cannot assign requested address")
    E(EAFNOSUPPORT, "Address family not supported by protocol")
    E(EAGAIN, "Resource temporarily unavailable") E(EWOULDBLOCK, "Resource temporarily unavailable")
    E(EALREADY, "Operation already in progress") E(EBADF, "Bad file descriptor")
    E(EBADMSG, "Bad message") E(EBUSY, "Device or resource busy") E(ECANCELED, "Operation canceled")
    E(ECHILD, "No child processes") E(ECONNABORTED, "Software caused connection abort")
    E(ECONNREFUSED, "Connection refused") E(ECONNRESET, "Connection reset by peer")
    E(EDEADLK, "Resource deadlock avoided") E(EDESTADDRREQ, "Destination address required")
    E(EDOM, "Numerical argument out of domain") E(EDQUOT, "Disk quota exceeded")
    E(EEXIST, "File exists") E(EFAULT, "Bad address") E(EFBIG, "File too large")
    E(EHOSTUNREACH, "No route to host") E(EIDRM, "Identifier removed")
    E(EILSEQ, "Invalid or incomplete multibyte or wide character")
    E(EINPROGRESS, "Operation now in progress") E(EINTR, "Interrupted system call")
    E(EINVAL, "Invalid argument") E(EIO, "Input/output error")
    E(EISCONN, "Transport endpoint is already connected") E(EISDIR, "Is a directory")
    E(ELOOP, "Too many levels of symbolic links") E(EMFILE, "Too many open files")
    E(EMLINK, "Too many links") E(EMSGSIZE, "Message too long") E(EMULTIHOP, "Multihop attempted")
    E(ENAMETOOLONG, "File name too long") E(ENETDOWN, "Network is down")
    E(ENETRESET, "Network dropped connection on reset") E(ENETUNREACH, "Network is unreachable")
    E(ENFILE, "Too many open files in system") E(ENOBUFS, "No buffer space available")
    E(ENODEV, "No such device") E(ENOENT, "No such file or directory")
    E(ENOEXEC, "Exec format error") E(ENOLCK, "No locks available")
    E(ENOLINK, "Link has been severed") E(ENOMEM, "Cannot allocate memory")
    E(ENOMSG, "No message of desired type") E(ENOPROTOOPT, "Protocol not available")
    E(ENOSPC, "No space left on device") E(ENOSYS, "Function not implemented")
    E(ENOTCONN, "Transport endpoint is not connected") E(ENOTDIR, "Not a directory")
    E(ENOTEMPTY, "Directory not empty") E(ENOTSOCK, "Socket operation on non-socket")
    E(ENOTSUP, "Operation not supported") E(ENOTTY, "Inappropriate ioctl for device")
    E(ENXIO, "No such device or address") E(EOVERFLOW, "Value too large for defined data type")
    E(EPERM, "Operation not permitted") E(EPIPE, "Broken pipe") E(EPROTO, "Protocol error")
    E(EPROTONOSUPPORT, "Protocol not supported") E(EPROTOTYPE, "Protocol wrong type for socket")
    E(ERANGE, "Numerical result out of range") E(EROFS, "Read-only file system")
    E(ESPIPE, "Illegal seek") E(ESRCH, "No such process") E(ESTALE, "Stale file handle")
    E(ETIMEDOUT, "Connection timed out") E(ETXTBSY, "Text file busy")
    E(EXDEV, "Invalid cross-device link")
#undef E
};
#define N_ERRORS (sizeof errors / sizeof errors[0])

const char *sys_error_msg(int e) {
    for (size_t i = 0; i < N_ERRORS; i++) if (errors[i].number == e) return errors[i].text;
    return strerror(e);
}
const char *sys_error_name(int e) {
    for (size_t i = 0; i < N_ERRORS; i++) if (errors[i].number == e) return errors[i].name;
    return "";
}
int sys_error_of_name(const char *name) {
    for (size_t i = 0; i < N_ERRORS; i++) if (strcmp(errors[i].name, name) == 0) return errors[i].number;
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

/* The calendar goes through the functions of msvcrt that are 64 bits wide
   by name: time_t is 32 bits in the 32-bit msvcrt, and would end in 2038. */
int sys_date_parts(int64_t seconds, int local, int32_t parts[9]) {
    __time64_t t = (__time64_t)seconds;
    struct tm tm;
    if ((local ? _localtime64_s(&tm, &t) : _gmtime64_s(&tm, &t)) != 0) return -1;
    parts[0] = tm.tm_sec;  parts[1] = tm.tm_min;   parts[2] = tm.tm_hour;
    parts[3] = tm.tm_mday; parts[4] = tm.tm_mon;   parts[5] = tm.tm_year;
    parts[6] = tm.tm_wday; parts[7] = tm.tm_yday;  parts[8] = tm.tm_isdst;
    return 0;
}
int64_t sys_date_seconds(int32_t parts[9], int local) {
    struct tm tm;
    memset(&tm, 0, sizeof tm);
    tm.tm_sec = parts[0]; tm.tm_min = parts[1]; tm.tm_hour = parts[2];
    tm.tm_mday = parts[3]; tm.tm_mon = parts[4]; tm.tm_year = parts[5];
    tm.tm_isdst = local ? parts[8] : 0;
    __time64_t t = local ? _mktime64(&tm) : _mkgmtime64(&tm);
    if (t == (__time64_t)-1) return failed();
    parts[0] = tm.tm_sec;  parts[1] = tm.tm_min;   parts[2] = tm.tm_hour;
    parts[3] = tm.tm_mday; parts[4] = tm.tm_mon;   parts[5] = tm.tm_year;
    parts[6] = tm.tm_wday; parts[7] = tm.tm_yday;  parts[8] = tm.tm_isdst;
    return (int64_t)t;
}
int sys_date_offset(int64_t seconds, int32_t *offset) {
    __time64_t t = (__time64_t)seconds;
    struct tm local, utc;
    if (_localtime64_s(&local, &t) != 0 || _gmtime64_s(&utc, &t) != 0) return failed();
    local.tm_isdst = 0; utc.tm_isdst = 0;
    __time64_t a = _mktime64(&local), b = _mktime64(&utc);
    if (a == (__time64_t)-1 || b == (__time64_t)-1) return failed();
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
/* The times of a file are read and set as Windows keeps them, in UTC:
   msvcrt's _stat64 and _utime64 go through the local time of TZ, and when TZ
   names another zone than the system's the times they give are off by the
   difference. */
static int64_t filetime_seconds(FILETIME ft) {
    uint64_t ticks = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    return (int64_t)(ticks / 10000000) - 11644473600LL;
}
static FILETIME seconds_filetime(int64_t seconds) {
    uint64_t ticks = (uint64_t)(seconds + 11644473600LL) * 10000000;
    FILETIME ft;
    ft.dwLowDateTime = (DWORD)ticks;
    ft.dwHighDateTime = (DWORD)(ticks >> 32);
    return ft;
}
/* access, modification and creation (which msvcrt gives as the change) */
static int file_times(const char *path, int fd, int64_t out[3]) {
    FILETIME a, m, c;
    if (path) {
        WIN32_FILE_ATTRIBUTE_DATA d;
        if (!GetFileAttributesExA(path, GetFileExInfoStandard, &d)) { errno = ENOENT; return -1; }
        a = d.ftLastAccessTime; m = d.ftLastWriteTime; c = d.ftCreationTime;
    } else {
        HANDLE h = (HANDLE)_get_osfhandle(fd);
        if (h == INVALID_HANDLE_VALUE || !GetFileTime(h, &c, &a, &m)) { errno = EBADF; return -1; }
    }
    out[0] = filetime_seconds(a); out[1] = filetime_seconds(m); out[2] = filetime_seconds(c);
    return 0;
}
static int set_file_times(const char *path, int64_t access, int64_t modification) {
    /* FILE_FLAG_BACKUP_SEMANTICS opens a directory too */
    HANDLE h = CreateFileA(path, FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (h == INVALID_HANDLE_VALUE) {
        errno = GetLastError() == ERROR_ACCESS_DENIED ? EACCES : ENOENT;
        return failed();
    }
    FILETIME a = seconds_filetime(access), m = seconds_filetime(modification);
    int ok = SetFileTime(h, NULL, &a, &m);
    CloseHandle(h);
    if (!ok) { errno = EACCES; return failed(); }
    return 0;
}
int64_t sys_mod_time(const char *path) {
    int64_t t[3];
    if (file_times(path, -1, t) != 0) return failed();
    return t[1];
}
int sys_set_time(const char *path, int64_t seconds, int now) {
    if (now) seconds = sys_time_now() / 1000000;
    return set_file_times(path, seconds, seconds);
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
/* The end of a directory is NULL with the error cleared, as POSIX's readdir
   leaves it: the library tells the end from a failure by it. */
const char *sys_read_dir(int dir) {
    last = 0;
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
/* A file on disk is always ready, for reading and for writing, as POSIX's
   poll says of a regular file; nothing else can be waited for yet. No
   descriptors at all is a wait for the time given. */
int sys_poll(const int *fds, int *events, int n, int64_t microseconds) {
    int ready = 0;
    for (int i = 0; i < n; i++) {
        HANDLE h = (HANDLE)_get_osfhandle(fds[i]);
        if (h == INVALID_HANDLE_VALUE) { errno = EBADF; return failed(); }
        if (GetFileType(h) != FILE_TYPE_DISK) return fail();
    }
    for (int i = 0; i < n; i++) {
        events[i] &= 1 | 2;
        if (events[i]) ready++;
    }
    if (ready == 0) {
        if (microseconds < 0) Sleep(INFINITE);
        else sys_time_sleep(microseconds);
    }
    return ready;
}

/* The named constants. What this layer decodes or emulates itself has the
   numbers of Linux: the flags of open (sys_openf), of fcntl, of waitpid,
   and the signals. What goes to Winsock unchanged has Winsock's numbers.
   The errors are the table above. The terminal's size of the control
   characters, NCCS, is left out: it is sys_nccs, 0 here. */
static const struct { const char *name; int64_t value; } constants[] = {
    /* signals */
    { "SIGHUP", 1 }, { "SIGINT", 2 }, { "SIGQUIT", 3 }, { "SIGILL", 4 }, { "SIGABRT", 6 },
    { "SIGBUS", 7 }, { "SIGFPE", 8 }, { "SIGKILL", 9 }, { "SIGUSR1", 10 }, { "SIGSEGV", 11 },
    { "SIGUSR2", 12 }, { "SIGPIPE", 13 }, { "SIGALRM", 14 }, { "SIGTERM", 15 }, { "SIGCHLD", 17 },
    { "SIGCONT", 18 }, { "SIGSTOP", 19 }, { "SIGTSTP", 20 }, { "SIGTTIN", 21 }, { "SIGTTOU", 22 },
    /* opening a file */
    { "O_RDONLY", 0 }, { "O_WRONLY", 1 }, { "O_RDWR", 2 }, { "O_CREAT", 0100 }, { "O_EXCL", 0200 },
    { "O_NOCTTY", 0400 }, { "O_TRUNC", 01000 }, { "O_APPEND", 02000 }, { "O_NONBLOCK", 04000 },
    { "O_SYNC", 04010000 },
    /* the bits of a file mode */
    { "S_IRUSR", 0400 }, { "S_IWUSR", 0200 }, { "S_IXUSR", 0100 }, { "S_IRWXU", 0700 },
    { "S_IRGRP", 040 }, { "S_IWGRP", 020 }, { "S_IXGRP", 010 }, { "S_IRWXG", 070 },
    { "S_IROTH", 04 }, { "S_IWOTH", 02 }, { "S_IXOTH", 01 }, { "S_IRWXO", 07 },
    { "S_ISUID", 04000 }, { "S_ISGID", 02000 },
    /* where a seek starts, what fcntl does, how to wait */
    { "SEEK_SET", 0 }, { "SEEK_CUR", 1 }, { "SEEK_END", 2 },
    { "F_DUPFD", 0 }, { "F_GETFD", 1 }, { "F_SETFD", 2 }, { "F_GETFL", 3 }, { "F_SETFL", 4 },
    { "F_GETLK", 5 }, { "F_SETLK", 6 }, { "F_SETLKW", 7 }, { "FD_CLOEXEC", 1 },
    { "F_RDLCK", 0 }, { "F_WRLCK", 1 }, { "F_UNLCK", 2 },
    { "WNOHANG", 1 }, { "WUNTRACED", 2 },
    /* the terminal (Posix.TTY) */
    { "BRKINT", 2 }, { "ICRNL", 256 }, { "IGNBRK", 1 }, { "IGNCR", 128 }, { "IGNPAR", 4 },
    { "INLCR", 64 }, { "INPCK", 16 }, { "ISTRIP", 32 }, { "IXOFF", 4096 }, { "IXON", 1024 },
    { "PARMRK", 8 }, { "OPOST", 1 }, { "CLOCAL", 2048 }, { "CREAD", 128 }, { "CS5", 0 },
    { "CS6", 16 }, { "CS7", 32 }, { "CS8", 48 }, { "CSIZE", 48 }, { "CSTOPB", 64 },
    { "HUPCL", 1024 }, { "PARENB", 256 }, { "PARODD", 512 }, { "ECHO", 8 }, { "ECHOE", 16 },
    { "ECHOK", 32 }, { "ECHONL", 64 }, { "ICANON", 2 }, { "IEXTEN", 32768 }, { "ISIG", 1 },
    { "NOFLSH", 128 }, { "TOSTOP", 256 }, { "VEOF", 4 }, { "VEOL", 11 }, { "VERASE", 2 },
    { "VINTR", 0 }, { "VKILL", 3 }, { "VMIN", 6 }, { "VQUIT", 1 }, { "VSUSP", 10 },
    { "VTIME", 5 }, { "VSTART", 8 }, { "VSTOP", 9 },
    { "B0", 0 }, { "B50", 1 }, { "B75", 2 }, { "B110", 3 }, { "B134", 4 }, { "B150", 5 },
    { "B200", 6 }, { "B300", 7 }, { "B600", 8 }, { "B1200", 9 }, { "B1800", 10 }, { "B2400", 11 },
    { "B4800", 12 }, { "B9600", 13 }, { "B19200", 14 }, { "B38400", 15 },
    { "TCSANOW", 0 }, { "TCSADRAIN", 1 }, { "TCSAFLUSH", 2 }, { "TCOOFF", 0 }, { "TCOON", 1 },
    { "TCIOFF", 2 }, { "TCION", 3 }, { "TCIFLUSH", 0 }, { "TCOFLUSH", 1 }, { "TCIOFLUSH", 2 },
    /* sockets, as Winsock numbers them */
#define C(n) { #n, (int64_t)n },
    C(AF_INET) C(AF_INET6) C(AF_UNIX) C(SOCK_STREAM) C(SOCK_DGRAM) C(SOL_SOCKET)
    C(SO_DEBUG) C(SO_REUSEADDR) C(SO_KEEPALIVE) C(SO_DONTROUTE) C(SO_LINGER)
    C(SO_BROADCAST) C(SO_OOBINLINE) C(SO_SNDBUF) C(SO_RCVBUF) C(SO_TYPE) C(SO_ERROR)
    C(MSG_OOB) C(MSG_PEEK) C(MSG_DONTROUTE) C(IPPROTO_TCP) C(TCP_NODELAY)
#undef C
    { "SHUT_RD", SD_RECEIVE }, { "SHUT_WR", SD_SEND }, { "SHUT_RDWR", SD_BOTH },
};

int64_t sys_const(const char *name) {
    for (size_t i = 0; i < sizeof constants / sizeof constants[0]; i++)
        if (strcmp(constants[i].name, name) == 0) return constants[i].value;
    return sys_error_of_name(name);
}
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
int64_t sys_sysconf(const char *name) { (void)name; last = 0; return fail(); }

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
/* the end of a file is 0 bytes with the error cleared, as on POSIX */
int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    last = 0;
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
    (void)path; (void)fd; (void)name; (void)out; last = 0; return fail();
}
int sys_tcgetattr(int fd, int64_t *out) { (void)fd; (void)out; return fail(); }
int sys_tcsetattr(int fd, int action, const int64_t *in) { (void)fd; (void)action; (void)in; return fail(); }
int64_t sys_tcop(int op, int fd, int64_t argument) { (void)op; (void)fd; (void)argument; return fail(); }
int sys_nccs(void) { return 0; }
int sys_linger(int fd, int set, int *seconds) { (void)fd; (void)set; (void)seconds; return fail(); }
int sys_socket_query(int fd, int what) { (void)fd; (void)what; return fail(); }
int sys_utime(const char *path, int64_t access, int64_t modification) {
    return set_file_times(path, access, modification);
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
    int64_t t[3];
    if (file_times(path, fd, t) != 0) return failed();
    out[8] = t[0];
    out[9] = t[1];
    out[10] = t[2];
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
int64_t sys_recv(int fd, char *b, int64_t n, int f) { (void)fd; (void)b; (void)n; (void)f; last = 0; return fail(); }
int64_t sys_recvfrom(int fd, char *b, int64_t n, int f) { (void)fd; (void)b; (void)n; (void)f; last = 0; return fail(); }
int sys_shutdown(int fd, int how) { (void)fd; (void)how; return fail(); }
int sys_sock_name(int fd) { (void)fd; return fail(); }
int sys_sock_peer(int fd) { (void)fd; return fail(); }
/* The addresses of sockets are the bytes of a sockaddr of Winsock, which has
   the layout of POSIX's (family, then port and address); making and taking
   them apart needs no socket. */
static char address[128];
static int address_length = 0;
const char *sys_last_addr(void) { return address; }
int sys_last_addr_len(void) { return address_length; }
/* Winsock is started the first time something of it is used. */
static int winsock(void) {
    static int started = 0;
    if (!started) {
        WSADATA data;
        if (WSAStartup(MAKEWORD(2, 2), &data) != 0) { last = ENOSYS; return -1; }
        started = 1;
    }
    return 0;
}
int sys_getsockopt(int fd, int l, int n) { (void)fd; (void)l; (void)n; return fail(); }
int sys_setsockopt(int fd, int l, int n, int v) { (void)fd; (void)l; (void)n; (void)v; return fail(); }
int sys_inet_addr(const char *host, int port) {
    struct sockaddr_in in;
    if (winsock() != 0) return -1;
    memset(&in, 0, sizeof in);
    in.sin_family = AF_INET;
    in.sin_port = htons((unsigned short)port);
    if (!host || !*host) in.sin_addr.s_addr = htonl(INADDR_ANY);
    else if (inet_pton(AF_INET, host, &in.sin_addr) != 1) { last = EINVAL; return -1; }
    memcpy(address, &in, sizeof in);
    address_length = (int)sizeof in;
    return 0;
}
/* no scope id is taken, as on POSIX */
int sys_inet6_addr(const char *host, int port) {
    struct sockaddr_in6 in6;
    if (winsock() != 0) return -1;
    memset(&in6, 0, sizeof in6);
    in6.sin6_family = AF_INET6;
    in6.sin6_port = htons((unsigned short)port);
    if (!host || !*host) in6.sin6_addr = in6addr_any;
    else if (inet_pton(AF_INET6, host, &in6.sin6_addr) != 1) { last = EINVAL; return -1; }
    memcpy(address, &in6, sizeof in6);
    address_length = (int)sizeof in6;
    return 0;
}
int sys_unix_addr(const char *path) {
    struct sockaddr_un un;
    memset(&un, 0, sizeof un);
    un.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof un.sun_path) { last = ENAMETOOLONG; return -1; }
    strcpy(un.sun_path, path);
    size_t n = offsetof(struct sockaddr_un, sun_path) + strlen(path) + 1;
    memcpy(address, &un, n);
    address_length = (int)n;
    return 0;
}
int sys_addr_family(const char *addr, int n) {
    unsigned short family;
    if (n < (int)sizeof family) { last = EINVAL; return -1; }
    memcpy(&family, addr, sizeof family);
    return family;
}
const char *sys_inet_parts(const char *addr, int n, int *port) {
    struct sockaddr_in in;
    if (n < (int)sizeof in || winsock() != 0) return NULL;
    memcpy(&in, addr, sizeof in);
    if (in.sin_family != AF_INET) return NULL;
    if (!inet_ntop(AF_INET, &in.sin_addr, path_buffer, sizeof path_buffer)) return NULL;
    *port = ntohs(in.sin_port);
    return path_buffer;
}
const char *sys_inet6_parts(const char *addr, int n, int *port) {
    struct sockaddr_in6 in6;
    if (n < (int)sizeof in6 || winsock() != 0) return NULL;
    memcpy(&in6, addr, sizeof in6);
    if (in6.sin6_family != AF_INET6) return NULL;
    if (!inet_ntop(AF_INET6, &in6.sin6_addr, path_buffer, sizeof path_buffer)) return NULL;
    *port = ntohs(in6.sin6_port);
    return path_buffer;
}
const char *sys_unix_path(const char *addr, int n) {
    struct sockaddr_un un;
    if (n < (int)offsetof(struct sockaddr_un, sun_path)) return NULL;
    memset(&un, 0, sizeof un);
    memcpy(&un, addr, (size_t)n < sizeof un ? (size_t)n : sizeof un);
    if (un.sun_family != AF_UNIX) return NULL;
    snprintf(path_buffer, sizeof path_buffer, "%s", un.sun_path);
    return path_buffer;
}
const char *sys_host_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_host_byaddr(const char *d) { (void)d; fail(); return NULL; }
const char *sys_hostname(void) { fail(); return NULL; }
const char *sys_proto_byname(const char *n) { (void)n; fail(); return NULL; }
const char *sys_proto_bynumber(int n) { (void)n; fail(); return NULL; }
const char *sys_serv_byname(const char *n, const char *p) { (void)n; (void)p; fail(); return NULL; }
const char *sys_serv_byport(int p, const char *pr) { (void)p; (void)pr; fail(); return NULL; }
