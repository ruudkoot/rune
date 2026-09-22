/* The system layer for Windows (`make windows`, built with mingw-w64). It is
   not part of any other build: `make check` never compiles this file, and
   nothing else in the tree depends on it.

   What Windows has, this gives: the clock, the calendar, files and
   directories, descriptors, the environment, running a command, the named
   constants and errors of POSIX (numbered as Linux numbers them where this
   layer decodes them itself, as Winsock does where they go to Winsock), and
   the sockets, which are Winsock's. What it does not do yet fails with
   ENOSYS, as in `make vm SYS=none`, and the library turns that into
   OS.SysErr; docs/plans/windows.md says which milestone takes what, and
   tests/basis/deviations.txt which checks of the suite fail meanwhile.

   Paths come to and from the library as the library writes them; the CRT of
   mingw takes both separators. */
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
#ifndef SIO_UDP_CONNRESET
#define SIO_UDP_CONNRESET _WSAIOW(IOC_VENDOR, 12)
#endif
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
    if (sock_of(fd)) return 5;
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
   poll says of a regular file, and sockets are asked with WSAPoll, which
   waits when nothing else is ready. Nothing else can be waited for yet. No
   descriptors at all is a wait for the time given. */
int sys_poll(const int *fds, int *events, int n, int64_t microseconds) {
    int ready = 0, nsock = 0;
    WSAPOLLFD *items = calloc((size_t)(n > 0 ? n : 1), sizeof *items);
    int *which = calloc((size_t)(n > 0 ? n : 1), sizeof *which);
    if (!items || !which) { free(items); free(which); last = ENOMEM; return -1; }
    for (int i = 0; i < n; i++) {
        Sock *s = sock_of(fds[i]);
        if (s) {
            items[nsock].fd = s->s;
            items[nsock].events = (short)(((events[i] & 1) ? POLLRDNORM : 0) | ((events[i] & 2) ? POLLWRNORM : 0) |
                                          ((events[i] & 4) ? POLLRDBAND : 0));
            which[nsock++] = i;
            continue;
        }
        HANDLE h = (HANDLE)_get_osfhandle(fds[i]);
        if (h == INVALID_HANDLE_VALUE) { free(items); free(which); errno = EBADF; return failed(); }
        if (GetFileType(h) != FILE_TYPE_DISK) { free(items); free(which); return fail(); }
        events[i] &= 1 | 2;
        if (events[i]) ready++;
    }
    if (nsock > 0) {
        int timeout = ready > 0 ? 0 : microseconds < 0 ? -1
                    : microseconds / 1000 >= INT_MAX ? INT_MAX : (int)((microseconds + 999) / 1000);
        if (WSAPoll(items, (ULONG)nsock, timeout) == SOCKET_ERROR) {
            free(items); free(which); return wsa_failed();
        }
        for (int k = 0; k < nsock; k++) {
            short r = items[k].revents;
            int i = which[k];
            /* the end of the stream is ready to be read, as POLLHUP is on POSIX */
            events[i] = ((r & (POLLRDNORM | POLLHUP)) ? 1 : 0) | ((r & POLLWRNORM) ? 2 : 0) | ((r & POLLRDBAND) ? 4 : 0);
            if (events[i]) ready++;
        }
    } else if (ready == 0) {
        if (microseconds < 0) Sleep(INFINITE);
        else sys_time_sleep(microseconds);
    }
    free(items);
    free(which);
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
int sys_isatty(int fd) { return !sock_of(fd) && _isatty(fd) ? 1 : 0; }
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
int sys_close_fd(int fd) {
    Sock *s = sock_of(fd);
    if (s) {
        s->used = 0;
        return closesocket(s->s) == 0 ? 0 : wsa_failed();
    }
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
    return r < 0 ? failed() : r;
}
/* A socket cannot take the number of a descriptor of the C runtime, nor
   the other way round. */
int sys_dup2(int fd, int to) {
    if (sock_of(fd) || sock_of(to)) { last = EBADF; return -1; }
    return _dup2(fd, to) == 0 ? to : failed();
}
int sys_pipe(int out[2]) { return _pipe(out, 65536, _O_BINARY) == 0 ? 0 : failed(); }
/* the end of a file is 0 bytes with the error cleared, as on POSIX */
int64_t sys_read_fd(int fd, char *buf, int64_t n) {
    last = 0;
    if (sock_of(fd)) return sys_recv(fd, buf, n, 0);
    int r = _read(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    return r < 0 ? failed() : r;
}
int64_t sys_write_fd(int fd, const char *buf, int64_t n) {
    if (sock_of(fd)) return sys_send(fd, buf, n, 0);
    int r = _write(fd, buf, (unsigned)(n > 0x7fffffff ? 0x7fffffff : n));
    return r < 0 ? failed() : r;
}
int64_t sys_lseek_fd(int fd, int64_t offset, int whence) {
    if (sock_of(fd)) { last = ESPIPE; return -1; }
    __int64 r = _lseeki64(fd, offset, whence);
    return r < 0 ? failed() : (int64_t)r;
}
int sys_fsync(int fd) {
    if (sock_of(fd)) { last = EINVAL; return -1; }
    return _commit(fd) == 0 ? 0 : failed();
}
/* The commands of fcntl, as Linux numbers them (sys_const). A socket is
   read and written (O_RDWR), and blocks or not as FIONBIO last said. */
int sys_fcntl(int fd, int command, int argument) {
    Sock *s = sock_of(fd);
    if (!s) return fail();
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
int sys_lock(int fd, int command, int type, int whence, int64_t start, int64_t length, int64_t out[5]) {
    (void)command; (void)type; (void)whence; (void)start; (void)length; (void)out;
    if (sock_of(fd)) { last = EINVAL; return -1; }
    return fail();
}
int sys_pathconf(const char *path, int fd, const char *name, int64_t *out) {
    (void)path; (void)fd; (void)name; (void)out; last = 0; return fail();
}
int sys_tcgetattr(int fd, int64_t *out) { (void)fd; (void)out; return fail(); }
int sys_tcsetattr(int fd, int action, const int64_t *in) { (void)fd; (void)action; (void)in; return fail(); }
int64_t sys_tcop(int op, int fd, int64_t argument) { (void)op; (void)fd; (void)argument; return fail(); }
int sys_nccs(void) { return 0; }
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
int sys_utime(const char *path, int64_t access, int64_t modification) {
    return set_file_times(path, access, modification);
}
int sys_ftruncate(int fd, int64_t length) {
    if (sock_of(fd)) { last = EINVAL; return -1; }
    return _chsize_s(fd, length) == 0 ? 0 : failed();
}
/* kind, mode, inode, device, links, user, group, size, access, modification,
   change. Windows has no inode, user or group: they are 0. */
int sys_stat_of(const char *path, int follow, int fd, int64_t out[11]) {
    (void)follow;
    if (!path && sock_of(fd)) {
        /* a socket, readable and writable by all, as Linux has it */
        for (int i = 0; i < 11; i++) out[i] = 0;
        out[0] = 5;
        out[1] = 0777;
        out[2] = (int64_t)sock_of(fd)->s;
        return 0;
    }
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
