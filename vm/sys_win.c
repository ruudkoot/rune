/* The system layer for Windows (`make windows`, built with mingw-w64). It is
   not part of any other build: `make check` never compiles this file, and
   nothing else in the tree depends on it.

   What Windows has, this gives: the clock, the calendar, files and
   directories with their links, descriptors, the environment, running a
   command, the named constants and errors of POSIX (numbered as Linux
   numbers them where this layer decodes them itself, as Winsock does where
   they go to Winsock), the sockets, which are Winsock's, the user and groups
   of the process, and the console as a terminal. A path of a drive goes to
   the library as /C:/... (the section on paths says why). What it does not
   do fails with ENOSYS, as in `make vm SYS=none`, and the library turns that
   into OS.SysErr; docs/plans/windows.md says which milestone takes what, and
   tests/basis/deviations.txt which checks of the suite fail. */
#include "sys.h"

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
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
#include <mstcpip.h>
#include <tlhelp32.h>
#ifndef SIO_UDP_CONNRESET
#define SIO_UDP_CONNRESET _WSAIOW(IOC_VENDOR, 12)
#endif
#include <windows.h>
#include <shellapi.h>
#include <ddeml.h>

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

/* ---------------------------------------------------------------- sockets */
/* A socket of Winsock is a SOCKET, not a descriptor of the C runtime, while
   the library holds every descriptor as an int (lib/basis/socket.sml). So a
   socket gets a number of its own, SOCKET_BASE and its slot in this table,
   which no descriptor of the C runtime reaches, and every call that takes a
   descriptor looks here first. Winsock cannot say whether a socket blocks,
   so the table remembers it; close-on-exec is kept here too, for M7, and
   SO_REUSEADDR (sys_setsockopt). So are how the socket was made and the
   options set on it, for sys_connect to make it again. */
#define SOCKET_BASE 0x40000000
#define SOCK_OPTIONS 16
typedef struct { int level, name, value; } SockOption;
typedef struct {
    SOCKET s;
    int used, nonblocking, cloexec, reuseaddr;
    int domain, type, protocol, bound, noptions;
    int pair;                  /* made by sys_socketpair: its addresses are unnamed */
    int connected;             /* a datagram socket given a peer by sys_connect */
    SockOption options[SOCK_OPTIONS];
} Sock;
static Sock *socks = NULL;
static int nsocks = 0, socks_cap = 0;

static Sock *sock_of(int fd) {
    if (fd < SOCKET_BASE || fd - SOCKET_BASE >= nsocks) return NULL;
    Sock *s = &socks[fd - SOCKET_BASE];
    return s->used ? s : NULL;
}
/* the lowest free number, as POSIX gives descriptors */
static int new_sock(SOCKET s) {
    int i;
    for (i = 0; i < nsocks; i++) if (!socks[i].used) break;
    if (i == nsocks) {
        if (nsocks == socks_cap) {
            int cap = socks_cap ? socks_cap * 2 : 16;
            Sock *bigger = realloc(socks, (size_t)cap * sizeof *socks);
            if (!bigger) { closesocket(s); last = ENOMEM; return -1; }
            socks = bigger;
            socks_cap = cap;
        }
        nsocks++;
    }
    socks[i].s = s;
    socks[i].used = 1;
    socks[i].nonblocking = 0;
    socks[i].cloexec = 0;
    socks[i].reuseaddr = 0;
    socks[i].domain = socks[i].type = socks[i].protocol = -1;
    socks[i].bound = 0;
    socks[i].noptions = 0;
    socks[i].pair = 0;
    socks[i].connected = 0;
    return SOCKET_BASE + i;
}

/* Winsock is started the first time something of it is used: vm/sys.h has
   no call for starting. */
static int winsock(void) {
    static int started = 0;
    if (!started) {
        WSADATA data;
        if (WSAStartup(MAKEWORD(2, 2), &data) != 0) { last = ENOSYS; return -1; }
        started = 1;
    }
    return 0;
}

/* The error of the last call of Winsock, as the errno of POSIX. */
static int errno_of_wsa(int e) {
    switch (e) {
    case WSAEINTR: return EINTR;              case WSAEBADF: return EBADF;
    case WSAEACCES: return EACCES;            case WSAEFAULT: return EFAULT;
    case WSAEINVAL: return EINVAL;            case WSAEMFILE: return EMFILE;
    case WSAEWOULDBLOCK: return EWOULDBLOCK;  case WSAEINPROGRESS: return EINPROGRESS;
    case WSAEALREADY: return EALREADY;        case WSAENOTSOCK: return ENOTSOCK;
    case WSAEDESTADDRREQ: return EDESTADDRREQ; case WSAEMSGSIZE: return EMSGSIZE;
    case WSAEPROTOTYPE: return EPROTOTYPE;    case WSAENOPROTOOPT: return ENOPROTOOPT;
    case WSAEPROTONOSUPPORT: return EPROTONOSUPPORT;
    case WSAESOCKTNOSUPPORT: return EPROTONOSUPPORT;
    case WSAEOPNOTSUPP: return ENOTSUP;       case WSAEPFNOSUPPORT: return EAFNOSUPPORT;
    case WSAEAFNOSUPPORT: return EAFNOSUPPORT; case WSAEADDRINUSE: return EADDRINUSE;
    case WSAEADDRNOTAVAIL: return EADDRNOTAVAIL; case WSAENETDOWN: return ENETDOWN;
    case WSAENETUNREACH: return ENETUNREACH;  case WSAENETRESET: return ENETRESET;
    case WSAECONNABORTED: return ECONNABORTED; case WSAECONNRESET: return ECONNRESET;
    case WSAENOBUFS: return ENOBUFS;          case WSAEISCONN: return EISCONN;
    case WSAENOTCONN: return ENOTCONN;        case WSAESHUTDOWN: return EPIPE;
    case WSAETIMEDOUT: return ETIMEDOUT;      case WSAECONNREFUSED: return ECONNREFUSED;
    case WSAELOOP: return ELOOP;              case WSAENAMETOOLONG: return ENAMETOOLONG;
    case WSAEHOSTDOWN: return EHOSTUNREACH;   case WSAEHOSTUNREACH: return EHOSTUNREACH;
    case WSAENOTEMPTY: return ENOTEMPTY;      case WSANOTINITIALISED: return ENOSYS;
    default: return EIO;
    }
}
static int wsa_failed(void) { last = errno_of_wsa(WSAGetLastError()); return -1; }
/* the socket of fd, or ENOTSOCK */
#define SOCK_OR_FAIL(s, fd) Sock *s = sock_of(fd); if (!s) { last = ENOTSOCK; return -1; }

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
   by name: time_t is 32 bits in the 32-bit msvcrt, and would end in 2038.
   Those know only the years 1970 to 3000. But msvcrt's rules for summer
   time are the same every year (TZ's, or those Windows has for its zone
   now), and the Gregorian calendar repeats itself every 400 years,
   weekdays included: so a time is moved by whole cycles into the years
   2370 to 2770, far from both ends, and its year moved back after. */
#define CYCLE_SECONDS 12622780800LL   /* 400 years: 146097 days */
#define CYCLE_BASE (1 * CYCLE_SECONDS) /* the start of 2370 */
static int64_t floor_div(int64_t a, int64_t b) { return a / b - (a % b != 0 && (a < 0) != (b < 0)); }
/* the number of cycles to add to a time to bring it into the window */
static int64_t cycles_for_time(int64_t seconds) {
    return -floor_div(seconds - CYCLE_BASE, CYCLE_SECONDS);
}
/* the number of cycles to add to a year (less 1900) to bring it there */
static int64_t cycles_for_year(int64_t tm_year) { return -floor_div(tm_year - 470, 400); }
static int to_parts(const struct tm *tm, int64_t cycles, int32_t parts[9]) {
    int64_t year = (int64_t)tm->tm_year - 400 * cycles;
    if (year > INT32_MAX || year < INT32_MIN) { last = EOVERFLOW; return -1; }
    parts[0] = tm->tm_sec;  parts[1] = tm->tm_min;   parts[2] = tm->tm_hour;
    parts[3] = tm->tm_mday; parts[4] = tm->tm_mon;   parts[5] = (int32_t)year;
    parts[6] = tm->tm_wday; parts[7] = tm->tm_yday;  parts[8] = tm->tm_isdst;
    return 0;
}
int sys_date_parts(int64_t seconds, int local, int32_t parts[9]) {
    int64_t k = cycles_for_time(seconds);
    __time64_t t = (__time64_t)(seconds + k * CYCLE_SECONDS);
    struct tm tm;
    if ((local ? _localtime64_s(&tm, &t) : _gmtime64_s(&tm, &t)) != 0) return -1;
    return to_parts(&tm, k, parts);
}
int64_t sys_date_seconds(int32_t parts[9], int local) {
    struct tm tm;
    int64_t k = cycles_for_year(parts[5]);
    memset(&tm, 0, sizeof tm);
    tm.tm_sec = parts[0]; tm.tm_min = parts[1]; tm.tm_hour = parts[2];
    tm.tm_mday = parts[3]; tm.tm_mon = parts[4]; tm.tm_year = (int)(parts[5] + 400 * k);
    tm.tm_isdst = local ? parts[8] : 0;
    __time64_t t = local ? _mktime64(&tm) : _mkgmtime64(&tm);
    if (t == (__time64_t)-1) return failed();
    if (to_parts(&tm, k, parts) != 0) return -1;
    return (int64_t)t - k * CYCLE_SECONDS;
}
int sys_date_offset(int64_t seconds, int32_t *offset) {
    __time64_t t = (__time64_t)(seconds + cycles_for_time(seconds) * CYCLE_SECONDS);
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

int sys_system(const char *command);   /* with the processes, below */
const char *sys_getenv(const char *name) { return getenv(name); }

/* ---------------------------------------------------------------- paths */
/* Windows writes a path as C:\Users\me, and Rune's OS.Path is POSIX's, to
   which that is one relative arc. So every path of a drive this layer hands
   back is written /C:/Users/me -- absolute to POSIX, and no file of Windows
   has a colon in its name, so no other path reads so -- and a path that
   comes in as /C:/... is given to Windows as C:/.... /dev/null is NUL, and
   everything else goes as it came; Windows takes "/" for "\" everywhere. */
static char native_buffers[4][MAX_PATH * 4];
static int native_next = 0;
static int is_drive(const char *p) {
    return ((p[0] >= 'A' && p[0] <= 'Z') || (p[0] >= 'a' && p[0] <= 'z')) && p[1] == ':';
}
static const char *native(const char *path) {
    if (!path) return path;
    if (strcmp(path, "/dev/null") == 0) return "NUL";
    if (strcmp(path, "/dev/tty") == 0) return "CON";
    if (path[0] == '/' && is_drive(path + 1) && (path[3] == '/' || path[3] == 0)) {
        char *b = native_buffers[native_next++ % 4];
        snprintf(b, sizeof native_buffers[0], "%c:%s", path[1], path[3] ? path + 3 : "/");
        return b;
    }
    return path;
}
/* a path of Windows, in place, as the library reads it; p has room for one
   more character */
static const char *posix_path(char *p) {
    forward(p);
    if (is_drive(p) && (p[2] == '/' || p[2] == 0)) {
        memmove(p + 1, p, strlen(p) + 1);
        p[0] = '/';
        if (p[3] == 0) { p[3] = '/'; p[4] = 0; }
    }
    return p;
}

/* The error of the last call of Windows as the errno of POSIX. */
static int errno_of_win(DWORD e) {
    switch (e) {
    case ERROR_FILE_NOT_FOUND: case ERROR_PATH_NOT_FOUND: case ERROR_INVALID_NAME:
    case ERROR_BAD_PATHNAME: case ERROR_INVALID_DRIVE: case ERROR_BAD_NETPATH: return ENOENT;
    case ERROR_ACCESS_DENIED: case ERROR_SHARING_VIOLATION: case ERROR_LOCK_VIOLATION: return EACCES;
    case ERROR_ALREADY_EXISTS: case ERROR_FILE_EXISTS: return EEXIST;
    case ERROR_DIR_NOT_EMPTY: return ENOTEMPTY;
    case ERROR_DIRECTORY: return ENOTDIR;
    case ERROR_FILENAME_EXCED_RANGE: return ENAMETOOLONG;
    case ERROR_CANT_RESOLVE_FILENAME: return ELOOP;
    case ERROR_NOT_SAME_DEVICE: return EXDEV;
    case ERROR_PRIVILEGE_NOT_HELD: return EPERM;
    case ERROR_INVALID_HANDLE: return EBADF;
    case ERROR_DISK_FULL: case ERROR_HANDLE_DISK_FULL: return ENOSPC;
    case ERROR_WRITE_PROTECT: return EROFS;
    case ERROR_NOT_SUPPORTED: return ENOTSUP;
    case ERROR_BROKEN_PIPE: case ERROR_NO_DATA: return EPIPE;
    case ERROR_TOO_MANY_OPEN_FILES: return EMFILE;
    case ERROR_NOT_ENOUGH_MEMORY: case ERROR_OUTOFMEMORY: return ENOMEM;
    case ERROR_NOT_A_REPARSE_POINT: case ERROR_INVALID_PARAMETER: return EINVAL;
    case ERROR_NEGATIVE_SEEK: return EINVAL;
    default: return EIO;
    }
}
/* Windows says a path is not found where POSIX says why: that one of its
   directories is a file (ENOTDIR), or that it or a name in it is too long
   (ENAMETOOLONG). The path is the native one. */
static int path_error(const char *path, int e) {
    if (e != ENOENT) return e;
    size_t n = strlen(path), start = 0;
    if (n >= MAX_PATH) return ENAMETOOLONG;
    char prefix[MAX_PATH * 4];
    for (size_t i = 0; i <= n; i++) {
        if (i < n && path[i] != '/' && path[i] != '\\') continue;
        if (i - start > 255) return ENAMETOOLONG;
        if (i < n && i > 0 && i > start) {
            memcpy(prefix, path, i);
            prefix[i] = 0;
            DWORD a = GetFileAttributesA(prefix);
            if (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY)) return ENOTDIR;
        }
        start = i + 1;
    }
    return ENOENT;
}
static int win_failed(const char *path) {
    last = errno_of_win(GetLastError());
    if (path) last = path_error(path, last);
    return -1;
}

/* ---------------------------------------------------------------- files */
/* A file is opened with FILE_SHARE_DELETE, so that it can be removed or
   renamed while it is open, as on POSIX, and with FILE_FLAG_BACKUP_SEMANTICS
   when it is a directory, which POSIX lets a program open for reading. */
#define SHARE_ALL (FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
static HANDLE open_existing(const char *path, DWORD access, int follow) {
    return CreateFileA(path, access, SHARE_ALL, NULL, OPEN_EXISTING,
                       FILE_FLAG_BACKUP_SEMANTICS | (follow ? 0 : FILE_FLAG_OPEN_REPARSE_POINT), NULL);
}
static int is_directory(const char *path) {
    DWORD a = GetFileAttributesA(path);
    return a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY);
}

/* What stat says of a file, from a handle to it. */
typedef struct {
    int kind;                      /* as sys_stat_of numbers them */
    int64_t mode, ino, dev, nlink, size, atime, mtime, ctime;
} FileInfo;
static int info_of_path(const char *path, int follow, FileInfo *fi);
static int is_symlink(const char *path);
static DWORD reparse_tag(const char *path);

/* The mask of the modes of new files and directories, as umask sets it. A
   file is made read-only when its mode leaves out the owner's write. */
static int creation_mask = 022;
int sys_umask(int mask) {
    int old = creation_mask;
    creation_mask = mask & 0777;
    return old;
}

int sys_mkdir(const char *path) {
    path = native(path);
    return CreateDirectoryA(path, NULL) ? 0 : win_failed(path);
}
/* A symbolic link to a directory is not a directory to rmdir, as on POSIX. */
int sys_rmdir(const char *path) {
    path = native(path);
    DWORD a = GetFileAttributesA(path);
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_REPARSE_POINT)) { last = ENOTDIR; return -1; }
    return RemoveDirectoryA(path) ? 0 : win_failed(path);
}
int sys_chdir(const char *path) {
    path = native(path);
    return SetCurrentDirectoryA(path) ? 0 : win_failed(path);
}
/* The directory as POSIX's getcwd gives it, with the links on the way to
   it followed: Windows keeps the path it was changed to. */
const char *sys_getcwd(void) {
    const char *real = sys_real_path(".");
    if (real) return real;
    DWORD n = GetCurrentDirectoryA(MAX_PATH * 4 - 2, path_buffer);
    if (n == 0 || n >= MAX_PATH * 4 - 2) { win_failed(NULL); return NULL; }
    return posix_path(path_buffer);
}
/* unlink: POSIX removes a file whatever its mode, and a symbolic link to a
   directory as a link; a directory itself it will not. */
int sys_remove(const char *path) {
    path = native(path);
    DWORD a = GetFileAttributesA(path);
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) {
        if (a & FILE_ATTRIBUTE_REPARSE_POINT) return RemoveDirectoryA(path) ? 0 : win_failed(path);
        last = EISDIR;
        return -1;
    }
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_READONLY))
        SetFileAttributesA(path, a & ~(DWORD)FILE_ATTRIBUTE_READONLY);
    if (DeleteFileA(path)) return 0;
    int e = win_failed(path);
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_READONLY)) SetFileAttributesA(path, a);
    return e;
}
/* rename as POSIX has it: a file replaces a file, a directory an empty
   directory; not a directory into itself, and not across volumes. */
int sys_rename(const char *from, const char *to) {
    from = native(from);
    to = native(to);
    DWORD fa = GetFileAttributesA(from), ta = GetFileAttributesA(to);
    if (fa == INVALID_FILE_ATTRIBUTES) return win_failed(from);
    if (ta != INVALID_FILE_ATTRIBUTES) {
        /* two names of one file: POSIX leaves both */
        FileInfo a, b;
        if (info_of_path(from, 0, &a) == 0 && info_of_path(to, 0, &b) == 0 && a.dev == b.dev && a.ino == b.ino)
            return 0;
        int from_dir = (fa & FILE_ATTRIBUTE_DIRECTORY) != 0, to_dir = (ta & FILE_ATTRIBUTE_DIRECTORY) != 0;
        if (from_dir && !to_dir) { last = ENOTDIR; return -1; }
        if (!from_dir && to_dir) { last = EISDIR; return -1; }
        if (to_dir && !RemoveDirectoryA(to)) return win_failed(to);
        if (!to_dir && (ta & FILE_ATTRIBUTE_READONLY)) SetFileAttributesA(to, ta & ~(DWORD)FILE_ATTRIBUTE_READONLY);
    }
    if (fa & FILE_ATTRIBUTE_DIRECTORY) {
        char a[MAX_PATH * 4], b[MAX_PATH * 4];
        if (GetFullPathNameA(from, sizeof a, a, NULL) && GetFullPathNameA(to, sizeof b, b, NULL)) {
            size_t n = strlen(forward(a));
            forward(b);
            if (_strnicmp(a, b, n) == 0 && b[n] == '/') { last = EINVAL; return -1; }
        }
    }
    return MoveFileExA(from, to, MOVEFILE_REPLACE_EXISTING) ? 0 : win_failed(to);
}

/* Windows has no execute permission: a file is executable when its
   extension is one of PATHEXT's, as the command line of Windows has it,
   and a directory can always be searched. */
static int executable(const char *path) {
    const char *dot = strrchr(path, '.'), *slash = strrchr(path, '/'), *back = strrchr(path, '\\');
    if (!dot || (slash && slash > dot) || (back && back > dot)) return 0;
    const char *list = getenv("PATHEXT");
    if (!list) list = ".COM;.EXE;.BAT;.CMD";
    size_t n = strlen(dot);
    for (const char *p = list; *p; ) {
        const char *end = strchr(p, ';');
        size_t k = end ? (size_t)(end - p) : strlen(p);
        if (k == n && _strnicmp(p, dot, n) == 0) return 1;
        if (!end) break;
        p = end + 1;
    }
    return 0;
}
int sys_access(const char *path, int read, int write, int exec) {
    (void)read;
    path = native(path);
    DWORD a = GetFileAttributesA(path);
    if (a == INVALID_FILE_ATTRIBUTES) { win_failed(path); return 0; }
    /* through a link to what it names, which may not be there */
    if ((a & FILE_ATTRIBUTE_REPARSE_POINT) && is_symlink(path)) {
        HANDLE h = open_existing(path, FILE_READ_ATTRIBUTES, 1);
        if (h == INVALID_HANDLE_VALUE) { win_failed(path); return 0; }
        BY_HANDLE_FILE_INFORMATION info;
        if (GetFileInformationByHandle(h, &info)) a = info.dwFileAttributes;
        CloseHandle(h);
    }
    int dir = (a & FILE_ATTRIBUTE_DIRECTORY) != 0;
    if (write && !dir && (a & FILE_ATTRIBUTE_READONLY)) { last = EACCES; return 0; }
    if (exec && !dir && !executable(path)) { last = EACCES; return 0; }
    return 1;
}

static int64_t filetime_seconds(FILETIME ft);
static int info_of(HANDLE h, const char *path, int link, FileInfo *fi) {
    memset(fi, 0, sizeof *fi);
    DWORD type = GetFileType(h);
    if (type == FILE_TYPE_PIPE) { fi->kind = 4; fi->mode = 0600; fi->nlink = 1; return 0; }
    if (type == FILE_TYPE_CHAR) {
        DWORD m;
        fi->kind = 6;
        fi->mode = GetConsoleMode(h, &m) ? 0620 : 0666;
        fi->nlink = 1;
        return 0;
    }
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(h, &info)) return win_failed(NULL);
    int dir = (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    char name[MAX_PATH * 4];
    if (!path && GetFinalPathNameByHandleA(h, name, sizeof name, FILE_NAME_NORMALIZED) > 0) path = name;
    if (link) { fi->kind = 2; fi->mode = 0777; }
    else if (dir) { fi->kind = 1; fi->mode = 0700; }
    else {
        fi->kind = 0;
        fi->mode = 0400 | ((info.dwFileAttributes & FILE_ATTRIBUTE_READONLY) ? 0 : 0200)
                 | (path && executable(path) ? 0100 : 0);
    }
    fi->ino = (int64_t)(((uint64_t)info.nFileIndexHigh << 32) | info.nFileIndexLow);
    fi->dev = (int64_t)info.dwVolumeSerialNumber;
    fi->nlink = (int64_t)info.nNumberOfLinks;
    fi->size = (int64_t)(((uint64_t)info.nFileSizeHigh << 32) | info.nFileSizeLow);
    fi->atime = filetime_seconds(info.ftLastAccessTime);
    fi->mtime = filetime_seconds(info.ftLastWriteTime);
    fi->ctime = filetime_seconds(info.ftCreationTime);
    return 0;
}
static int is_symlink(const char *path);
static int64_t link_text_length(const char *path);
/* stat of a path, following a link or not; any other reparse point is
   opened as itself (a socket's file cannot be opened through) */
static int info_of_path(const char *path, int follow, FileInfo *fi) {
    DWORD tag = reparse_tag(path);
    int symlink = tag == IO_REPARSE_TAG_SYMLINK || tag == IO_REPARSE_TAG_MOUNT_POINT;
    int link = !follow && symlink;
    HANDLE h = open_existing(path, FILE_READ_ATTRIBUTES, follow && symlink);
    if (h == INVALID_HANDLE_VALUE) return win_failed(path);
    int r = info_of(h, path, link, fi);
    CloseHandle(h);
    if (r == 0 && link) fi->size = link_text_length(path);
    /* a socket's file, as Linux makes it */
    if (r == 0 && tag == IO_REPARSE_TAG_AF_UNIX) { fi->kind = 5; fi->mode = 0755; }
    return r;
}

/* 0 regular, 1 directory, 2 symbolic link, 3 other. file_kind follows
   links, link_kind does not. */
int sys_file_kind(const char *path) {
    FileInfo fi;
    if (info_of_path(native(path), 1, &fi) != 0) return -1;
    return fi.kind <= 1 ? fi.kind : 3;
}
int sys_link_kind(const char *path) {
    FileInfo fi;
    if (info_of_path(native(path), 0, &fi) != 0) return -1;
    return fi.kind <= 2 ? fi.kind : 3;
}
int64_t sys_file_size(const char *path) {
    FileInfo fi;
    if (info_of_path(native(path), 1, &fi) != 0) return -1;
    return fi.size;
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
static int set_file_times(const char *path, int64_t access, int64_t modification) {
    HANDLE h = open_existing(path, FILE_WRITE_ATTRIBUTES, 1);
    if (h == INVALID_HANDLE_VALUE) return win_failed(path);
    FILETIME a = seconds_filetime(access), m = seconds_filetime(modification);
    int ok = SetFileTime(h, NULL, &a, &m);
    CloseHandle(h);
    return ok ? 0 : win_failed(NULL);
}
int64_t sys_mod_time(const char *path) {
    FileInfo fi;
    if (info_of_path(native(path), 1, &fi) != 0) return -1;
    return fi.mtime;
}
int sys_set_time(const char *path, int64_t seconds, int now) {
    if (now) seconds = sys_time_now() / 1000000;
    return set_file_times(native(path), seconds, seconds);
}
int sys_utime(const char *path, int64_t access, int64_t modification) {
    return set_file_times(native(path), access, modification);
}

/* ---------------------------------------------------------------- links */
/* A symbolic link is a reparse point of the tag IO_REPARSE_TAG_SYMLINK (a
   junction, IO_REPARSE_TAG_MOUNT_POINT, is read as one too). Its target is
   kept as its print name, with "\" for "/" and a drive written C:\; this
   layer writes and reads it as POSIX has it. The layout of the reparse data
   is that of ntifs.h, which user programs do not get. */
typedef struct {
    ULONG tag;
    USHORT data_length, reserved;
    USHORT substitute_offset, substitute_length, print_offset, print_length;
    /* symbolic links only: ULONG flags, then the names */
    UCHAR rest[1];
} ReparseData;
static char link_text[MAX_PATH * 4];
/* The target of the link at the native path, as the library reads it, or
   NULL with EINVAL when the file is no link. */
static const char *read_link_text(const char *path) {
    HANDLE h = open_existing(path, FILE_READ_ATTRIBUTES, 0);
    if (h == INVALID_HANDLE_VALUE) { win_failed(path); return NULL; }
    static union { ReparseData data; char bytes[MAXIMUM_REPARSE_DATA_BUFFER_SIZE]; } buffer;
    DWORD got = 0;
    BOOL ok = DeviceIoControl(h, FSCTL_GET_REPARSE_POINT, NULL, 0, &buffer, sizeof buffer, &got, NULL);
    CloseHandle(h);
    if (!ok) { last = GetLastError() == ERROR_NOT_A_REPARSE_POINT ? EINVAL : errno_of_win(GetLastError()); return NULL; }
    const ReparseData *r = &buffer.data;
    const UCHAR *names;
    if (r->tag == IO_REPARSE_TAG_SYMLINK) names = r->rest + sizeof(ULONG);
    else if (r->tag == IO_REPARSE_TAG_MOUNT_POINT) names = r->rest;
    else { last = EINVAL; return NULL; }
    USHORT offset = r->print_length ? r->print_offset : r->substitute_offset;
    USHORT length = r->print_length ? r->print_length : r->substitute_length;
    const WCHAR *w = (const WCHAR *)(names + offset);
    int n = WideCharToMultiByte(CP_ACP, 0, w, length / (int)sizeof(WCHAR), link_text, (int)sizeof link_text - 2, NULL, NULL);
    if (n <= 0) { last = EINVAL; return NULL; }
    link_text[n] = 0;
    /* a substitute name is \??\C:\...: the prefix is Windows' own */
    if (strncmp(link_text, "\\??\\", 4) == 0) memmove(link_text, link_text + 4, strlen(link_text + 4) + 1);
    return posix_path(link_text);
}
/* The tag of a reparse point, 0 for a file that is none. A link is a
   symbolic link or a junction; a socket of the Unix domain is a reparse
   point too (IO_REPARSE_TAG_AF_UNIX), and names nothing. */
#ifndef IO_REPARSE_TAG_AF_UNIX
#define IO_REPARSE_TAG_AF_UNIX 0x80000023L
#endif
static DWORD reparse_tag(const char *path) {
    WIN32_FIND_DATAA d;
    HANDLE f = FindFirstFileA(path, &d);
    if (f == INVALID_HANDLE_VALUE) return 0;
    FindClose(f);
    return (d.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) ? d.dwReserved0 : 0;
}
static int is_symlink(const char *path) {
    DWORD tag = reparse_tag(path);
    return tag == IO_REPARSE_TAG_SYMLINK || tag == IO_REPARSE_TAG_MOUNT_POINT;
}
/* lstat gives the length of the target as the size of a link */
static int64_t link_text_length(const char *path) {
    const char *t = read_link_text(path);
    return t ? (int64_t)strlen(t) : 0;
}
const char *sys_read_link(const char *path) { return read_link_text(native(path)); }

/* symlink: the link is made to a directory when its target is one now (a
   dangling link is made to a file); without the privilege it needs, which
   Developer Mode waives, Windows refuses it with EPERM. */
int sys_symlink(const char *from, const char *to) {
    char target[MAX_PATH * 4];
    snprintf(target, sizeof target, "%s", native(from));
    to = native(to);
    for (char *c = target; *c; c++) if (*c == '/') *c = '\\';
    /* where the target is, from the directory of the link */
    char where[MAX_PATH * 8];
    if (target[0] == '\\' || is_drive(target)) snprintf(where, sizeof where, "%s", target);
    else {
        const char *slash = strrchr(to, '/'), *back = strrchr(to, '\\');
        const char *sep = slash > back ? slash : back;
        if (sep) snprintf(where, sizeof where, "%.*s\\%s", (int)(sep - to), to, target);
        else snprintf(where, sizeof where, "%s", target);
    }
    DWORD flags = 0x2;   /* SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE */
    if (is_directory(where)) flags |= SYMBOLIC_LINK_FLAG_DIRECTORY;
    if (CreateSymbolicLinkA(to, target, flags)) return 0;
    if (GetLastError() == ERROR_INVALID_PARAMETER && CreateSymbolicLinkA(to, target, flags & ~(DWORD)0x2)) return 0;
    return win_failed(to);
}
/* link: a hard link, which Windows makes to files only, as POSIX may */
int sys_link(const char *from, const char *to) {
    from = native(from);
    to = native(to);
    if (is_directory(from)) { last = EPERM; return -1; }
    return CreateHardLinkA(to, from, NULL) ? 0 : win_failed(to);
}
int sys_mkfifo(const char *path, int mode) { (void)path; (void)mode; return fail(); }

/* realpath: the path Windows opens the file by, links followed, as
   GetFinalPathNameByHandle gives it (\\?\C:\... or \\?\UNC\server\...). */
const char *sys_real_path(const char *path) {
    path = native(path);
    HANDLE h = open_existing(path, FILE_READ_ATTRIBUTES, 1);
    if (h == INVALID_HANDLE_VALUE) { win_failed(path); return NULL; }
    char full[MAX_PATH * 4];
    DWORD n = GetFinalPathNameByHandleA(h, full, sizeof full, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    CloseHandle(h);
    if (n == 0 || n >= sizeof full) { win_failed(NULL); return NULL; }
    const char *p = full;
    if (strncmp(p, "\\\\?\\UNC\\", 8) == 0) { snprintf(path_buffer, sizeof path_buffer, "\\\\%s", p + 8); }
    else { if (strncmp(p, "\\\\?\\", 4) == 0) p += 4; snprintf(path_buffer, sizeof path_buffer, "%s", p); }
    return posix_path(path_buffer);
}
/* As mkstemp does for POSIX: a name in the directory Windows keeps for
   temporary files, and the file made so that the name is taken. The name
   is random, as mkstemp's is: GetTempFileName gives names in turn, so when
   programs remove the file to make a directory of the name, as the Basis
   suite does, a program started at the same time is given it again. */
const char *sys_tmp_name(void) {
    static uint32_t x = 0;
    char dir[MAX_PATH + 1];
    DWORD n = GetTempPathA(sizeof dir, dir);
    if (n == 0 || n > MAX_PATH) { last = ENOENT; return NULL; }
    if (x == 0) x = (uint32_t)GetTickCount64() ^ ((uint32_t)GetCurrentProcessId() << 12) ^ 0x2545f491u;
    for (int tries = 0; tries < 100; tries++) {
        x ^= x << 13; x ^= x >> 17; x ^= x << 5;
        snprintf(path_buffer, sizeof path_buffer, "%srune%08lx.tmp", dir, (unsigned long)x);
        HANDLE h = CreateFileA(path_buffer, GENERIC_WRITE, SHARE_ALL, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
        if (h != INVALID_HANDLE_VALUE) { CloseHandle(h); return posix_path(path_buffer); }
        if (GetLastError() != ERROR_FILE_EXISTS) { win_failed(dir); return NULL; }
    }
    last = EEXIST;
    return NULL;
}
/* Windows has no inode: the volume and the file index of the handle name a
   file, which is what BY_HANDLE_FILE_INFORMATION gives. */
int sys_file_id(const char *path, int64_t *device, int64_t *inode) {
    FileInfo fi;
    if (info_of_path(native(path), 1, &fi) != 0) return -1;
    *device = fi.dev;
    *inode = fi.ino;
    return 0;
}
/* Directories, on FindFirstFile: a stream is a slot of this table. "." and
   ".." are left out, as readdir's caller expects of OS.FileSys.readDir.
   reads counts the FindNextFile calls since the start, which a fork's
   child makes again. */
#define DIRS 64
static struct {
    int used; HANDLE find; WIN32_FIND_DATAA data; int pending; int64_t reads; char pattern[MAX_PATH * 4];
} dirs[DIRS];

static int dir_start(int i) {
    dirs[i].find = FindFirstFileA(dirs[i].pattern, &dirs[i].data);
    if (dirs[i].find == INVALID_HANDLE_VALUE) return win_failed(NULL);
    dirs[i].pending = 1;
    dirs[i].reads = 0;
    return 0;
}
int sys_open_dir(const char *path) {
    int i;
    path = native(path);
    for (i = 0; i < DIRS; i++) if (!dirs[i].used) break;
    if (i == DIRS) { last = EMFILE; return -1; }
    DWORD a = GetFileAttributesA(path);
    if (a == INVALID_FILE_ATTRIBUTES) return win_failed(path);
    if (!(a & FILE_ATTRIBUTE_DIRECTORY)) { last = ENOTDIR; return -1; }
    snprintf(dirs[i].pattern, sizeof dirs[i].pattern, "%s\\*", path);
    if (dir_start(i) != 0) return -1;
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
            dirs[dir].reads++;
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
static HANDLE console_of(int fd);
int sys_desc_kind(int fd) {
    if (sock_of(fd)) return 5;
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (h == INVALID_HANDLE_VALUE) { errno = EBADF; return failed(); }
    BY_HANDLE_FILE_INFORMATION info;
    switch (GetFileType(h)) {
        case FILE_TYPE_DISK:
            return GetFileInformationByHandle(h, &info) && (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
        case FILE_TYPE_CHAR: return console_of(fd) ? 3 : 6;
        case FILE_TYPE_PIPE: return 4;
        default: return 6;
    }
}
/* poll. Windows can wait for sockets (WSAPoll) and nothing else in the same
   call, so each kind of descriptor is asked in its own way:
     a file on disk is always ready, for reading and for writing, as POSIX's
     poll says of a regular file, and so is a device such as NUL;
     the reading end of a pipe is ready when PeekNamedPipe finds bytes in it,
     or finds its writer gone (the end of the stream is ready to be read);
     the writing end of a pipe is ready for writing;
     a console is ready for reading when a key waits in its input, and for
     writing always;
     sockets are asked with WSAPoll.
   Nothing is urgent but a socket's out-of-band data. Where anything but
   sockets is asked for, the set is looked at again every 10 milliseconds
   until one is ready or the time is up; sockets alone wait in WSAPoll. No
   descriptors at all is a wait for the time given. */
static int access_of(HANDLE h);
static int console_key_waits(HANDLE h) {
    DWORD n = 0;
    if (!GetNumberOfConsoleInputEvents(h, &n) || n == 0) return 0;
    INPUT_RECORD records[64];
    DWORD got = 0;
    if (!PeekConsoleInputA(h, records, n < 64 ? n : 64, &got)) return 0;
    for (DWORD i = 0; i < got; i++)
        if (records[i].EventType == KEY_EVENT && records[i].Event.KeyEvent.bKeyDown &&
            records[i].Event.KeyEvent.uChar.AsciiChar != 0)
            return 1;
    return 0;
}
/* what a descriptor that is no socket is ready for now, of what is asked */
static int ready_now(HANDLE h, int asked) {
    DWORD mode, avail = 0;
    switch (GetFileType(h)) {
    case FILE_TYPE_DISK: return asked & 3;
    case FILE_TYPE_PIPE: {
        int r = 0;
        if (asked & 1) {
            if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) {
                /* the writer is gone: the end can be read; a writing end
                   cannot be peeked into, and is not ready for reading */
                if (GetLastError() == ERROR_BROKEN_PIPE) r |= 1;
            } else if (avail > 0) r |= 1;
        }
        if ((asked & 2) && (access_of(h) != 0)) r |= 2;
        return r;
    }
    case FILE_TYPE_CHAR:
        if (GetConsoleMode(h, &mode)) {
            int r = asked & 2;
            if ((asked & 1) && access_of(h) != 1 && console_key_waits(h)) r |= 1;
            return r;
        }
        return asked & 3;
    default: return 0;
    }
}
int sys_poll(const int *fds, int *events, int n, int64_t microseconds) {
    WSAPOLLFD *items = calloc((size_t)(n > 0 ? n : 1), sizeof *items);
    int *which = calloc((size_t)(n > 0 ? n : 1), sizeof *which);
    int *asked = calloc((size_t)(n > 0 ? n : 1), sizeof *asked);
    HANDLE *handles = calloc((size_t)(n > 0 ? n : 1), sizeof *handles);
    int nsock = 0, others = 0, result = -1;
    if (!items || !which || !asked || !handles) { last = ENOMEM; goto done; }
    for (int i = 0; i < n; i++) {
        asked[i] = events[i];
        Sock *s = sock_of(fds[i]);
        if (s) {
            items[nsock].fd = s->s;
            items[nsock].events = (short)(((events[i] & 1) ? POLLRDNORM : 0) | ((events[i] & 2) ? POLLWRNORM : 0) |
                                          ((events[i] & 4) ? POLLRDBAND : 0));
            which[nsock++] = i;
            handles[i] = NULL;
            continue;
        }
        handles[i] = (HANDLE)_get_osfhandle(fds[i]);
        if (handles[i] == INVALID_HANDLE_VALUE) { last = EBADF; goto done; }
        others++;
    }
    ULONGLONG start = GetTickCount64();
    for (;;) {
        int ready = 0;
        for (int i = 0; i < n; i++) {
            if (!handles[i]) continue;
            events[i] = ready_now(handles[i], asked[i]);
            if (events[i]) ready++;
        }
        int timeout;
        if (ready > 0) timeout = 0;
        else if (others > 0) timeout = microseconds == 0 ? 0 : 10;
        else timeout = microseconds < 0 ? -1 : microseconds / 1000 >= INT_MAX ? INT_MAX : (int)((microseconds + 999) / 1000);
        if (nsock > 0) {
            for (int k = 0; k < nsock; k++) items[k].revents = 0;
            if (WSAPoll(items, (ULONG)nsock, timeout) == SOCKET_ERROR) { wsa_failed(); goto done; }
            for (int k = 0; k < nsock; k++) {
                short r = items[k].revents;
                int i = which[k];
                /* the end of the stream is ready to be read, as POLLHUP is on POSIX */
                events[i] = ((r & (POLLRDNORM | POLLHUP)) ? 1 : 0) | ((r & POLLWRNORM) ? 2 : 0) | ((r & POLLRDBAND) ? 4 : 0);
                if (events[i]) ready++;
            }
        } else if (ready == 0 && timeout != 0) {
            if (n == 0 && microseconds < 0) Sleep(INFINITE);
            if (n == 0) { sys_time_sleep(microseconds); result = 0; goto done; }
            Sleep((DWORD)timeout);
        }
        int64_t spent = (int64_t)(GetTickCount64() - start) * 1000;
        if (ready > 0 || microseconds == 0 || (microseconds > 0 && spent >= microseconds) || (nsock > 0 && others == 0)) {
            result = ready;
            goto done;
        }
    }
done:
    free(items);
    free(which);
    free(asked);
    free(handles);
    return result;
}

/* The named constants. What this layer decodes or emulates itself has the
   numbers of Linux: the flags of open (sys_openf), of fcntl, of waitpid,
   and the signals. What goes to Winsock unchanged has Winsock's numbers.
   The errors are the table above. */
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
    { "VTIME", 5 }, { "VSTART", 8 }, { "VSTOP", 9 }, { "NCCS", 32 },
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
/* ---------------------------------------------------------------- ids */
int64_t sys_getpid(void) { return (int64_t)GetCurrentProcessId(); }
/* the process that made this one, from a snapshot of all of them */
int64_t sys_getppid(void) {
    HANDLE all = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (all == INVALID_HANDLE_VALUE) { last = EIO; return -1; }
    PROCESSENTRY32 e;
    e.dwSize = sizeof e;
    DWORD me = GetCurrentProcessId();
    int64_t parent = -1;
    for (BOOL ok = Process32First(all, &e); ok; ok = Process32Next(all, &e))
        if (e.th32ProcessID == me) { parent = (int64_t)e.th32ParentProcessID; break; }
    CloseHandle(all);
    if (parent < 0) last = ESRCH;
    return parent;
}

/* Windows names users and groups by SIDs, not numbers. The number of a user
   or a group here is the last part of its SID, its relative identifier, as
   Cygwin shows it (1001 is the first user a machine is given). Only the user
   of the process and the groups of its token can be asked for. */
static void *token_info(TOKEN_INFORMATION_CLASS what) {
    HANDLE token;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) { last = EACCES; return NULL; }
    DWORD size = 0;
    GetTokenInformation(token, what, NULL, 0, &size);
    void *info = size ? malloc(size) : NULL;
    if (!info || !GetTokenInformation(token, what, info, size, &size)) {
        free(info);
        CloseHandle(token);
        last = EACCES;
        return NULL;
    }
    CloseHandle(token);
    return info;
}
static int64_t rid_of(PSID sid) {
    return (int64_t)*GetSidSubAuthority(sid, (DWORD)(*GetSidSubAuthorityCount(sid) - 1));
}
int64_t sys_getuid(void) {
    TOKEN_USER *u = token_info(TokenUser);
    if (!u) return -1;
    int64_t id = rid_of(u->User.Sid);
    free(u);
    return id;
}
int64_t sys_geteuid(void) { return sys_getuid(); }
int64_t sys_getgid(void) {
    TOKEN_PRIMARY_GROUP *g = token_info(TokenPrimaryGroup);
    if (!g) return -1;
    int64_t id = rid_of(g->PrimaryGroup);
    free(g);
    return id;
}
int64_t sys_getegid(void) { return sys_getgid(); }
/* A process may become the user and group it is, and no other. */
int sys_setuid(int64_t uid) {
    int64_t me = sys_getuid();
    if (me < 0) return -1;
    if (uid != me) { last = EPERM; return -1; }
    return 0;
}
int sys_setgid(int64_t gid) {
    int64_t me = sys_getgid();
    if (me < 0) return -1;
    if (gid != me) { last = EPERM; return -1; }
    return 0;
}
/* the groups of the token, those it uses (enabled) */
int sys_getgroups(int64_t *out, int n) {
    TOKEN_GROUPS *g = token_info(TokenGroups);
    if (!g) return -1;
    int k = 0;
    for (DWORD i = 0; i < g->GroupCount; i++) {
        if (!(g->Groups[i].Attributes & SE_GROUP_ENABLED)) continue;
        if (k < n) out[k] = rid_of(g->Groups[i].Sid);
        k++;
    }
    free(g);
    if (n > 0 && k > n) { last = EINVAL; return -1; }
    return k;
}
static char user_name[256];
static const char *current_user(void) {
    DWORD n = sizeof user_name;
    if (!GetUserNameA(user_name, &n)) { last = ENOENT; return NULL; }
    return user_name;
}
const char *sys_getlogin(void) { return current_user(); }
int64_t sys_getpgrp(void) { return fail(); }
int64_t sys_setsid(void) { return fail(); }
int sys_setpgid(int64_t pid, int64_t pgid) { (void)pid; (void)pgid; return fail(); }
/* The name of the system is "Windows"; its release is the version of
   Windows, as RtlGetVersion gives it (GetVersionEx gives what the program's
   manifest asks for), its version the build, and the machine that of the
   processor, not of this process: a 32-bit VM on 64-bit Windows says x86_64,
   as a 32-bit program does on Linux. */
static char uname_strings[1024];
const char *sys_uname(void) {
    char node[256] = "";
    DWORD n = sizeof node;
    GetComputerNameExA(ComputerNameDnsHostname, node, &n);
    typedef LONG (WINAPI *RtlGetVersionFn)(PRTL_OSVERSIONINFOW);
    RtlGetVersionFn get = (RtlGetVersionFn)(void (*)(void))GetProcAddress(GetModuleHandleA("ntdll.dll"), "RtlGetVersion");
    RTL_OSVERSIONINFOW v;
    memset(&v, 0, sizeof v);
    v.dwOSVersionInfoSize = sizeof v;
    if (get) get(&v);
    char release[32], version[32];
    snprintf(release, sizeof release, "%lu.%lu", (unsigned long)v.dwMajorVersion, (unsigned long)v.dwMinorVersion);
    snprintf(version, sizeof version, "%lu", (unsigned long)v.dwBuildNumber);
    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    const char *machine = si.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_AMD64 ? "x86_64"
                        : si.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_ARM64 ? "aarch64"
                        : si.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_INTEL ? "i686" : "unknown";
    const char *parts[5] = { "Windows", node, release, version, machine };
    size_t at = 0;
    for (int i = 0; i < 5; i++) {
        size_t k = strlen(parts[i]);
        if (at + k + 2 >= sizeof uname_strings) break;
        memcpy(uname_strings + at, parts[i], k);
        at += k;
        uname_strings[at++] = 0;
    }
    uname_strings[at] = 0;
    return uname_strings;
}
/* The processor time of the children the process has waited for, which
   sys_waitpid adds to, in microseconds. */
static int64_t children_user = 0, children_sys = 0;
int sys_times(int64_t out[5]) {
    FILETIME creation, exited, kernel, user;
    if (!GetProcessTimes(GetCurrentProcess(), &creation, &exited, &kernel, &user)) { last = EIO; return -1; }
    out[0] = (int64_t)GetTickCount64() * 1000;
    out[1] = of_filetime(user);
    out[2] = of_filetime(kernel);
    out[3] = children_user;
    out[4] = children_sys;
    return 0;
}
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
/* A terminal is a console of Windows: msvcrt's _isatty says so of NUL too,
   and of every other character device. */
static HANDLE console_of(int fd) {
    if (sock_of(fd)) return NULL;
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    DWORD mode;
    return h != INVALID_HANDLE_VALUE && GetConsoleMode(h, &mode) ? h : NULL;
}
/* the terminal is /dev/tty, which the layer opens as the console, CON */
const char *sys_ctermid(void) { return "/dev/tty"; }
const char *sys_ttyname(int fd) {
    if (!console_of(fd)) { last = ENOTTY; return NULL; }
    return "/dev/tty";
}
int sys_isatty(int fd) { return console_of(fd) ? 1 : 0; }
/* The limits of sysconf, as Linux gives them where Windows has no answer of
   its own; -1 with the error cleared is "no limit", and an option Windows
   does not have (job control, saved ids) is -1 too. */
int64_t sys_sysconf(const char *name) {
    last = 0;
    if (strcmp(name, "ARG_MAX") == 0) return 32767;   /* the command line of CreateProcess */
    if (strcmp(name, "CHILD_MAX") == 0) return -1;
    if (strcmp(name, "CLK_TCK") == 0) return 100;
    if (strcmp(name, "NGROUPS_MAX") == 0) return 65536;
    if (strcmp(name, "OPEN_MAX") == 0) return 2048;   /* the descriptors of msvcrt */
    if (strcmp(name, "STREAM_MAX") == 0) return _getmaxstdio();
    if (strcmp(name, "TZNAME_MAX") == 0) return -1;
    if (strcmp(name, "JOB_CONTROL") == 0) return -1;
    if (strcmp(name, "SAVED_IDS") == 0) return -1;
    if (strcmp(name, "VERSION") == 0) return 200809;
    if (strcmp(name, "PAGESIZE") == 0) {
        SYSTEM_INFO si;
        GetSystemInfo(&si);
        return (int64_t)si.dwPageSize;
    }
    last = EINVAL;
    return -1;
}

/* What POSIX keeps of a descriptor of the C runtime and msvcrt does not:
   the status flags append, non-blocking and synchronous (which POSIX keeps
   with the open file, and which a duplicate gets a copy of here), and
   close-on-exec, which is the descriptor's own. The access mode is asked of
   Windows (access_of). crt_append is msvcrt's own append, which fopen's
   "a" asks for and msvcrt cannot be asked about: a fork's child opens the
   descriptor again with it. */
#define FD_TABLE 2048
typedef struct { int append, nonblocking, sync, cloexec, crt_append; } FdFlags;
static FdFlags fd_flags[FD_TABLE];
static FdFlags *flags_of(int fd) { return fd >= 0 && fd < FD_TABLE ? &fd_flags[fd] : NULL; }
static void set_flags(int fd, int append, int nonblocking, int sync) {
    FdFlags *f = flags_of(fd);
    if (!f) return;
    f->append = append;
    f->nonblocking = nonblocking;
    f->sync = sync;
    f->cloexec = 0;
    f->crt_append = 0;
}
/* the access of a handle, O_RDONLY, O_WRONLY or O_RDWR, from the rights it
   was opened with (NtQueryInformationFile, FileAccessInformation) */
static int access_of(HANDLE h) {
    typedef LONG (WINAPI *QueryFn)(HANDLE, void *, void *, ULONG, int);
    static QueryFn query = NULL;
    if (!query) query = (QueryFn)(void (*)(void))GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtQueryInformationFile");
    struct { void *status; ULONG_PTR information; } io;
    ACCESS_MASK mask = 0;
    if (!query || query(h, &io, &mask, sizeof mask, 8) != 0) return 2;
    int r = (mask & FILE_READ_DATA) != 0, w = (mask & (FILE_WRITE_DATA | FILE_APPEND_DATA)) != 0;
    return r && w ? 2 : w ? 1 : 0;
}

/* open, with the flags of Linux (sys_const): the file is opened with
   CreateFile, shared for removal (open_existing), and given to msvcrt as a
   descriptor, in binary mode, because a stream of the library counts bytes.
   A new file is read-only when its mode, less the umask, does not let the
   owner write; the descriptor that makes it may still write, as on POSIX,
   and a file that exists keeps its mode. A directory opens for reading. */
static int open_fd(const char *path, int flags, int mode, int crt_append) {
    path = native(path);
    int access = flags & 3, create = (flags & 0100) != 0, exclusive = (flags & 0200) != 0;
    int truncate = (flags & 01000) != 0, append = (flags & 02000) != 0;
    DWORD a = GetFileAttributesA(path);
    HANDLE h;
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_DIRECTORY)) {
        if (create && exclusive) { last = EEXIST; return -1; }
        if (access != 0 || truncate) { last = EISDIR; return -1; }
        h = open_existing(path, GENERIC_READ, 1);
    } else {
        DWORD want = access == 0 ? GENERIC_READ : access == 1 ? GENERIC_WRITE : GENERIC_READ | GENERIC_WRITE;
        DWORD disposition, attributes = FILE_ATTRIBUTE_NORMAL;
        if (a != INVALID_FILE_ATTRIBUTES) {
            if (create && exclusive) { last = EEXIST; return -1; }
            disposition = truncate ? TRUNCATE_EXISTING : OPEN_EXISTING;
        } else {
            if (!create) { last = path_error(path, ENOENT); return -1; }
            disposition = CREATE_NEW;
            if (!((mode & ~creation_mask) & 0200)) attributes = FILE_ATTRIBUTE_READONLY;
        }
        h = CreateFileA(path, want, SHARE_ALL, NULL, disposition, attributes, NULL);
    }
    if (h == INVALID_HANDLE_VALUE) return win_failed(path);
    int fd = _open_osfhandle((intptr_t)h, _O_BINARY | (crt_append ? _O_APPEND : 0) |
                             (access == 0 ? _O_RDONLY : access == 1 ? _O_WRONLY : _O_RDWR));
    if (fd < 0) { CloseHandle(h); return failed(); }
    /* append is this layer's (sys_write_fd), so that fcntl can turn it off */
    set_flags(fd, append && !crt_append, (flags & 04000) != 0, (flags & 04010000) == 04010000);
    if (flags_of(fd)) flags_of(fd)->crt_append = crt_append;
    return fd;
}
int sys_openf(const char *path, int flags, int mode) { return open_fd(path, flags, mode, 0); }
/* fopen for the core (TextIO, BinIO, the loader): a descriptor of sys_openf
   and a stream on it, so that the paths and sharing are those above. The
   error is left in errno, where the core looks for it. */
FILE *sys_fopen(const char *path, const char *mode) {
    int flags = mode[0] == 'r' ? 0 : mode[0] == 'w' ? 1 | 0100 | 01000 : 1 | 0100 | 02000;
    if (strchr(mode, '+')) flags = (flags & ~3) | 2;
    int fd = open_fd(path, flags, 0666, mode[0] == 'a');
    if (fd < 0) { errno = last; return NULL; }
    FILE *f = _fdopen(fd, mode);
    if (!f) { int e = errno; _close(fd); errno = e; }
    return f;
}
static void drop_locks(int fd);
int sys_close_fd(int fd) {
    Sock *s = sock_of(fd);
    if (s) {
        s->used = 0;
        return closesocket(s->s) == 0 ? 0 : wsa_failed();
    }
    drop_locks(fd);
    return _close(fd) == 0 ? 0 : failed();
}
/* A socket is duplicated as Winsock hands a socket to another process,
   here to this one. */
int sys_dup(int fd) {
    Sock *s = sock_of(fd);
    if (s) {
        WSAPROTOCOL_INFOW info;
        int nonblocking = s->nonblocking;
        if (WSADuplicateSocketW(s->s, GetCurrentProcessId(), &info) != 0) return wsa_failed();
        SOCKET copy = WSASocketW(FROM_PROTOCOL_INFO, FROM_PROTOCOL_INFO, FROM_PROTOCOL_INFO, &info, 0,
                                 WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
        if (copy == INVALID_SOCKET) return wsa_failed();
        int r = new_sock(copy);
        if (r >= 0) sock_of(r)->nonblocking = nonblocking;
        return r;
    }
    int r = _dup(fd);
    if (r < 0) return failed();
    if (flags_of(fd) && flags_of(r)) { *flags_of(r) = *flags_of(fd); flags_of(r)->cloexec = 0; }
    return r;
}
/* A socket cannot take the number of a descriptor of the C runtime, nor
   the other way round. */
int sys_dup2(int fd, int to) {
    if (sock_of(fd) || sock_of(to)) { last = EBADF; return -1; }
    if (_dup2(fd, to) != 0) return failed();
    if (fd != to && flags_of(fd) && flags_of(to)) { *flags_of(to) = *flags_of(fd); flags_of(to)->cloexec = 0; }
    return to;
}
/* A pipe's handles are not inherited by the programs this one starts
   unless it hands them on (M7). */
int sys_pipe(int out[2]) {
    if (_pipe(out, 65536, _O_BINARY | _O_NOINHERIT) != 0) return failed();
    set_flags(out[0], 0, 0, 0);
    set_flags(out[1], 0, 0, 0);
    return 0;
}
/* the end of a file is 0 bytes with the error cleared, as on POSIX */
/* A pipe that does not block and has nothing in it says EAGAIN; one whose
   writer has gone says the end. */
int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    last = 0;
    if (sock_of(fd)) return sys_recv(fd, buf, n, 0);
    FdFlags *f = flags_of(fd);
    if (f && f->nonblocking && n > 0) {
        HANDLE h = (HANDLE)_get_osfhandle(fd);
        DWORD avail = 0;
        if (h != INVALID_HANDLE_VALUE && GetFileType(h) == FILE_TYPE_PIPE) {
            if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) {
                if (GetLastError() == ERROR_BROKEN_PIPE) return 0;
                return win_failed(NULL);
            }
            if (avail == 0) { last = EAGAIN; return -1; }
            if ((int64_t)avail < n) n = avail;
        }
    }
    int r = _read(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    return r < 0 ? failed() : r;
}
/* O_APPEND: every write goes to the end; O_SYNC: every write is on the
   disk before it returns. */
int64_t sys_write_fd(int fd, const char *buf, int64_t n) {
    if (sock_of(fd)) return sys_send(fd, buf, n, 0);
    FdFlags *f = flags_of(fd);
    if (f && f->append) _lseeki64(fd, 0, SEEK_END);
    int r = _write(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    /* msvcrt has no errno for a pipe whose reader is gone (ERROR_NO_DATA) */
    if (r < 0 && (_doserrno == ERROR_NO_DATA || _doserrno == ERROR_BROKEN_PIPE)) { last = EPIPE; return -1; }
    if (r < 0) return failed();
    if (f && f->sync) _commit(fd);
    return r;
}
int64_t sys_lseek_fd(int fd, int64_t offset, int whence) {
    if (sock_of(fd)) { last = ESPIPE; return -1; }
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (h == INVALID_HANDLE_VALUE) { last = EBADF; return -1; }
    /* msvcrt seeks on a pipe or a device without complaint */
    if (GetFileType(h) != FILE_TYPE_DISK) { last = ESPIPE; return -1; }
    __int64 r = _lseeki64(fd, offset, whence);
    return r < 0 ? failed() : (int64_t)r;
}
int sys_fsync(int fd) {
    if (sock_of(fd)) { last = EINVAL; return -1; }
    return _commit(fd) == 0 ? 0 : failed();
}
/* The commands of fcntl, as Linux numbers them (sys_const). A socket is
   read and written (O_RDWR), and blocks or not as FIONBIO last said. */
static int fcntl_fd(int fd, int command, int argument) {
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    FdFlags *f = flags_of(fd);
    if (h == INVALID_HANDLE_VALUE || !f) { last = EBADF; return -1; }
    switch (command) {
    case 0: {                                                    /* F_DUPFD */
        if (argument < 0 || argument >= FD_TABLE) { last = EINVAL; return -1; }
        for (int to = argument; to < FD_TABLE; to++)
            if ((HANDLE)_get_osfhandle(to) == INVALID_HANDLE_VALUE) return sys_dup2(fd, to);
        last = EMFILE;
        return -1;
    }
    case 1: return f->cloexec;                                   /* F_GETFD */
    case 2: f->cloexec = argument & 1; return 0;                 /* F_SETFD */
    case 3:                                                      /* F_GETFL */
        return access_of(h) | (f->append ? 02000 : 0) | (f->nonblocking ? 04000 : 0) | (f->sync ? 04010000 : 0);
    case 4:                                                      /* F_SETFL */
        f->append = (argument & 02000) != 0;
        f->nonblocking = (argument & 04000) != 0;
        return 0;
    default: last = EINVAL; return -1;
    }
}
int sys_fcntl(int fd, int command, int argument) {
    Sock *s = sock_of(fd);
    if (!s) return fcntl_fd(fd, command, argument);
    switch (command) {
    case 1: return s->cloexec;                                   /* F_GETFD */
    case 2: s->cloexec = argument & 1; return 0;                 /* F_SETFD */
    case 3: return 2 | (s->nonblocking ? 04000 : 0);             /* F_GETFL */
    case 4: {                                                    /* F_SETFL */
        u_long on = (argument & 04000) != 0;
        if (ioctlsocket(s->s, FIONBIO, &on) != 0) return wsa_failed();
        s->nonblocking = (int)on;
        return 0;
    }
    default: last = EINVAL; return -1;
    }
}
/* Locks. Windows locks a range of a file for a handle, and holds it
   against every other handle, the process's own too; POSIX locks it for
   the process, which its own locks never stop. So the process's locks are
   kept here, a new lock of the process replaces its old ones where they
   meet, and F_GETLK looks here before it asks Windows, with a handle of
   its own, whether another process holds the range. A lock that is split
   by an unlock is taken again for what is left. */
typedef struct { int used, fd, type; int64_t start, end; } Lock;   /* [start, end) */
#define LOCKS 256
static Lock locks[LOCKS];
static int lock_range(HANDLE h, int type, int64_t start, int64_t end, int wait) {
    OVERLAPPED o;
    memset(&o, 0, sizeof o);
    o.Offset = (DWORD)start;
    o.OffsetHigh = (DWORD)((uint64_t)start >> 32);
    uint64_t n = (uint64_t)(end - start);
    DWORD flags = (type == 1 ? LOCKFILE_EXCLUSIVE_LOCK : 0) | (wait ? 0 : LOCKFILE_FAIL_IMMEDIATELY);
    return LockFileEx(h, flags, 0, (DWORD)n, (DWORD)(n >> 32), &o) ? 0 : -1;
}
static void unlock_range(HANDLE h, int64_t start, int64_t end) {
    OVERLAPPED o;
    memset(&o, 0, sizeof o);
    o.Offset = (DWORD)start;
    o.OffsetHigh = (DWORD)((uint64_t)start >> 32);
    uint64_t n = (uint64_t)(end - start);
    UnlockFileEx(h, 0, (DWORD)n, (DWORD)(n >> 32), &o);
}
/* take the process's locks of fd off [start, end), keeping what is left */
static void release(int fd, HANDLE h, int64_t start, int64_t end) {
    for (int i = 0; i < LOCKS; i++) {
        Lock *l = &locks[i];
        if (!l->used || l->fd != fd || l->end <= start || l->start >= end) continue;
        unlock_range(h, l->start, l->end);
        Lock keep = *l;
        l->used = 0;
        for (int side = 0; side < 2; side++) {
            int64_t s0 = side == 0 ? keep.start : end, e0 = side == 0 ? start : keep.end;
            if (s0 >= e0 || lock_range(h, keep.type, s0, e0, 0) != 0) continue;
            for (int j = 0; j < LOCKS; j++)
                if (!locks[j].used) { locks[j] = keep; locks[j].start = s0; locks[j].end = e0; locks[j].used = 1; break; }
        }
    }
}
static void drop_locks(int fd) {
    for (int i = 0; i < LOCKS; i++) if (locks[i].used && locks[i].fd == fd) locks[i].used = 0;
}
int sys_lock(int fd, int command, int type, int whence, int64_t start, int64_t length, int64_t out[5]) {
    if (sock_of(fd)) { last = EINVAL; return -1; }
    HANDLE h = (HANDLE)_get_osfhandle(fd);
    if (h == INVALID_HANDLE_VALUE) { last = EBADF; return -1; }
    int64_t base = 0;
    if (whence == 1) base = _lseeki64(fd, 0, SEEK_CUR);
    else if (whence == 2) {
        LARGE_INTEGER size;
        if (!GetFileSizeEx(h, &size)) return win_failed(NULL);
        base = size.QuadPart;
    }
    int64_t from = base + start, to = length == 0 ? INT64_MAX : base + start + length;
    if (length < 0) { to = from; from = from + length; }
    if (from < 0 || to < from) { last = EINVAL; return -1; }
    out[0] = type; out[1] = whence; out[2] = start; out[3] = length; out[4] = 0;
    if (command == 5) {                                          /* F_GETLK */
        out[0] = 2;                                              /* F_UNLCK */
        for (int i = 0; i < LOCKS; i++)
            if (locks[i].used && locks[i].end > from && locks[i].start < to) return 0;
        HANDLE probe = ReOpenFile(h, GENERIC_READ, SHARE_ALL, 0);
        if (probe == INVALID_HANDLE_VALUE) return win_failed(NULL);
        if (lock_range(probe, type, from, to, 0) == 0) unlock_range(probe, from, to);
        else out[0] = 1;                                         /* held by another process */
        CloseHandle(probe);
        return 0;
    }
    if (command != 6 && command != 7) { last = EINVAL; return -1; }
    /* a read lock needs a descriptor open for reading, a write lock one open
       for writing, as POSIX has it; Windows locks for any handle */
    int access = access_of(h);
    if ((type == 0 && access == 1) || (type == 1 && access == 0)) { last = EBADF; return -1; }
    release(fd, h, from, to);
    if (type == 2) return 0;                                     /* F_UNLCK */
    if (lock_range(h, type, from, to, command == 7) != 0) {
        last = GetLastError() == ERROR_LOCK_VIOLATION || GetLastError() == ERROR_IO_PENDING ? EAGAIN
             : errno_of_win(GetLastError());
        return -1;
    }
    for (int i = 0; i < LOCKS; i++)
        if (!locks[i].used) { locks[i] = (Lock){ 1, fd, type, from, to }; return 0; }
    unlock_range(h, from, to);
    last = ENOLCK;
    return -1;
}
/* The limits of pathconf, those of NTFS and of msvcrt; -1 is "no such
   property" (the options of synchronised, asynchronous and prioritised
   input and output, which Linux leaves undefined too). */
int sys_pathconf(const char *path, int fd, const char *name, int64_t *out) {
    last = 0;
    path = native(path);
    if (path ? GetFileAttributesA(path) == INVALID_FILE_ATTRIBUTES
             : (!sock_of(fd) && (HANDLE)_get_osfhandle(fd) == INVALID_HANDLE_VALUE)) {
        last = path ? ENOENT : EBADF;
        return -1;
    }
    static const struct { const char *name; int64_t value; } limits[] = {
        { "LINK_MAX", 1024 }, { "MAX_CANON", 255 }, { "MAX_INPUT", 255 }, { "NAME_MAX", 255 },
        { "PATH_MAX", MAX_PATH }, { "PIPE_BUF", 4096 }, { "CHOWN_RESTRICTED", 1 }, { "NO_TRUNC", 1 },
        { "VDISABLE", 0 }, { "SYNC_IO", -1 }, { "ASYNC_IO", -1 }, { "PRIO_IO", -1 }, { "FILESIZEBITS", 64 },
    };
    for (size_t i = 0; i < sizeof limits / sizeof limits[0]; i++)
        if (strcmp(limits[i].name, name) == 0) { *out = limits[i].value; return 0; }
    last = EINVAL;
    return -1;
}

/* The terminal: a console, of which the settings of POSIX that have a
   counterpart are its modes -- ECHO (echoing input), ICANON (reading by
   lines) and ISIG (^C ends the program) -- and the rest are what a
   terminal of Linux has. The control characters are Linux's, but for the
   end of the input, ^Z on Windows. Anything else is not a terminal. */
#define TERMINAL_NCCS 32
int sys_nccs(void) { return TERMINAL_NCCS; }
int sys_tcgetattr(int fd, int64_t *out) {
    HANDLE h = console_of(fd);
    DWORD mode;
    if (!h || !GetConsoleMode(h, &mode)) { last = ENOTTY; return -1; }
    out[0] = 0400 | 02000;                                          /* ICRNL IXON */
    out[1] = 01;                                                    /* OPOST */
    out[2] = 060 | 0200;                                            /* CS8 CREAD */
    out[3] = ((mode & ENABLE_ECHO_INPUT) ? 010 | 020 | 040 : 0)     /* ECHO ECHOE ECHOK */
           | ((mode & ENABLE_LINE_INPUT) ? 02 : 0)                  /* ICANON */
           | ((mode & ENABLE_PROCESSED_INPUT) ? 01 : 0)             /* ISIG */
           | 0100000;                                               /* IEXTEN */
    out[4] = out[5] = 15;                                           /* B38400 */
    for (int i = 0; i < TERMINAL_NCCS; i++) out[6 + i] = 0;
    out[6 + 0] = 3;  out[6 + 1] = 28; out[6 + 2] = 127; out[6 + 3] = 21;   /* INTR QUIT ERASE KILL */
    out[6 + 4] = 26; out[6 + 5] = 0;  out[6 + 6] = 1;                      /* EOF TIME MIN */
    out[6 + 8] = 17; out[6 + 9] = 19; out[6 + 10] = 26;                    /* START STOP SUSP */
    return 0;
}
int sys_tcsetattr(int fd, int action, const int64_t *in) {
    (void)action;
    HANDLE h = console_of(fd);
    DWORD mode;
    if (!h || !GetConsoleMode(h, &mode)) { last = ENOTTY; return -1; }
    mode &= ~(DWORD)(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT | ENABLE_PROCESSED_INPUT);
    if (in[3] & 010) mode |= ENABLE_ECHO_INPUT;
    /* a console echoes only by lines */
    if (in[3] & 02) mode |= ENABLE_LINE_INPUT; else mode &= ~(DWORD)ENABLE_ECHO_INPUT;
    if (in[3] & 01) mode |= ENABLE_PROCESSED_INPUT;
    return SetConsoleMode(h, mode) ? 0 : (last = EIO, -1);
}
/* drain, flush, flow, break, get and set the group of the foreground */
int64_t sys_tcop(int op, int fd, int64_t argument) {
    HANDLE h = console_of(fd);
    if (!h) { last = ENOTTY; return -1; }
    switch (op) {
    case 0: return 0;
    case 1: if (argument != 1) FlushConsoleInputBuffer(h); return 0;   /* TCOFLUSH has nothing to flush */
    default: last = ENOSYS; return -1;
    }
}
/* SO_LINGER, as sys_posix.c has it: *seconds is -1 when off. */
int sys_linger(int fd, int set, int *seconds) {
    struct linger l;
    int len = sizeof l;
    SOCK_OR_FAIL(s, fd);
    if (set) {
        l.l_onoff = *seconds >= 0;
        l.l_linger = (u_short)(*seconds >= 0 ? *seconds : 0);
        if (setsockopt(s->s, SOL_SOCKET, SO_LINGER, (const char *)&l, sizeof l) != 0) return wsa_failed();
    }
    if (getsockopt(s->s, SOL_SOCKET, SO_LINGER, (char *)&l, &len) != 0) return wsa_failed();
    *seconds = l.l_onoff ? l.l_linger : -1;
    return 0;
}
/* 0: the bytes that can be read at once; 1: whether the next byte is the
   out-of-band mark. Winsock's SIOCATMARK says whether no urgent byte is
   waiting at all, which is the other way round. */
int sys_socket_query(int fd, int what) {
    u_long v = 0;
    SOCK_OR_FAIL(s, fd);
    if (what == 0) return ioctlsocket(s->s, FIONREAD, &v) == 0 ? (int)v : wsa_failed();
    if (what == 1) return ioctlsocket(s->s, SIOCATMARK, &v) == 0 ? !v : wsa_failed();
    last = EINVAL;
    return -1;
}
int sys_ftruncate(int fd, int64_t length) {
    if (sock_of(fd)) { last = EINVAL; return -1; }
    return _chsize_s(fd, length) == 0 ? 0 : failed();
}
/* kind, mode, inode, device, links, user, group, size, access, modification,
   change: the handle's file information (FileInfo). The owner of every file
   is the user of the process, and its group the user's, as Cygwin says
   without ACLs; the change is the creation, as msvcrt has it. */
int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]) {
    FileInfo fi;
    if (!path && sock_of(fd)) {
        /* a socket, readable and writable by all, as Linux has it */
        memset(&fi, 0, sizeof fi);
        fi.kind = 5;
        fi.mode = 0777;
        fi.ino = (int64_t)sock_of(fd)->s;
        fi.nlink = 1;
    } else if (path) {
        if (info_of_path(native(path), follow, &fi) != 0) return -1;
    } else {
        HANDLE h = (HANDLE)_get_osfhandle(fd);
        if (h == INVALID_HANDLE_VALUE) { last = EBADF; return -1; }
        if (info_of(h, NULL, 0, &fi) != 0) return -1;
    }
    int64_t uid = sys_getuid(), gid = sys_getgid();
    out[0] = fi.kind;
    out[1] = fi.mode;
    out[2] = fi.ino;
    out[3] = fi.dev;
    out[4] = fi.nlink;
    out[5] = uid < 0 ? 0 : uid;
    out[6] = gid < 0 ? 0 : gid;
    out[7] = fi.size;
    out[8] = fi.atime;
    out[9] = fi.mtime;
    out[10] = fi.ctime;
    return 0;
}
/* A mode of Windows is only whether the owner may write: the read-only
   attribute, which a directory does not have. fchmod reopens the file for
   its attributes, which the descriptor may not have been opened for. */
int sys_chmod(const char *path, int fd, int mode) {
    HANDLE h;
    if (path) h = open_existing(native(path), FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES, 1);
    else {
        HANDLE own = sock_of(fd) ? INVALID_HANDLE_VALUE : (HANDLE)_get_osfhandle(fd);
        if (own == INVALID_HANDLE_VALUE) { last = EBADF; return -1; }
        h = ReOpenFile(own, FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES, SHARE_ALL, FILE_FLAG_BACKUP_SEMANTICS);
    }
    if (h == INVALID_HANDLE_VALUE) return win_failed(path ? native(path) : NULL);
    FILE_BASIC_INFO info;
    int ok = GetFileInformationByHandleEx(h, FileBasicInfo, &info, sizeof info);
    if (ok && !(info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
        DWORD a = info.FileAttributes & ~(DWORD)FILE_ATTRIBUTE_READONLY;
        if (!(mode & 0200)) a |= FILE_ATTRIBUTE_READONLY;
        if (a == 0) a = FILE_ATTRIBUTE_NORMAL;
        memset(&info, 0, sizeof info);   /* zero times are left as they are */
        info.FileAttributes = a;
        ok = SetFileInformationByHandle(h, FileBasicInfo, &info, sizeof info);
    }
    if (!ok) win_failed(NULL);
    CloseHandle(h);
    return ok ? 0 : -1;
}
/* Every file is the user's, so it can be given to the user and a group of
   the user's (-1 leaves either as it is), and to no one else. */
int sys_chown(const char *path, int fd, int64_t uid, int64_t gid) {
    FileInfo fi;
    if (path) { if (info_of_path(native(path), 1, &fi) != 0) return -1; }
    else if (!sock_of(fd) && (HANDLE)_get_osfhandle(fd) == INVALID_HANDLE_VALUE) { last = EBADF; return -1; }
    int64_t groups[256];
    int n = sys_getgroups(groups, 256);
    int group_ok = gid == -1 || gid == sys_getgid();
    for (int i = 0; i < n && !group_ok; i++) group_ok = groups[i] == gid;
    if ((uid != -1 && uid != sys_getuid()) || !group_ok) { last = EPERM; return -1; }
    return 0;
}
/* The user of the process, and no other: its name, its home (USERPROFILE)
   and its shell (COMSPEC), with the numbers of sys_getuid and sys_getgid.
   Another user is not found, with the error cleared, as getpwnam leaves it. */
static char pw_strings[3 * (MAX_PATH * 4)];
const char *sys_getpw(const char *name, int64_t uid, int64_t out[2]) {
    const char *me = current_user();
    int64_t my_uid = sys_getuid(), my_gid = sys_getgid();
    if (!me || my_uid < 0 || my_gid < 0) return NULL;
    last = 0;
    if (name ? _stricmp(name, me) != 0 : uid != my_uid) return NULL;
    const char *home = getenv("USERPROFILE"), *shell = getenv("COMSPEC");
    const char *parts[3] = { me, home ? home : "", shell ? shell : "" };
    size_t at = 0;
    for (int i = 0; i < 3; i++) {
        size_t k = strlen(parts[i]);
        if (at + k + 2 >= sizeof pw_strings) break;
        memcpy(pw_strings + at, parts[i], k);
        pw_strings[at + k] = 0;
        if (i > 0) posix_path(pw_strings + at);   /* the home and the shell */
        k = strlen(pw_strings + at);
        at += k;
        pw_strings[at++] = 0;
    }
    pw_strings[at] = 0;
    out[0] = my_uid;
    out[1] = my_gid;
    return pw_strings;
}
/* A group of the process's token, by name or by number: its name and
   number, and as its members the user of the process, the one member this
   layer knows. Another group is not found, with the error cleared. */
static char gr_name[256], gr_members[256];
const char *sys_getgr(const char *name, int64_t gid, int64_t *id) {
    TOKEN_GROUPS *g = token_info(TokenGroups);
    TOKEN_PRIMARY_GROUP *primary = token_info(TokenPrimaryGroup);
    const char *me = current_user();
    const char *found = NULL;
    last = 0;
    if (g && primary && me) {
        for (DWORD i = 0; i <= g->GroupCount && !found; i++) {
            PSID sid = i == 0 ? primary->PrimaryGroup : g->Groups[i - 1].Sid;
            char account[256], domain[256];
            DWORD an = sizeof account, dn = sizeof domain;
            SID_NAME_USE use;
            if (!LookupAccountSidA(NULL, sid, account, &an, domain, &dn, &use)) continue;
            if (name ? _stricmp(name, account) != 0 : gid != rid_of(sid)) continue;
            snprintf(gr_name, sizeof gr_name, "%s", account);
            gr_name[strlen(gr_name) + 1] = 0;
            snprintf(gr_members, sizeof gr_members, "%s", me);
            gr_members[strlen(gr_members) + 1] = 0;
            *id = rid_of(sid);
            found = gr_name;
        }
    }
    free(g);
    free(primary);
    return found;
}
const char *sys_group_members(void) { return gr_members; }

/* The addresses of sockets are the bytes of a sockaddr of Winsock, which has
   the layout of POSIX's (family, then port and address). */
static char address[128];
static int address_length = 0;
const char *sys_last_addr(void) { return address; }
int sys_last_addr_len(void) { return address_length; }

/* Sockets are made as socket() makes them, but not to be inherited by the
   programs this one starts (M7 hands on what a program asks for). A UDP
   socket does not report, on its next receive, that an earlier datagram
   found no one listening: POSIX has no such failure. */
int sys_socket(int domain, int type, int protocol) {
    if (winsock() != 0) return -1;
    SOCKET s = WSASocketW(domain, type, protocol, NULL, 0, WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
    if (s == INVALID_SOCKET) return wsa_failed();
    if (type == SOCK_DGRAM && (domain == AF_INET || domain == AF_INET6)) {
        BOOL report = FALSE;
        DWORD bytes = 0;
        WSAIoctl(s, SIO_UDP_CONNRESET, &report, sizeof report, NULL, 0, &bytes, NULL, NULL);
    }
    int fd = new_sock(s);
    if (fd >= 0) {
        Sock *made = sock_of(fd);
        made->domain = domain;
        made->type = type;
        made->protocol = protocol;
    }
    return fd;
}

/* Windows has no socketpair. A pair of AF_UNIX stream sockets is made the
   long way: a socket listening on a name in the directory of temporary
   files, one that connects to it, and the one accepted; the listener and
   its name go again. Windows has no AF_UNIX datagrams, and POSIX no other
   families of pairs. */
int sys_socketpair(int domain, int type, int protocol, int out[2]) {
    static unsigned serial = 0;
    if (domain != AF_UNIX) { last = EOPNOTSUPP; return -1; }
    if (type != SOCK_STREAM) { last = EPROTONOSUPPORT; return -1; }
    if (winsock() != 0) return -1;
    struct sockaddr_un name;
    memset(&name, 0, sizeof name);
    name.sun_family = AF_UNIX;
    char dir[MAX_PATH + 1];
    DWORD n = GetTempPathA(sizeof dir, dir);
    if (n == 0 || n > MAX_PATH) { last = ENOENT; return -1; }
    snprintf(name.sun_path, sizeof name.sun_path, "%srune-pair-%lu-%u", dir,
             (unsigned long)GetCurrentProcessId(), serial++);
    SOCKET listener = WSASocketW(AF_UNIX, SOCK_STREAM, protocol, NULL, 0, WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
    if (listener == INVALID_SOCKET) return wsa_failed();
    SOCKET a = INVALID_SOCKET, b = INVALID_SOCKET;
    DeleteFileA(name.sun_path);
    if (bind(listener, (struct sockaddr *)&name, sizeof name) != 0 || listen(listener, 1) != 0) goto failed;
    a = WSASocketW(AF_UNIX, SOCK_STREAM, protocol, NULL, 0, WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
    if (a == INVALID_SOCKET || connect(a, (struct sockaddr *)&name, sizeof name) != 0) goto failed;
    b = accept(listener, NULL, NULL);
    if (b == INVALID_SOCKET) goto failed;
    closesocket(listener);
    DeleteFileA(name.sun_path);
    out[0] = new_sock(a);
    out[1] = new_sock(b);
    if (out[0] < 0 || out[1] < 0) return -1;
    for (int k = 0; k < 2; k++) {
        Sock *made = sock_of(out[k]);
        made->domain = AF_UNIX;
        made->type = SOCK_STREAM;
        made->protocol = protocol;
        made->pair = 1;
    }
    return 0;
failed:
    wsa_failed();
    if (a != INVALID_SOCKET) closesocket(a);
    closesocket(listener);
    DeleteFileA(name.sun_path);
    return -1;
}

/* The port a stream socket binds when it asks for any (port 0) is picked at
   random from the ephemeral ones, as Linux picks it. Windows gives the
   lowest free port every time: a listener that closes and is made again
   gets the same port, and its connections meet those of the last one,
   which wait out TIME_WAIT (see sys_connect). */
static unsigned next_random(void) {
    static unsigned x = 0;
    if (x == 0) x = (unsigned)GetTickCount() ^ ((unsigned)GetCurrentProcessId() << 16) ^ 0x9e3779b9u;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return x;
}
int sys_bind(int fd, const char *addr, int n) {
    SOCK_OR_FAIL(s, fd);
    unsigned short family = 0, port = 1;
    if (n >= (int)sizeof(struct sockaddr_in)) {
        memcpy(&family, addr, sizeof family);
        if (family == AF_INET || (family == AF_INET6 && n >= (int)sizeof(struct sockaddr_in6)))
            memcpy(&port, addr + offsetof(struct sockaddr_in, sin_port), sizeof port);
    }
    if (s->type == SOCK_STREAM && (family == AF_INET || family == AF_INET6) && port == 0) {
        char copy[sizeof(struct sockaddr_in6)];
        memcpy(copy, addr, (size_t)n < sizeof copy ? (size_t)n : sizeof copy);
        for (int tries = 0; tries < 32; tries++) {
            unsigned short random_port = htons((unsigned short)(49152 + next_random() % 16384));
            memcpy(copy + offsetof(struct sockaddr_in, sin_port), &random_port, sizeof random_port);
            if (bind(s->s, (const struct sockaddr *)copy, n) == 0) { s->bound = 1; return 0; }
            if (WSAGetLastError() != WSAEADDRINUSE && WSAGetLastError() != WSAEACCES) break;
        }
    }
    if (bind(s->s, (const struct sockaddr *)addr, n) != 0) return wsa_failed();
    s->bound = 1;
    return 0;
}
/* A connection that a non-blocking socket starts is EINPROGRESS, as on
   POSIX, where Winsock says WSAEWOULDBLOCK.

   Windows gives the ports of the loopback interface out in turn, so two
   programs that each listen and connect on it, one after the other, swap
   ports: the second one's connection has the ends of the first one's,
   which waits out TIME_WAIT, and connect fails with WSAEADDRINUSE. Linux
   picks ports at random and never meets this. A socket the program did not
   bind is then made again, with the options it was given, and connected
   from the next port. */
static SOCKET remake(Sock *s) {
    SOCKET fresh = WSASocketW(s->domain, s->type, s->protocol, NULL, 0, WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
    if (fresh == INVALID_SOCKET) return fresh;
    for (int i = 0; i < s->noptions; i++)
        setsockopt(fresh, s->options[i].level, s->options[i].name, (const char *)&s->options[i].value, sizeof(int));
    u_long on = (u_long)s->nonblocking;
    ioctlsocket(fresh, FIONBIO, &on);
    return fresh;
}
/* A connection on the loopback interface is made or refused at once. Some
   machines (a firewall that swallows the reset of a closed local port)
   never answer a closed one, and a blocking connect to it would wait for
   ever; so a blocking connect on the loopback interface is given four
   seconds -- Windows' own refusal takes two -- and after that the port is
   taken to refuse, and the socket, whose attempt is still pending, is made
   again. */
static int is_loopback(const char *addr, int n) {
    unsigned short family;
    if (n < (int)sizeof family) return 0;
    memcpy(&family, addr, sizeof family);
    if (family == AF_INET && n >= (int)sizeof(struct sockaddr_in))
        return ((const struct sockaddr_in *)(const void *)addr)->sin_addr.s_addr == htonl(INADDR_LOOPBACK)
            || (ntohl(((const struct sockaddr_in *)(const void *)addr)->sin_addr.s_addr) >> 24) == 127;
    if (family == AF_INET6 && n >= (int)sizeof(struct sockaddr_in6))
        return IN6_IS_ADDR_LOOPBACK(&((const struct sockaddr_in6 *)(const void *)addr)->sin6_addr);
    return 0;
}
/* one connect: 0, or the error of Winsock (WSAETIMEDOUT when a bounded
   one ran out of time) */
static int connect_once(Sock *s, const char *addr, int n, int bounded) {
    u_long on = 1, off = 0;
    if (bounded) ioctlsocket(s->s, FIONBIO, &on);
    int e = connect(s->s, (const struct sockaddr *)addr, n) == 0 ? 0 : WSAGetLastError();
    if (bounded && e == WSAEWOULDBLOCK) {
        WSAPOLLFD p;
        p.fd = s->s;
        p.events = POLLWRNORM;
        p.revents = 0;
        int k = WSAPoll(&p, 1, 4000);
        if (k == 0) e = WSAETIMEDOUT;
        else if (k < 0) e = WSAGetLastError();
        else if (p.revents & (POLLERR | POLLHUP)) {
            int err = 0, len = sizeof err;
            getsockopt(s->s, SOL_SOCKET, SO_ERROR, (char *)&err, &len);
            e = err ? err : WSAECONNREFUSED;
        } else e = 0;
    }
    if (bounded) ioctlsocket(s->s, FIONBIO, &off);
    return e;
}
int sys_connect(int fd, const char *addr, int n) {
    SOCK_OR_FAIL(s, fd);
    int bounded = !s->nonblocking && s->type == SOCK_STREAM && is_loopback(addr, n);
    for (int tries = 0; ; tries++) {
        int e = connect_once(s, addr, n, bounded);
        if (e == 0) {
            /* a connected datagram socket hears that its peer's port is
               unreachable, as on POSIX; an unconnected one does not */
            if (s->type == SOCK_DGRAM) {
                BOOL report = TRUE;
                DWORD bytes = 0;
                WSAIoctl(s->s, SIO_UDP_CONNRESET, &report, sizeof report, NULL, 0, &bytes, NULL, NULL);
                s->connected = 1;
            }
            return 0;
        }
        if (e == WSAEWOULDBLOCK) { last = EINPROGRESS; return -1; }
        int again = e == WSAEADDRINUSE && !s->bound && s->domain >= 0 && tries < 16;
        if (e == WSAETIMEDOUT && bounded) e = WSAECONNREFUSED;
        if (again || (bounded && e == WSAECONNREFUSED)) {
            SOCKET fresh = remake(s);
            if (fresh != INVALID_SOCKET) { closesocket(s->s); s->s = fresh; }
            if (again && fresh != INVALID_SOCKET) continue;
        }
        last = errno_of_wsa(e);
        return -1;
    }
}
int sys_listen(int fd, int backlog) {
    SOCK_OR_FAIL(s, fd);
    return listen(s->s, backlog) == 0 ? 0 : wsa_failed();
}
/* The socket accepted blocks, as it does on Linux, whatever the listening
   one does: Winsock would have it inherit that. */
int sys_accept(int fd) {
    SOCK_OR_FAIL(s, fd);
    SOCKET a = accept(s->s, NULL, NULL);
    if (a == INVALID_SOCKET) return wsa_failed();
    u_long off = 0;
    ioctlsocket(a, FIONBIO, &off);
    return new_sock(a);
}
static int clamp(int64_t n) { return n > INT_MAX ? INT_MAX : (int)n; }
int64_t sys_send(int fd, const char *buf, int64_t n, int flags) {
    SOCK_OR_FAIL(s, fd);
    int r = send(s->s, buf, clamp(n), flags);
    return r == SOCKET_ERROR ? wsa_failed() : r;
}
int64_t sys_sendto(int fd, const char *buf, int64_t n, int flags, const char *addr, int addrlen) {
    SOCK_OR_FAIL(s, fd);
    int r = sendto(s->s, buf, clamp(n), flags, (const struct sockaddr *)addr, addrlen);
    return r == SOCKET_ERROR ? wsa_failed() : r;
}
/* Nothing received, with the error cleared, is the end of the stream, as on
   POSIX: so is a socket shut down for receiving, which Winsock reports as
   WSAESHUTDOWN. A datagram longer than the buffer is cut to it, where
   Winsock also fails with WSAEMSGSIZE. */
static int64_t received(int r, int64_t n) {
    if (r != SOCKET_ERROR) return r;
    int e = WSAGetLastError();
    if (e == WSAESHUTDOWN) return 0;
    if (e == WSAEMSGSIZE) return clamp(n);
    last = errno_of_wsa(e);
    return -1;
}
int64_t sys_recv(int fd, char *buf, int64_t n, int flags) {
    last = 0;
    SOCK_OR_FAIL(s, fd);
    int64_t r = received(recv(s->s, buf, clamp(n), flags), n);
    /* the refusal a connected datagram socket hears, as POSIX names it */
    if (r < 0 && s->type == SOCK_DGRAM && last == ECONNRESET) last = ECONNREFUSED;
    return r;
}
int64_t sys_recvfrom(int fd, char *buf, int64_t n, int flags) {
    int len = sizeof address;
    last = 0;
    SOCK_OR_FAIL(s, fd);
    int64_t got = received(recvfrom(s->s, buf, clamp(n), flags, (struct sockaddr *)address, &len), n);
    address_length = got < 0 ? 0 : len;
    return got;
}
int sys_shutdown(int fd, int how) {
    SOCK_OR_FAIL(s, fd);
    return shutdown(s->s, how) == 0 ? 0 : wsa_failed();
}
/* the address of no name of the socket's family: what POSIX gives for a
   socket not yet bound, and for either end of a pair */
static void unnamed(Sock *s) {
    memset(address, 0, sizeof address);
    unsigned short family = (unsigned short)s->domain;
    memcpy(address, &family, sizeof family);
    address_length = s->domain == AF_INET ? (int)sizeof(struct sockaddr_in)
                   : s->domain == AF_INET6 ? (int)sizeof(struct sockaddr_in6) : (int)sizeof family;
}
int sys_sock_name(int fd) {
    int len = sizeof address;
    SOCK_OR_FAIL(s, fd);
    if (s->pair) { unnamed(s); return 0; }
    if (getsockname(s->s, (struct sockaddr *)address, &len) != 0) {
        if (WSAGetLastError() == WSAEINVAL && s->domain >= 0) { unnamed(s); return 0; }
        return wsa_failed();
    }
    address_length = len;
    return 0;
}
int sys_sock_peer(int fd) {
    int len = sizeof address;
    SOCK_OR_FAIL(s, fd);
    if (s->pair) { unnamed(s); return 0; }
    if (getpeername(s->s, (struct sockaddr *)address, &len) != 0) return wsa_failed();
    address_length = len;
    return 0;
}

/* SO_REUSEADDR of POSIX lets a socket bind an address that a connection
   just closed still holds; Winsock's lets it bind one that another socket
   is using, and connections then collide. What POSIX's allows, Winsock
   allows by default, so the option is only remembered. */
int sys_getsockopt(int fd, int level, int name) {
    int value = 0, len = sizeof value;
    SOCK_OR_FAIL(s, fd);
    if (level == SOL_SOCKET && name == SO_REUSEADDR) return s->reuseaddr;
    if (getsockopt(s->s, level, name, (char *)&value, &len) != 0) return wsa_failed();
    /* Winsock tells a connected datagram socket that its peer's port is
       unreachable on its next receive, and never in SO_ERROR, where POSIX
       keeps it until it is read: a receive that peeks finds it, and takes
       it, as reading SO_ERROR does. */
    if (level == SOL_SOCKET && name == SO_ERROR && value == 0 && s->type == SOCK_DGRAM && s->connected) {
        u_long on = 1, off = (u_long)s->nonblocking;
        char byte;
        ioctlsocket(s->s, FIONBIO, &on);
        if (recv(s->s, &byte, 1, MSG_PEEK) == SOCKET_ERROR && WSAGetLastError() == WSAECONNRESET)
            value = ECONNREFUSED;
        ioctlsocket(s->s, FIONBIO, &off);
    }
    return value;
}
int sys_setsockopt(int fd, int level, int name, int value) {
    SOCK_OR_FAIL(s, fd);
    if (level == SOL_SOCKET && name == SO_REUSEADDR) { s->reuseaddr = value != 0; return 0; }
    if (setsockopt(s->s, level, name, (const char *)&value, sizeof value) != 0) return wsa_failed();
    /* kept for remake: the last value of each option */
    int i;
    for (i = 0; i < s->noptions; i++) if (s->options[i].level == level && s->options[i].name == name) break;
    if (i < SOCK_OPTIONS) {
        s->options[i].level = level;
        s->options[i].name = name;
        s->options[i].value = value;
        if (i == s->noptions) s->noptions++;
    }
    return 0;
}
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
    path = native(path);
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
    return posix_path(path_buffer);
}
/* The databases of hosts, protocols and services are Winsock's, which reads
   the files POSIX has under %SystemRoot%\System32\drivers\etc. An entry is
   packed as sys_posix.c packs it: the name, the numbers, then the other
   names, one after another. */
static char strings[8192];
static size_t pack_one(size_t at, const char *part) {
    size_t n = strlen(part);
    if (at + n + 2 >= sizeof strings) return at;
    memcpy(strings + at, part, n);
    at += n;
    strings[at++] = 0;
    return at;
}
static const char *pack(const char *first, char **rest, const char *second) {
    size_t at = 0;
    if (first) at = pack_one(at, first);
    if (second) at = pack_one(at, second);
    for (char **p = rest; p && *p; p++) at = pack_one(at, *p);
    strings[at] = 0;
    return strings;
}
/* the addresses of a host in one part, separated by spaces */
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
const char *sys_host_byname(const char *name) {
    return winsock() != 0 ? NULL : pack_host(gethostbyname(name));
}
const char *sys_host_byaddr(const char *dotted) {
    struct in_addr in;
    if (winsock() != 0) return NULL;
    if (inet_pton(AF_INET, dotted, &in) != 1) { last = EINVAL; return NULL; }
    return pack_host(gethostbyaddr((const char *)&in, sizeof in, AF_INET));
}
const char *sys_hostname(void) {
    if (winsock() != 0) return NULL;
    if (gethostname(path_buffer, (int)sizeof path_buffer) != 0) { wsa_failed(); return NULL; }
    return path_buffer;
}
static const char *pack_proto(struct protoent *p) {
    if (!p) return NULL;
    char number[32];
    snprintf(number, sizeof number, "%d", p->p_proto);
    return pack(p->p_name, p->p_aliases, number);
}
const char *sys_proto_byname(const char *name) {
    return winsock() != 0 ? NULL : pack_proto(getprotobyname(name));
}
const char *sys_proto_bynumber(int number) {
    return winsock() != 0 ? NULL : pack_proto(getprotobynumber(number));
}
/* the name, the port, the protocol, then the other names */
static const char *pack_serv(struct servent *s) {
    if (!s) return NULL;
    char number[32];
    snprintf(number, sizeof number, "%d", ntohs((unsigned short)s->s_port));
    size_t at = pack_one(0, s->s_name);
    at = pack_one(at, number);
    at = pack_one(at, s->s_proto);
    for (char **p = s->s_aliases; p && *p; p++) at = pack_one(at, *p);
    strings[at] = 0;
    return strings;
}
const char *sys_serv_byname(const char *name, const char *protocol) {
    if (winsock() != 0) return NULL;
    return pack_serv(getservbyname(name, protocol && *protocol ? protocol : NULL));
}
const char *sys_serv_byport(int port, const char *protocol) {
    if (winsock() != 0) return NULL;
    return pack_serv(getservbyport(htons((unsigned short)port), protocol && *protocol ? protocol : NULL));
}

/* ---------------------------------------------------------------- processes */
/* Windows has no fork: sys_fork fails, and the core forks by a second VM
   instead (vm/image.c, and the section "fork" below). A program is started
   by CreateProcess (sys_spawn), which gives it only the three handles it is
   to have as its standard streams; exec without a fork is a program
   started so, waited for, and ended with; and the children are kept here,
   with the handles that waitpid waits on. A signal is not a thing of Windows: Rune has no
   handlers for them, so a program can only see a signal's default action,
   and that is the end of the process, which TerminateProcess gives, with an
   exit code no program gives (SIGNALLED_BY with the signal in its low bits)
   for waitpid to tell apart. */
#define SIGNALLED_BY 0xE0520000u
int sys_fork(void) { return fail(); }

typedef struct { DWORD pid; HANDLE process; } Child;
static Child *children = NULL;
static int nchildren = 0, children_cap = 0;
static int add_child(DWORD pid, HANDLE process) {
    if (nchildren == children_cap) {
        int cap = children_cap ? children_cap * 2 : 16;
        Child *bigger = realloc(children, (size_t)cap * sizeof *children);
        if (!bigger) return -1;
        children = bigger;
        children_cap = cap;
    }
    children[nchildren].pid = pid;
    children[nchildren].process = process;
    nchildren++;
    return 0;
}

/* The command line of Windows, which the program splits into arguments
   again: an argument with a blank or a quote in it is quoted as msvcrt reads
   quotes, a run of backslashes doubled before a quote. */
static char *command_line(char *const argv[]) {
    size_t cap = 16;
    for (char *const *a = argv; *a; a++) cap += 2 * strlen(*a) + 3;
    char *line = malloc(cap), *o = line;
    if (!line) return NULL;
    for (char *const *a = argv; *a; a++) {
        const char *s = *a;
        if (a != argv) *o++ = ' ';
        if (*s && !strpbrk(s, " \t\n\v\"")) { strcpy(o, s); o += strlen(s); continue; }
        *o++ = '"';
        for (;; s++) {
            size_t slashes = 0;
            while (*s == '\\') { slashes++; s++; }
            if (!*s) { while (slashes--) { *o++ = '\\'; *o++ = '\\'; } break; }
            if (*s == '"') { for (size_t i = 0; i < 2 * slashes + 1; i++) *o++ = '\\'; }
            else while (slashes--) *o++ = '\\';
            *o++ = *s;
        }
        *o++ = '"';
    }
    *o = 0;
    return line;
}
/* the file a program is: the path, or with an extension of PATHEXT when it
   has none; searched for on PATH when search is set and it has no
   directory. out gets it; 0, or -1 with ENOENT. */
static int find_program(const char *path, int search, char *out, size_t n) {
    const char *exts = getenv("PATHEXT");
    if (!exts) exts = ".COM;.EXE;.BAT;.CMD";
    const char *slash = strpbrk(path, "/\\"), *dot = strrchr(path, '.');
    int has_ext = dot && (!slash || dot > strrchr(path, slash[0]));
    const char *dirs = search && !slash && !is_drive(path) ? getenv("PATH") : NULL;
    const char *d = dirs ? dirs : "";
    for (;;) {
        const char *end = dirs ? strchr(d, ';') : NULL;
        size_t k = dirs ? (end ? (size_t)(end - d) : strlen(d)) : 0;
        char base[MAX_PATH * 4];
        if (dirs) snprintf(base, sizeof base, "%.*s\\%s", (int)k, d, path);
        else snprintf(base, sizeof base, "%s", path);
        DWORD a = GetFileAttributesA(base);
        if (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY) && (has_ext || !dirs)) {
            snprintf(out, n, "%s", base);
            return 0;
        }
        if (!has_ext)
            for (const char *e = exts; *e; ) {
                const char *eend = strchr(e, ';');
                size_t ek = eend ? (size_t)(eend - e) : strlen(e);
                snprintf(out, n, "%s%.*s", base, (int)ek, e);
                a = GetFileAttributesA(out);
                if (a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY)) return 0;
                if (!eend) break;
                e = eend + 1;
            }
        if (!dirs || !end) break;
        d = end + 1;
    }
    last = ENOENT;
    return -1;
}
/* the handle a descriptor of the library stands for */
static HANDLE handle_of(int fd) {
    Sock *s = sock_of(fd);
    return s ? (HANDLE)s->s : (HANDLE)_get_osfhandle(fd);
}
/* Start the program; its process handle is kept as a child's, and a job,
   when one is given, gets it before it runs. extra, when given, is an
   inheritable handle the program inherits besides its standard ones. */
static int64_t spawn(const char *path, char *const argv[], char *const envp[], int search,
                     const int fds[3], HANDLE job, const char *raw, HANDLE extra) {
    /* raw: a command line given whole, for a program that reads it its own
       way (cmd.exe). Windows takes 32767 characters at most, which is
       E2BIG before the program is looked for, as execve counts the
       arguments before it opens the file. */
    char *line = raw ? _strdup(raw) : command_line(argv);
    if (!line) { last = ENOMEM; return -1; }
    if (strlen(line) > 32766) { free(line); last = E2BIG; return -1; }
    char program[MAX_PATH * 4];
    if (find_program(native(path), search, program, sizeof program) != 0) { free(line); return -1; }
    /* a batch file is run by the command interpreter */
    const char *dot = strrchr(program, '.');
    int batch = !raw && dot && (_stricmp(dot, ".bat") == 0 || _stricmp(dot, ".cmd") == 0);
    char *app = program;
    char comspec[MAX_PATH * 4];
    if (batch) {
        const char *c = getenv("COMSPEC");
        snprintf(comspec, sizeof comspec, "%s", c ? c : "C:\\Windows\\System32\\cmd.exe");
        char *wrapped = malloc(strlen(line) + strlen(program) + 32);
        if (!wrapped) { free(line); last = ENOMEM; return -1; }
        sprintf(wrapped, "cmd /d /s /c \"\"%s\" %s\"", program, strchr(line, ' ') ? strchr(line, ' ') + 1 : "");
        free(line);
        line = wrapped;
        app = comspec;
    }
    /* the environment: the variables, each NUL-terminated, then an empty one */
    char *block = NULL;
    if (envp) {
        size_t size = 2;
        for (char *const *e = envp; *e; e++) size += strlen(*e) + 1;
        block = malloc(size);
        if (!block) { free(line); last = ENOMEM; return -1; }
        char *o = block;
        for (char *const *e = envp; *e; e++) { strcpy(o, *e); o += strlen(*e) + 1; }
        *o++ = 0;
        if (o == block + 1) *o = 0;
    }
    /* the three handles, as inheritable copies, and only they inherited */
    HANDLE std[3], list[4];
    int nlist = 0;
    for (int i = 0; i < 3; i++) {
        HANDLE h = handle_of(fds[i] >= 0 ? fds[i] : i);
        std[i] = INVALID_HANDLE_VALUE;
        if (h != INVALID_HANDLE_VALUE && h != NULL &&
            DuplicateHandle(GetCurrentProcess(), h, GetCurrentProcess(), &std[i], 0, TRUE, DUPLICATE_SAME_ACCESS))
            list[nlist++] = std[i];
    }
    if (extra) list[nlist++] = extra;
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(NULL, 1, 0, &size);
    LPPROC_THREAD_ATTRIBUTE_LIST attributes = malloc(size);
    STARTUPINFOEXA si;
    memset(&si, 0, sizeof si);
    si.StartupInfo.cb = sizeof si;
    si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    si.StartupInfo.hStdInput = std[0];
    si.StartupInfo.hStdOutput = std[1];
    si.StartupInfo.hStdError = std[2];
    int ok = attributes && InitializeProcThreadAttributeList(attributes, 1, 0, &size);
    if (ok && nlist > 0)
        ok = UpdateProcThreadAttribute(attributes, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, list,
                                       (SIZE_T)nlist * sizeof(HANDLE), NULL, NULL);
    si.lpAttributeList = attributes;
    PROCESS_INFORMATION pi;
    DWORD flags = EXTENDED_STARTUPINFO_PRESENT | (job ? CREATE_SUSPENDED : 0);
    if (ok) ok = CreateProcessA(app, line, NULL, NULL, nlist > 0, flags, block, NULL, &si.StartupInfo, &pi);
    DWORD error = GetLastError();
    for (int i = 0; i < 3; i++) if (std[i] != INVALID_HANDLE_VALUE) CloseHandle(std[i]);
    if (attributes) { DeleteProcThreadAttributeList(attributes); free(attributes); }
    free(line);
    free(block);
    if (!ok) {
        last = error == ERROR_BAD_EXE_FORMAT ? ENOEXEC : errno_of_win(error);
        return -1;
    }
    if (job) {
        AssignProcessToJobObject(job, pi.hProcess);
        ResumeThread(pi.hThread);
    }
    CloseHandle(pi.hThread);
    if (add_child(pi.dwProcessId, pi.hProcess) != 0) { last = ENOMEM; return -1; }
    return (int64_t)pi.dwProcessId;
}
int64_t sys_spawn(const char *path, char *const argv[], char *const envp[], int search, const int fds[3]) {
    return spawn(path, argv, envp, search, fds, NULL, NULL, NULL);
}

/* How a process ended, as waitpid tells it: 0 exited with a status, or 1
   ended by a signal. An exception of Windows that ends a program is the
   signal POSIX would have sent for it. */
static void status_of(DWORD code, int64_t out[2]) {
    if ((code & 0xFFFF0000u) == SIGNALLED_BY) { out[0] = 1; out[1] = (int64_t)(code & 0xFFFFu); return; }
    int signal = 0;
    switch (code) {
    case 0xC0000005: case 0xC00000FD: signal = 11; break;   /* access violation, stack overflow: SEGV */
    case 0xC000013A: signal = 2; break;                     /* ^C: INT */
    case 0xC0000094: case 0xC000008E: case 0xC0000091: signal = 8; break;   /* FPE */
    case 0xC000001D: case 0xC0000096: signal = 4; break;    /* ILL */
    case 0xC0000409: case 0x80000003: signal = 6; break;    /* fail fast, breakpoint: ABRT */
    }
    if (signal) { out[0] = 1; out[1] = signal; }
    else { out[0] = 0; out[1] = (int64_t)(code & 0xFF); }
}
/* a child that has ended: its status, its processor time added to the
   children's, and its handle closed */
static void reap_child(int i, int64_t out[3]) {
    DWORD code = 0;
    GetExitCodeProcess(children[i].process, &code);
    FILETIME c, e, k, u;
    if (GetProcessTimes(children[i].process, &c, &e, &k, &u)) {
        children_user += of_filetime(u);
        children_sys += of_filetime(k);
    }
    out[0] = (int64_t)children[i].pid;
    status_of(code, out + 1);
    CloseHandle(children[i].process);
    children[i] = children[--nchildren];
}
/* waitpid: a child by its number, or any (-1; a group, which Windows does
   not have, is taken for all of them); WNOHANG (1) does not wait, and says
   0 when none has ended. */
int sys_waitpid(int64_t pid, int flags, int64_t out[3]) {
    int nohang = flags & 1;
    if (pid > 0) {
        int i;
        for (i = 0; i < nchildren; i++) if ((int64_t)children[i].pid == pid) break;
        if (i == nchildren) { last = ECHILD; return -1; }
        DWORD r = WaitForSingleObject(children[i].process, nohang ? 0 : INFINITE);
        if (r == WAIT_TIMEOUT) { out[0] = 0; out[1] = out[2] = 0; return 0; }
        if (r != WAIT_OBJECT_0) return win_failed(NULL);
        reap_child(i, out);
        return 0;
    }
    if (nchildren == 0) { last = ECHILD; return -1; }
    for (;;) {
        /* WaitForMultipleObjects takes 64 at a time */
        for (int from = 0; from < nchildren; from += MAXIMUM_WAIT_OBJECTS) {
            int n = nchildren - from < MAXIMUM_WAIT_OBJECTS ? nchildren - from : MAXIMUM_WAIT_OBJECTS;
            HANDLE hs[MAXIMUM_WAIT_OBJECTS];
            for (int k = 0; k < n; k++) hs[k] = children[from + k].process;
            DWORD wait = nohang || nchildren > MAXIMUM_WAIT_OBJECTS ? 0 : INFINITE;
            DWORD r = WaitForMultipleObjects((DWORD)n, hs, FALSE, wait);
            if (r < WAIT_OBJECT_0 + (DWORD)n) { reap_child(from + (int)(r - WAIT_OBJECT_0), out); return 0; }
            if (r == WAIT_FAILED) return win_failed(NULL);
        }
        if (nohang) { out[0] = 0; out[1] = out[2] = 0; return 0; }
        Sleep(10);
    }
}

/* kill: the default action of the signal. 0 asks whether the process is
   there; CHLD and CONT do nothing to a process that runs; the signals that
   stop one (STOP, TSTP, TTIN, TTOU) Windows cannot give; every other ends
   it. A process group is not a thing of Windows. */
int sys_kill(int64_t pid, int signal) {
    if (signal < 0 || signal > 64) { last = EINVAL; return -1; }
    if (pid <= 0) { last = ENOSYS; return -1; }
    if (signal >= 19 && signal <= 22) { last = ENOSYS; return -1; }
    HANDLE h = NULL;
    int own = 0;
    if ((DWORD)pid == GetCurrentProcessId()) h = GetCurrentProcess();
    for (int i = 0; !h && i < nchildren; i++) if ((int64_t)children[i].pid == pid) { h = children[i].process; own = 1; }
    if (!h) {
        h = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, (DWORD)pid);
        if (!h) { last = GetLastError() == ERROR_ACCESS_DENIED ? EPERM : ESRCH; return -1; }
    }
    DWORD code = 0;
    int running = GetExitCodeProcess(h, &code) && code == STILL_ACTIVE;
    int r = 0;
    if (!running && !own && h != GetCurrentProcess()) { last = ESRCH; r = -1; }
    else if (running && signal != 0 && signal != 17 && signal != 18) {
        /* nothing is flushed, as nothing is when a signal ends a process */
        if (!TerminateProcess(h, SIGNALLED_BY | (DWORD)signal)) r = win_failed(NULL);
    }
    if (!own && h != GetCurrentProcess()) CloseHandle(h);
    return r;
}

/* alarm: a timer that ends the process as SIGALRM would, there being no
   handler; the seconds that were left of the one before. */
static HANDLE alarm_timer = NULL;
static ULONGLONG alarm_due = 0;
__attribute__((force_align_arg_pointer))
static VOID CALLBACK ring(PVOID data, BOOLEAN fired) {
    (void)data; (void)fired;
    TerminateProcess(GetCurrentProcess(), SIGNALLED_BY | 14);
}
int sys_alarm(int seconds) {
    int left = 0;
    if (alarm_timer) {
        ULONGLONG now = GetTickCount64();
        if (alarm_due > now) left = (int)((alarm_due - now + 999) / 1000);
        DeleteTimerQueueTimer(NULL, alarm_timer, NULL);
        alarm_timer = NULL;
    }
    if (seconds > 0) {
        if (!CreateTimerQueueTimer(&alarm_timer, NULL, ring, NULL, (DWORD)seconds * 1000, 0, WT_EXECUTEONLYONCE))
            return win_failed(NULL);
        alarm_due = GetTickCount64() + (ULONGLONG)seconds * 1000;
    }
    return left;
}
/* _exit and _Exit end in ExitProcess, which lets msvcrt.dll flush every
   stream as it is unloaded; a process that ends itself does not unload
   anything. */
void sys_exit_now(int status) {
    TerminateProcess(GetCurrentProcess(), (UINT)status);
    _exit(status);
}
/* pause: only a signal ends it, and every signal ends the process */
int sys_pause(void) {
    for (;;) Sleep(INFINITE);
}

/* exec, without a fork: the program is started with this one's standard
   streams, in a job that ends it when this process ends (so that a kill of
   this one reaches it), and this process waits for it and ends with its
   status, which its parent then sees. The program gets nothing but its
   standard streams, so every other descriptor and socket is closed before
   the wait, or this process would hold, say, the writing end of a pipe
   whose reader then waits for its end as long as the program runs. */
int sys_exec(const char *path, char *const argv[], char *const envp[], int search) {
    HANDLE job = CreateJobObjectA(NULL, NULL);
    if (job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits;
        memset(&limits, 0, sizeof limits);
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof limits);
    }
    int fds[3] = { -1, -1, -1 };
    int64_t pid = spawn(path, argv, envp, search, fds, job, NULL, NULL);
    if (pid < 0) { if (job) CloseHandle(job); return -1; }
    HANDLE process = children[nchildren - 1].process;
    for (int fd = 3; fd < FD_TABLE; fd++) if (_get_osfhandle(fd) != -1) _close(fd);
    for (int i = 0; i < nsocks; i++) if (socks[i].used) { closesocket(socks[i].s); socks[i].used = 0; }
    WaitForSingleObject(process, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(process, &code);
    sys_exit_now((int)code);
    return -1;   /* not reached */
}

/* system: the command interpreter of Windows (COMSPEC) runs the command,
   which it is given whole, as /s /c "command" keeps it; the status as the
   POSIX layer gives it, what the command exited with or 256 and the signal
   that ended it. msvcrt's own system would hand the command every
   descriptor of msvcrt this process has open. */
int sys_system(const char *command) {
    const char *comspec = getenv("COMSPEC");
    if (!comspec) comspec = "C:\\Windows\\System32\\cmd.exe";
    char *line = malloc(strlen(command) + 32);
    if (!line) { last = ENOMEM; return -1; }
    sprintf(line, "cmd /d /s /c \"%s\"", command);
    char *argv[] = { (char *)comspec, NULL };
    int fds[3] = { -1, -1, -1 };
    int64_t pid = spawn(comspec, argv, NULL, 0, fds, NULL, line, NULL);
    free(line);
    if (pid < 0) return -1;
    int64_t out[3];
    if (sys_waitpid(pid, 0, out) != 0) return -1;
    return out[1] == 0 ? (int)out[2] : 256 + (int)out[2];
}

/* ---------------------------------------------------------------- fork */
/* fork by a second VM (vm/image.c), there being no fork. The child is this
   runevm, started as `runevm --resume HANDLE` with this one's standard
   handles and the reading end of a pipe, which is all it inherits. The
   rest it gets as Windows hands things to another process: each
   descriptor's handle by DuplicateHandle and each socket by
   WSADuplicateSocket, the close-on-exec ones as well, since close-on-exec
   matters only at exec. Through the pipe go first this layer's part --
   the handles by descriptor with the flags kept here, the sockets with
   what their table knows, each directory stream by its pattern and how
   far it has read, and the umask -- and then the core's image. The child
   gives each descriptor and socket its number again, which SML values
   hold. msvcrt's own way of handing on descriptors (lpReserved2) is not
   used: it names handles, which the kernel copies only if they are
   inheritable. */
int sys_has_fork(void) { return 0; }
FILE *sys_fdopen(int fd, const char *mode) { return _fdopen(fd, mode); }

typedef struct { int fd; uint64_t handle; FdFlags flags; } ForkFd;
typedef struct { int slot; WSAPROTOCOL_INFOW info; Sock sock; } ForkSock;
typedef struct { int slot, pending; int64_t reads; char pattern[MAX_PATH * 4]; } ForkDir;
static int64_t fork_child = -1;

FILE *sys_fork_start(void) {
    char self[MAX_PATH * 4];
    DWORD length = GetModuleFileNameA(NULL, self, sizeof self);
    if (length == 0 || length >= sizeof self) { win_failed(NULL); return NULL; }
    HANDLE rd, wr, inherited;
    if (!CreatePipe(&rd, &wr, NULL, 1 << 16)) { win_failed(NULL); return NULL; }
    int ok = DuplicateHandle(GetCurrentProcess(), rd, GetCurrentProcess(), &inherited, 0, TRUE, DUPLICATE_SAME_ACCESS);
    CloseHandle(rd);
    if (!ok) { win_failed(NULL); CloseHandle(wr); return NULL; }
    char token[32];
    snprintf(token, sizeof token, "%llu", (unsigned long long)(uintptr_t)inherited);
    char resume[] = "--resume";
    char *argv[] = { self, resume, token, NULL };
    int fds[3] = { -1, -1, -1 };
    int64_t pid = spawn(self, argv, NULL, 0, fds, NULL, NULL, inherited);
    CloseHandle(inherited);
    if (pid < 0) { CloseHandle(wr); return NULL; }
    HANDLE child = children[nchildren - 1].process;
    int image = _open_osfhandle((intptr_t)wr, _O_BINARY | _O_WRONLY);
    FILE *out = image >= 0 ? _fdopen(image, "wb") : NULL;
    if (!out) {
        if (image >= 0) _close(image); else CloseHandle(wr);
        last = ENOMEM;
        return NULL;
    }
    fork_child = pid;
    setvbuf(out, NULL, _IOFBF, 1 << 20);   /* the image is the whole heap */

    ForkFd *given = malloc(FD_TABLE * sizeof *given);
    uint32_t n = 0;
    for (int fd = 0; given && fd < FD_TABLE; fd++) {
        HANDLE h = (HANDLE)_get_osfhandle(fd);
        HANDLE copy;
        if (fd == image || h == INVALID_HANDLE_VALUE || h == NULL || h == (HANDLE)(intptr_t)-2) continue;
        if (!DuplicateHandle(GetCurrentProcess(), h, child, &copy, 0, FALSE, DUPLICATE_SAME_ACCESS)) continue;
        given[n].fd = fd;
        given[n].handle = (uint64_t)(uintptr_t)copy;
        given[n].flags = fd_flags[fd];
        n++;
    }
    fwrite(&n, sizeof n, 1, out);
    if (n > 0) fwrite(given, sizeof *given, n, out);
    free(given);

    uint32_t nsock = 0;
    for (int i = 0; i < nsocks; i++) if (socks[i].used) nsock++;
    fwrite(&nsock, sizeof nsock, 1, out);
    for (int i = 0; i < nsocks; i++) {
        if (!socks[i].used) continue;
        ForkSock f;
        memset(&f, 0, sizeof f);
        f.slot = i;
        f.sock = socks[i];
        /* one that cannot be handed on goes as a slot the child leaves closed */
        if (WSADuplicateSocketW(socks[i].s, (DWORD)pid, &f.info) != 0) f.slot = -1;
        fwrite(&f, sizeof f, 1, out);
    }

    uint32_t ndirs = 0;
    for (int i = 0; i < DIRS; i++) if (dirs[i].used) ndirs++;
    fwrite(&ndirs, sizeof ndirs, 1, out);
    for (int i = 0; i < DIRS; i++) {
        if (!dirs[i].used) continue;
        ForkDir d;
        d.slot = i;
        d.pending = dirs[i].pending;
        d.reads = dirs[i].reads;
        memcpy(d.pattern, dirs[i].pattern, sizeof d.pattern);
        fwrite(&d, sizeof d, 1, out);
    }
    fwrite(&creation_mask, sizeof creation_mask, 1, out);
    return out;
}

int64_t sys_fork_finish(FILE *image) {
    fclose(image);
    return fork_child;
}

/* This layer's part is read from the pipe's handle itself, before any
   descriptor is made for it, so that the descriptor cannot take a number
   that one of the parent's is to have. */
static int read_exactly(HANDLE h, void *p, DWORD n) {
    char *at = p;
    while (n > 0) {
        DWORD got = 0;
        if (!ReadFile(h, at, n, &got, NULL) || got == 0) return 0;
        at += got;
        n -= got;
    }
    return 1;
}
/* the socket table with a slot i, the new ones unused */
static int sock_slot(int i) {
    while (nsocks <= i) {
        if (nsocks == socks_cap) {
            int cap = socks_cap ? socks_cap * 2 : 16;
            Sock *bigger = realloc(socks, (size_t)cap * sizeof *socks);
            if (!bigger) return -1;
            socks = bigger;
            socks_cap = cap;
        }
        socks[nsocks++].used = 0;
    }
    return 0;
}
FILE *sys_resume(const char *token) {
    char *end;
    unsigned long long value = strtoull(token, &end, 10);
    if (end == token || *end != 0) { last = EINVAL; return NULL; }
    HANDLE h = (HANDLE)(uintptr_t)value;

    uint32_t n = 0;
    if (!read_exactly(h, &n, sizeof n) || n > FD_TABLE) { last = EIO; return NULL; }
    int have[3] = { 0, 0, 0 };
    for (uint32_t k = 0; k < n; k++) {
        ForkFd f;
        if (!read_exactly(h, &f, sizeof f)) { last = EIO; return NULL; }
        if (f.fd < 0 || f.fd >= FD_TABLE) continue;
        HANDLE given = (HANDLE)(uintptr_t)f.handle;
        int fd = _open_osfhandle((intptr_t)given, _O_BINARY | (f.flags.crt_append ? _O_APPEND : 0));
        if (fd < 0) { CloseHandle(given); continue; }
        if (fd != f.fd) {
            int moved = _dup2(fd, f.fd) == 0;
            _close(fd);
            if (!moved) continue;
        }
        fd_flags[f.fd] = f.flags;
        if (f.fd < 3) have[f.fd] = 1;
    }
    /* a standard descriptor the parent had closed */
    for (int fd = 0; fd < 3; fd++) if (!have[fd]) _close(fd);

    uint32_t nsock = 0;
    if (!read_exactly(h, &nsock, sizeof nsock)) { last = EIO; return NULL; }
    for (uint32_t k = 0; k < nsock; k++) {
        ForkSock f;
        if (!read_exactly(h, &f, sizeof f)) { last = EIO; return NULL; }
        if (f.slot < 0 || winsock() != 0 || sock_slot(f.slot) != 0) continue;
        SOCKET s = WSASocketW(FROM_PROTOCOL_INFO, FROM_PROTOCOL_INFO, FROM_PROTOCOL_INFO, &f.info, 0,
                              WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT);
        if (s == INVALID_SOCKET) continue;
        socks[f.slot] = f.sock;
        socks[f.slot].s = s;
        socks[f.slot].used = 1;
    }

    uint32_t ndirs = 0;
    if (!read_exactly(h, &ndirs, sizeof ndirs)) { last = EIO; return NULL; }
    for (uint32_t k = 0; k < ndirs; k++) {
        ForkDir d;
        if (!read_exactly(h, &d, sizeof d)) { last = EIO; return NULL; }
        if (d.slot < 0 || d.slot >= DIRS) continue;
        int i = d.slot;
        memcpy(dirs[i].pattern, d.pattern, sizeof d.pattern);
        dirs[i].pattern[sizeof dirs[i].pattern - 1] = 0;
        if (dir_start(i) != 0) continue;
        for (int64_t r = 0; r < d.reads && FindNextFileA(dirs[i].find, &dirs[i].data); r++) dirs[i].reads++;
        dirs[i].pending = d.pending;
        dirs[i].used = 1;
    }
    if (!read_exactly(h, &creation_mask, sizeof creation_mask)) { last = EIO; return NULL; }

    int fd = _open_osfhandle((intptr_t)h, _O_BINARY | _O_RDONLY);
    if (fd < 0) { last = EMFILE; return NULL; }
    FILE *in = _fdopen(fd, "rb");
    if (!in) { _close(fd); last = ENOMEM; return NULL; }
    setvbuf(in, NULL, _IOFBF, 1 << 20);
    return in;
}

/* ---------------------------------------------------------------- Windows */
/* The structure Windows of the Basis Library (lib/basis/windows.sml).

   A key of the registry is a number of this table; the seven keys at the
   roots are 0 to 6, in the order of the specification (classesRoot,
   currentUser, localMachine, users, performanceData, currentConfig,
   dynData), and are never closed. Names and strings go through the code
   page of Windows (the A calls), as the rest of this file does. */
#define WIN_KEYS 256
static HKEY win_keys[WIN_KEYS];
static int win_key_used[WIN_KEYS];
static HKEY key_of(int k) {
    static const HKEY roots[7] = {
        HKEY_CLASSES_ROOT, HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE, HKEY_USERS,
        HKEY_PERFORMANCE_DATA, HKEY_CURRENT_CONFIG, HKEY_DYN_DATA
    };
    if (k >= 0 && k < 7) return roots[k];
    if (k >= 7 && k < WIN_KEYS && win_key_used[k]) return win_keys[k];
    return NULL;
}
/* the error of a call of the registry, which returns it */
static int reg_failed(LONG e) { last = errno_of_win((DWORD)e); return -1; }

/* open or, when create is set, create: out[0] 1 made, 2 opened; out[1] the key */
int sys_win_reg_open(int key, const char *name, int access, int create, int64_t out[2]) {
    HKEY parent = key_of(key), made;
    if (!parent) { last = EBADF; return -1; }
    int k;
    for (k = 7; k < WIN_KEYS; k++) if (!win_key_used[k]) break;
    if (k == WIN_KEYS) { last = EMFILE; return -1; }
    DWORD disposition = REG_OPENED_EXISTING_KEY;
    LONG r = create ? RegCreateKeyExA(parent, name, 0, NULL, REG_OPTION_NON_VOLATILE, (REGSAM)access, NULL, &made, &disposition)
                    : RegOpenKeyExA(parent, name, 0, (REGSAM)access, &made);
    if (r != ERROR_SUCCESS) return reg_failed(r);
    win_keys[k] = made;
    win_key_used[k] = 1;
    out[0] = disposition == REG_CREATED_NEW_KEY ? 1 : 2;
    out[1] = k;
    return 0;
}
int sys_win_reg_close(int key) {
    if (key < 7) return 0;
    HKEY h = key_of(key);
    if (!h) { last = EBADF; return -1; }
    win_key_used[key] = 0;
    LONG r = RegCloseKey(h);
    return r == ERROR_SUCCESS ? 0 : reg_failed(r);
}
int sys_win_reg_delete(int key, const char *name, int value) {
    HKEY h = key_of(key);
    if (!h) { last = EBADF; return -1; }
    LONG r = value ? RegDeleteValueA(h, name) : RegDeleteKeyA(h, name);
    return r == ERROR_SUCCESS ? 0 : reg_failed(r);
}
/* The name of the index-th subkey (or value): NULL with the error cleared
   when there are no more, NULL with an error on failure. */
static char reg_name[16384 + 1];
const char *sys_win_reg_enum(int key, int index, int value) {
    HKEY h = key_of(key);
    if (!h) { last = EBADF; return NULL; }
    DWORD n = sizeof reg_name;
    LONG r = value ? RegEnumValueA(h, (DWORD)index, reg_name, &n, NULL, NULL, NULL, NULL)
                   : RegEnumKeyExA(h, (DWORD)index, reg_name, &n, NULL, NULL, NULL, NULL);
    if (r == ERROR_NO_MORE_ITEMS) { last = 0; return NULL; }
    if (r != ERROR_SUCCESS) { reg_failed(r); return NULL; }
    reg_name[n] = 0;
    return reg_name;
}
/* The value named: its type of the registry and its bytes, as the registry
   keeps them (a string with its NUL). *length is -1 with the error cleared
   when there is no such value. */
static char *reg_data = NULL;
const char *sys_win_reg_query(int key, const char *name, int *type, int64_t *length) {
    HKEY h = key_of(key);
    if (!h) { last = EBADF; return NULL; }
    DWORD t = 0, n = 0;
    LONG r = RegQueryValueExA(h, name, NULL, &t, NULL, &n);
    if (r == ERROR_FILE_NOT_FOUND) { last = 0; *length = -1; return ""; }
    if (r != ERROR_SUCCESS) { reg_failed(r); return NULL; }
    free(reg_data);
    reg_data = malloc(n + 2);
    if (!reg_data) { last = ENOMEM; return NULL; }
    r = RegQueryValueExA(h, name, NULL, &t, (BYTE *)reg_data, &n);
    if (r != ERROR_SUCCESS) { reg_failed(r); return NULL; }
    *type = (int)t;
    *length = (int64_t)n;
    return reg_data;
}
int sys_win_reg_set(int key, const char *name, int type, const char *data, int64_t length) {
    HKEY h = key_of(key);
    if (!h) { last = EBADF; return -1; }
    LONG r = RegSetValueExA(h, name, 0, (DWORD)type, (const BYTE *)data, (DWORD)length);
    return r == ERROR_SUCCESS ? 0 : reg_failed(r);
}

/* Config: 0 the directory of Windows, 1 its system directory, 2 the name of
   the computer, 3 the name of the user; written as Windows writes them
   (C:\Windows), as the specification has it. */
static char win_string[MAX_PATH * 4];
const char *sys_win_config(int what) {
    DWORD n = sizeof win_string;
    BOOL ok;
    switch (what) {
    case 0: n = GetWindowsDirectoryA(win_string, sizeof win_string); ok = n > 0 && n < sizeof win_string; break;
    case 1: n = GetSystemDirectoryA(win_string, sizeof win_string); ok = n > 0 && n < sizeof win_string; break;
    case 2: ok = GetComputerNameA(win_string, &n); break;
    case 3: ok = GetUserNameA(win_string, &n); break;
    default: last = EINVAL; return NULL;
    }
    if (!ok) { win_failed(NULL); return NULL; }
    return win_string;
}
/* the version, as RtlGetVersion gives it (GetVersionEx gives what the
   program's manifest asks for): major, minor, build, platform; and the
   service pack */
const char *sys_win_version(int64_t out[4]) {
    typedef LONG (WINAPI *RtlGetVersionFn)(PRTL_OSVERSIONINFOW);
    RtlGetVersionFn get = (RtlGetVersionFn)(void (*)(void))GetProcAddress(GetModuleHandleA("ntdll.dll"), "RtlGetVersion");
    RTL_OSVERSIONINFOW v;
    memset(&v, 0, sizeof v);
    v.dwOSVersionInfoSize = sizeof v;
    if (!get || get(&v) != 0) { last = ENOSYS; return NULL; }
    out[0] = v.dwMajorVersion; out[1] = v.dwMinorVersion; out[2] = v.dwBuildNumber; out[3] = v.dwPlatformId;
    int n = WideCharToMultiByte(CP_ACP, 0, v.szCSDVersion, -1, win_string, (int)sizeof win_string, NULL, NULL);
    if (n <= 0) win_string[0] = 0;
    return win_string;
}
/* the volume whose root is given: its name and the name of its file system,
   one after the other; out[0] the serial, out[1] the longest name */
static char volume_strings[2 * (MAX_PATH + 1)];
const char *sys_win_volume(const char *root, int64_t out[2]) {
    char path[MAX_PATH * 4];
    snprintf(path, sizeof path - 1, "%s", native(root));
    size_t k = strlen(path);
    if (k > 0 && path[k - 1] != '\\' && path[k - 1] != '/') { path[k] = '\\'; path[k + 1] = 0; }
    char name[MAX_PATH + 1], system[MAX_PATH + 1];
    DWORD serial = 0, longest = 0, flags = 0;
    if (!GetVolumeInformationA(path, name, sizeof name, &serial, &longest, &flags, system, sizeof system))
        { win_failed(path); return NULL; }
    size_t a = strlen(name);
    memcpy(volume_strings, name, a + 1);
    memcpy(volume_strings + a + 1, system, strlen(system) + 1);
    out[0] = (int64_t)serial;
    out[1] = (int64_t)longest;
    return volume_strings;
}
/* the program Windows would open the file with (FindExecutable); NULL with
   the error cleared when there is none */
const char *sys_win_find_executable(const char *name) {
    HINSTANCE r = FindExecutableA(native(name), NULL, win_string);
    if ((INT_PTR)r > 32) return posix_path(win_string);
    last = (INT_PTR)r == SE_ERR_NOASSOC || (INT_PTR)r == ERROR_FILE_NOT_FOUND || (INT_PTR)r == ERROR_PATH_NOT_FOUND ? 0 : EIO;
    return NULL;
}
/* ShellExecute, "open": a program with its argument (launchApplication), or
   a document with the program that opens it (openDocument) */
int sys_win_shell_execute(const char *file, const char *arg, int document) {
    const char *f = native(file);
    if (!document && !executable(f)) { last = ENOEXEC; return -1; }
    HINSTANCE r = ShellExecuteA(NULL, "open", f, document ? NULL : arg, NULL, SW_SHOWNORMAL);
    if ((INT_PTR)r > 32) return 0;
    switch ((INT_PTR)r) {
    case ERROR_FILE_NOT_FOUND: case ERROR_PATH_NOT_FOUND: last = ENOENT; break;
    case SE_ERR_ACCESSDENIED: last = EACCES; break;
    case ERROR_BAD_FORMAT: last = ENOEXEC; break;
    case SE_ERR_NOASSOC: case SE_ERR_ASSOCINCOMPLETE: last = ENOEXEC; break;
    default: last = EIO;
    }
    return -1;
}
/* A program with its arguments as one string, as CreateProcess takes them
   (Windows.execute and simpleExecute), and fds[] its standard streams. */
int64_t sys_win_spawn(const char *command, const char *arg, const int fds[3]) {
    char *line = malloc(strlen(command) + strlen(arg) + 8);
    if (!line) { last = ENOMEM; return -1; }
    sprintf(line, "\"%s\"%s%s", command, *arg ? " " : "", arg);
    char *argv[] = { (char *)command, NULL };
    int64_t pid = spawn(command, argv, NULL, 0, fds, NULL, line, NULL);
    free(line);
    return pid;
}
/* wait for a child and give the code it ended with, all 32 bits of it,
   which is what Windows.reap gives */
int sys_win_wait(int64_t pid, int64_t *code) {
    for (int i = 0; i < nchildren; i++) {
        if ((int64_t)children[i].pid != pid) continue;
        if (WaitForSingleObject(children[i].process, INFINITE) != WAIT_OBJECT_0) return win_failed(NULL);
        DWORD c = 0;
        GetExitCodeProcess(children[i].process, &c);
        FILETIME a, e, k, u;
        if (GetProcessTimes(children[i].process, &a, &e, &k, &u)) {
            children_user += of_filetime(u);
            children_sys += of_filetime(k);
        }
        CloseHandle(children[i].process);
        children[i] = children[--nchildren];
        *code = (int64_t)c;
        return 0;
    }
    last = ECHILD;
    return -1;
}

/* DDE, as a client: a conversation with a service on a topic, in which
   commands are executed. Each conversation has its own instance of DDEML,
   and is a number of this table. A transaction waits for as long as the
   delay, and a busy service is asked again as many times as the retries
   say. */
#define DDE_CONVERSATIONS 64
static struct { int used; DWORD instance; HCONV conversation; } dde[DDE_CONVERSATIONS];
__attribute__((force_align_arg_pointer))
static HDDEDATA CALLBACK dde_callback(UINT type, UINT format, HCONV conversation, HSZ a, HSZ b,
                                      HDDEDATA data, ULONG_PTR x, ULONG_PTR y) {
    (void)type; (void)format; (void)conversation; (void)a; (void)b; (void)data; (void)x; (void)y;
    return NULL;
}
static int dde_failed(DWORD instance) {
    UINT e = DdeGetLastError(instance);
    last = e == DMLERR_NO_CONV_ESTABLISHED ? ECONNREFUSED : e == DMLERR_BUSY ? EBUSY
         : e == DMLERR_EXECACKTIMEOUT ? ETIMEDOUT : e == DMLERR_NOTPROCESSED ? EIO : EIO;
    return -1;
}
int sys_win_dde_start(const char *service, const char *topic) {
    int i;
    for (i = 0; i < DDE_CONVERSATIONS; i++) if (!dde[i].used) break;
    if (i == DDE_CONVERSATIONS) { last = EMFILE; return -1; }
    DWORD instance = 0;
    if (DdeInitializeA(&instance, dde_callback, APPCMD_CLIENTONLY, 0) != DMLERR_NO_ERROR) { last = EIO; return -1; }
    HSZ s = DdeCreateStringHandleA(instance, service, CP_WINANSI);
    HSZ t = DdeCreateStringHandleA(instance, topic, CP_WINANSI);
    HCONV c = DdeConnect(instance, s, t, NULL);
    int r = c ? 0 : dde_failed(instance);
    DdeFreeStringHandle(instance, s);
    DdeFreeStringHandle(instance, t);
    if (!c) { DdeUninitialize(instance); return r; }
    dde[i].used = 1;
    dde[i].instance = instance;
    dde[i].conversation = c;
    return i;
}
int sys_win_dde_execute(int info, const char *command, int retries, int64_t delay_ms) {
    if (info < 0 || info >= DDE_CONVERSATIONS || !dde[info].used) { last = EBADF; return -1; }
    DWORD timeout = delay_ms <= 0 ? 1 : delay_ms > 0x7fffffff ? 0x7fffffff : (DWORD)delay_ms;
    for (int attempt = 0; ; attempt++) {
        DWORD result = 0;
        HDDEDATA r = DdeClientTransaction((LPBYTE)command, (DWORD)strlen(command) + 1, dde[info].conversation,
                                          NULL, 0, XTYP_EXECUTE, timeout, &result);
        if (r) return 0;
        UINT e = DdeGetLastError(dde[info].instance);
        if ((e == DMLERR_BUSY || (result & DDE_FBUSY)) && attempt < retries) { Sleep(timeout); continue; }
        return dde_failed(dde[info].instance);
    }
}
int sys_win_dde_stop(int info) {
    if (info < 0 || info >= DDE_CONVERSATIONS || !dde[info].used) { last = EBADF; return -1; }
    DdeDisconnect(dde[info].conversation);
    DdeUninitialize(dde[info].instance);
    dde[info].used = 0;
    return 0;
}

/* ---------------------------------------------------------- executable memory */
void *sys_code_alloc(size_t size) {
    void *p = VirtualAlloc(NULL, size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!p) last = errno_of_win(GetLastError());
    return p;
}
size_t sys_code_page(void) {
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    return si.dwPageSize ? si.dwPageSize : 4096;
}
int sys_code_protect(void *code, size_t size, int executable) {
    DWORD old;
    if (!VirtualProtect(code, size, executable ? PAGE_EXECUTE_READ : PAGE_READWRITE, &old)) { last = errno_of_win(GetLastError()); return 0; }
    return 1;
}
void sys_code_flush(void *code, size_t size) { FlushInstructionCache(GetCurrentProcess(), code, size); }
void sys_code_free(void *code, size_t size) { (void)size; VirtualFree(code, 0, MEM_RELEASE); }
