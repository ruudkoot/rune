/* A native oracle for the Windows text boundary. Direct W calls inspect what
   Rune wrote, and create fixtures Rune must read. Private codec/path probes
   pin canonical WTF-8 and UNC spelling without needing a network share. */
#include "../../runtime/sys/sys_win.c"

static int failures;
static void check(const char *label, int ok) {
    printf("%s windows.text/%s\n", ok ? "PASS" : "FAIL", label);
    if (!ok) { fprintf(stderr, "  errno=%d winerror=%lu\n", sys_errno(), (unsigned long)GetLastError()); failures++; }
}
/* The isolated surrogates have an intervening scalar: adjacent high+low
   code units would form another supplementary character. */
static const char isolated[] = "\xed\xa0\x80-x-\xed\xbf\xbf";
static const WCHAR isolated16[] = {0xd800, '-', 'x', '-', 0xdfff, 0};
static void codec(void) {
    const WCHAR good[] = {0x3bb, 0xe9, 0xd83d, 0xde80, 0};
    const char utf8[] = "\xce\xbb\xc3\xa9\xf0\x9f\x9a\x80";
    char *b = text8(good, 4, NULL);
    check("utf16-to-utf8", b && strcmp(b, utf8) == 0); free(b);
    WCHAR *w = text16(utf8, sizeof utf8 - 1, NULL);
    check("utf8-to-utf16", w && memcmp(w, good, sizeof good) == 0); free(w);
    b = text8(isolated16, 5, NULL);
    check("isolated-surrogates", b && strcmp(b, isolated) == 0); free(b);
    w = text16(isolated, sizeof isolated - 1, NULL);
    check("isolated-roundtrip", w && memcmp(w, isolated16, sizeof isolated16) == 0); free(w);
    const char *bad[] = {"\x80", "\xc0\x80", "\xe0\x80\x80", "\xe2\x82", "\xf0\x80\x80\x80", "\xf4\x90\x80\x80", "\xed\xa0\x80\xed\xb0\x80"};
    int ok = 1;
    for (size_t i = 0; i < sizeof bad / sizeof *bad; i++) {
        w = text16(bad[i], strlen(bad[i]), NULL); ok &= !w && last == EILSEQ; free(w);
    }
    check("reject-malformed-and-cesu8", ok);
    char embedded[] = {'a', 0, (char)0xce, (char)0xbb, 0, 0};
    size_t n;
    w = text16(embedded, sizeof embedded, &n); b = w ? text8(w, n, &n) : NULL;
    check("embedded-nuls", b && n == sizeof embedded && memcmp(b, embedded, n) == 0); free(w); free(b);
    const WCHAR drive[] = L"C:\\Users\\Name\\file.txt";
    char *stored = NULL;
    const char *native_path = store_path(&stored, drive, wcslen(drive));
    check("native-drive-output", native_path && !strcmp(native_path, "C:\\Users\\Name\\file.txt"));
    const WCHAR network[] = L"\\\\?\\UNC\\Server\\Share\\file.txt";
    native_path = store_path(&stored, network, wcslen(network));
    check("native-unc-output", native_path && !strcmp(native_path, "\\\\Server\\Share\\file.txt"));
    const WCHAR target[] = L"..\\folder\\file.txt";
    native_path = store_path(&stored, target, wcslen(target));
    check("native-relative-link-output", native_path && !strcmp(native_path, "..\\folder\\file.txt"));
    native_path = store_path(&stored, isolated16, 5);
    check("native-path-WTF8-output", native_path && !strcmp(native_path, isolated));
    free(stored);
    char unc[600] = "//server/share/";
    memset(unc + strlen(unc), 'a', 300); unc[315] = 0;
    w = path16(unc);
    check("extended-unc", w && wcsncmp(w, L"\\\\?\\UNC\\server\\share\\", 21) == 0); free(w);
}
static void environment(void) {
    SetEnvironmentVariableW(L"RuneText\x3bb", isolated16);
    const char *v = sys_getenv("RuneText\xce\xbb");
    check("wide-environment", v && strcmp(v, isolated) == 0);
    check("invalid-env-name", !sys_getenv("\xff") && last == EILSEQ);
    check("absent-clears-error", !sys_getenv("RuneTextNeverSet") && last == 0);
    SetEnvironmentVariableW(L"RuneTextEmpty", L"");
    v = sys_getenv("RuneTextEmpty"); check("empty-environment", v && !*v && last == 0);
    WCHAR *large = malloc(20001 * sizeof *large);
    for (int i = 0; i < 20000; i++) large[i] = 0x4e00;
    large[20000] = 0;
    check("set-large-environment", SetEnvironmentVariableW(L"RuneTextLarge1", large) && SetEnvironmentVariableW(L"RuneTextLarge2", large));
    v = sys_environ(); size_t size = 0;
    if (v) for (const char *p = v; *p; p += strlen(p) + 1) size += strlen(p) + 1;
    check("environment-over-64k", v && size > 120000);
    free(large);
    SetEnvironmentVariableW(L"RuneTextLarge1", NULL); SetEnvironmentVariableW(L"RuneTextLarge2", NULL);
    SetEnvironmentVariableW(L"RuneText\x3bb", NULL); SetEnvironmentVariableW(L"RuneTextEmpty", NULL);
}
static void files(void) {
    WCHAR name[] = {0x3bb, 0xe9, 0xd83d, 0xde80, 0xd800, '-', 0xdfff, '.', 't', 'x', 't', 0};
    const char *file = "\xce\xbb\xc3\xa9\xf0\x9f\x9a\x80\xed\xa0\x80-\xed\xbf\xbf.txt";
    HANDLE h = CreateFileW(name, GENERIC_WRITE, SHARE_ALL, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD written = 0;
    check("native-create", h != INVALID_HANDLE_VALUE && WriteFile(h, "hello", 5, &written, NULL) && written == 5);
    if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
    FILE *f = sys_fopen(file, "rb"); char got[6] = {0};
    check("read-native-file", f && fread(got, 1, 5, f) == 5 && strcmp(got, "hello") == 0); if (f) fclose(f);
    int d = sys_open_dir("."), seen = 0; const char *entry;
    if (d >= 0) { while ((entry = sys_read_dir(d))) if (!strcmp(entry, file)) seen++; sys_close_dir(d); }
    check("directory-surrogates", seen == 1);
    check("malformed-rename-source", sys_rename("bad\xff", file) < 0 && last == EILSEQ && sys_file_size(file) == 5);
    check("malformed-rename-destination", sys_rename(file, "bad\xff") < 0 && last == EILSEQ && sys_file_size(file) == 5);
    int64_t bad_limit;
    check("malformed-pathconf", sys_pathconf("bad\xff", -1, "PATH_MAX", &bad_limit) < 0 && last == EILSEQ);
    check("malformed-shell-file", sys_win_shell_execute("bad\xff.exe", "", 0) < 0 && last == EILSEQ);
    check("malformed-access", sys_access("bad\xff", 0, 0, 0) < 0 && last == EILSEQ);
    check("remove-native-file", sys_remove(file) == 0 && GetFileAttributesW(name) == INVALID_FILE_ATTRIBUTES);
    f = sys_fopen("bad\xff", "wb"); check("malformed-path-error", !f && errno == EILSEQ); if (f) fclose(f);
    char path[1800] = "long";
    check("long-root", sys_mkdir(path) == 0);
    int count = 0, ok = 1;
    while (strlen(path) < 1200) {
        strcat(path, "/abcdefghijabcdefghijabcdefghijabcdefghij\xce\xbb");
        if (sys_mkdir(path) != 0) { ok = 0; break; }
        count++;
    }
    check("directories-over-1040", ok && strlen(path) > 1040);
    size_t base = strlen(path); strcat(path, "/file.txt");
    f = sys_fopen(path, "wb"); check("long-write", f && fwrite("wide", 1, 4, f) == 4); if (f) fclose(f);
    WCHAR cwd[32768], absolute[32768];
    GetCurrentDirectoryW(32768, cwd);
    wcscpy(absolute, L"\\\\?\\"); wcscat(absolute, cwd); wcscat(absolute, L"\\");
    /* This independent conversion handles scalar-only fixtures. */
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, absolute + wcslen(absolute), 32768 - (int)wcslen(absolute));
    for (WCHAR *p = absolute; *p; p++) if (*p == L'/') *p = L'\\';
    h = CreateFileW(absolute, GENERIC_READ, SHARE_ALL, NULL, OPEN_EXISTING, 0, NULL);
    check("native-inspects-long-file", h != INVALID_HANDLE_VALUE); if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
    char dotted[1900]; snprintf(dotted, sizeof dotted, "%.*s/./file.txt", (int)base, path);
    check("long-relative-dot-components", sys_file_size(dotted) == 4);
    char hard[1900], soft[1900];
    snprintf(hard, sizeof hard, "%s.hard", path); snprintf(soft, sizeof soft, "%s.link", path);
    int64_t dev1, ino1, dev2, ino2;
    check("long-hard-link", sys_link(path, hard) == 0 && sys_file_id(path, &dev1, &ino1) == 0 &&
          sys_file_id(hard, &dev2, &ino2) == 0 && dev1 == dev2 && ino1 == ino2);
    check("long-hard-link-remove", sys_remove(hard) == 0);
    int symlink = sys_symlink("file.txt", soft);
    if (symlink == 0) {
        const char *target = sys_read_link(soft);
        check("long-relative-symbolic-link", target && !strcmp(target, "file.txt") && sys_file_size(soft) == 4);
        check("long-symbolic-link-remove", sys_remove(soft) == 0);
        check("relative-link-components-create", sys_symlink("./file.txt", soft) == 0);
        target = sys_read_link(soft);
        check("relative-link-native-separators", target && !strcmp(target, ".\\file.txt"));
        check("relative-link-components-remove", sys_remove(soft) == 0);
        const char *resolved = sys_real_path(path);
        char *expected = resolved ? _strdup(resolved) : NULL;
        check("absolute-link-create", expected && sys_symlink(expected, soft) == 0);
        target = sys_read_link(soft);
        check("absolute-link-native-path", expected && target && !strcmp(target, expected) && sys_file_size(target) == 4);
        check("absolute-link-remove", sys_remove(soft) == 0);
        free(expected);
    } else if (last == EPERM) puts("SKIP windows.text/symbolic-link-privilege");
    else check("long-symbolic-link-create", 0);
    WCHAR *slash = wcsrchr(absolute, L'\\');
    *slash = 0;
    if (SetCurrentDirectoryW(absolute)) {
        const char *deep_cwd = sys_getcwd();
        check("native-deep-current-directory", deep_cwd && strlen(deep_cwd) > 1040 && sys_file_size("file.txt") == 4);
        FILE *null = sys_fopen("/dev/null", "wb");
        check("deep-cwd-null-device", null && sys_desc_kind(sys_fileno(null)) == 6); if (null) fclose(null);
        check("restore-current-directory", SetCurrentDirectoryW(cwd));
    } else puts("SKIP windows.text/native-deep-current-directory-limit");
    *slash = L'\\';
    const char *real = sys_real_path(path); char *saved = real ? _strdup(real) : NULL;
    check("long-full-path", saved && strlen(saved) > 1040 && sys_file_size(saved) == 4); free(saved);
    char renamed[1900]; snprintf(renamed, sizeof renamed, "%s.new", path);
    check("long-rename", sys_rename(path, renamed) == 0 && sys_file_size(renamed) == 4);
    check("long-remove", sys_remove(renamed) == 0);
    path[base] = 0;
    d = sys_open_dir(path); check("long-directory", d >= 0 && !sys_read_dir(d) && last == 0); if (d >= 0) sys_close_dir(d);
    int64_t limit = 0; check("path-max-indeterminate", sys_pathconf(path, -1, "PATH_MAX", &limit) == 0 && limit == -1);
    while (count-- > 0) { check("long-rmdir", sys_rmdir(path) == 0); *strrchr(path, '/') = 0; }
    check("root-rmdir", sys_rmdir(path) == 0);
}
static void registry(void) {
    char key[128]; WCHAR native_key[128];
    snprintf(key, sizeof key, "Software\\RuneText-%lu-\xce\xbb", (unsigned long)GetCurrentProcessId());
    swprintf(native_key, 128, L"Software\\RuneText-%lu-\x3bb", (unsigned long)GetCurrentProcessId());
    int64_t result[2];
    int ok = sys_win_reg_open(1, key, KEY_ALL_ACCESS, 1, result) == 0;
    check("registry-create", ok); if (!ok) return;
    int handle = (int)result[1]; HKEY h;
    check("native-opens-registry", RegOpenKeyExW(HKEY_CURRENT_USER, native_key, 0, KEY_ALL_ACCESS, &h) == ERROR_SUCCESS);
    const char *value = "\xce\xbb\0\xed\xa0\x80-x-\xed\xbf\xbf\0\0";
    size_t len = 2 + 1 + sizeof isolated - 1 + 2;
    check("registry-write-multi", sys_win_reg_set(handle, "\xce\xbb", REG_MULTI_SZ, value, (int64_t)len) == 0);
    WCHAR data[64]; DWORD n = sizeof data, type;
    LONG r = RegQueryValueExW(h, L"\x3bb", NULL, &type, (BYTE *)data, &n);
    WCHAR expected[] = {0x3bb, 0, 0xd800, '-', 'x', '-', 0xdfff, 0, 0};
    check("native-inspects-registry", r == ERROR_SUCCESS && type == REG_MULTI_SZ && n == sizeof expected && !memcmp(data, expected, n));
    int t; int64_t length; const char *back = sys_win_reg_query(handle, "\xce\xbb", &t, &length);
    check("registry-read-multi", back && t == REG_MULTI_SZ && length == (int64_t)len && !memcmp(back, value, len));
    const char raw[] = {0, (char)0xff, (char)0xd8, 0};
    check("registry-binary", sys_win_reg_set(handle, "binary", REG_BINARY, raw, sizeof raw) == 0);
    back = sys_win_reg_query(handle, "binary", &t, &length);
    check("registry-binary-exact", back && length == sizeof raw && !memcmp(back, raw, sizeof raw));
    /* RegSetValueExW requires REG_SZ's terminator in cbData. */
    check("native-registry-write", RegSetValueExW(h, L"native", 0, REG_SZ, (const BYTE *)isolated16, sizeof isolated16) == ERROR_SUCCESS);
    back = sys_win_reg_query(handle, "native", &t, &length);
    check("registry-native-text", back && t == REG_SZ && length == sizeof isolated && !memcmp(back, isolated, sizeof isolated));
    sys_win_reg_delete(handle, "native", 1);
    const char *entry = sys_win_reg_enum(handle, 0, 1);
    check("registry-wide-enumeration", entry && (!strcmp(entry, "binary") || !strcmp(entry, "\xce\xbb")));
    RegCloseKey(h); sys_win_reg_delete(handle, "\xce\xbb", 1); sys_win_reg_delete(handle, "binary", 1);
    sys_win_reg_close(handle); check("registry-cleanup", sys_win_reg_delete(1, key, 0) == 0);
}
static int native_run(const WCHAR *app, const WCHAR *tail) {
    size_t size = wcslen(app) + wcslen(tail) + 5;
    WCHAR *line = malloc(size * sizeof *line);
    if (!line) return 1;
    swprintf(line, size, L"\"%ls\" %ls", app, tail);
    STARTUPINFOW si = {0}; si.cb = sizeof si;
    PROCESS_INFORMATION pi;
    BOOL ok = CreateProcessW(app, line, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi);
    free(line);
    if (!ok) return 1;
    CloseHandle(pi.hThread);
    DWORD status;
    DWORD wait = WaitForSingleObject(pi.hProcess, 120000);
    if (wait != WAIT_OBJECT_0) TerminateProcess(pi.hProcess, 99);
    GetExitCodeProcess(pi.hProcess, &status); CloseHandle(pi.hProcess);
    return wait == WAIT_OBJECT_0 ? (int)status : 99;
}
static int child(int argc, WCHAR **argv) {
    WCHAR env[64];
    int ok = argc == 8 && !wcscmp(argv[2], isolated16) && !*argv[3] &&
             !wcscmp(argv[4], L"a b") && !wcscmp(argv[5], L"quote\"x") && !wcscmp(argv[6], L"tail\\") &&
             wcslen(argv[7]) == 11000;
    if (argc == 8) for (int i = 0; i < 11000; i++) if (argv[7][i] != 0x4e00) ok = 0;
    ok &= GetEnvironmentVariableW(L"RuneChild\x3bb", env, 64) > 0 && !wcscmp(env, isolated16);
    WCHAR marker[16];
    if (GetEnvironmentVariableW(L"RuneTextOrderFixture", marker, 16)) {
        const WCHAR *names[] = {L"alpha=", L"RuneChild\x3bb=", L"zebra=", L"\xd83d\xde80=", L"\xe000="};
        WCHAR *block = GetEnvironmentStringsW();
        size_t seen = 0;
        for (WCHAR *p = block; *p; p += wcslen(p) + 1)
            for (size_t i = 0; i < 5; i++)
                if (!wcsncmp(p, names[i], wcslen(names[i]))) { if (seen != i) ok = 0; seen++; }
        FreeEnvironmentStringsW(block);
        ok &= seen == 5;
    }
    return ok ? 0 : 17;
}
static void processes(void) {
    WCHAR module[32768]; GetModuleFileNameW(NULL, module, 32768);
    check("unicode-program-dir", CreateDirectoryW(L"program-\x3bb", NULL));
    check("unicode-program-copy", CopyFileW(module, L"program-\x3bb\\child-\x3bb.exe", TRUE));
    const char *program = "program-\xce\xbb/child-\xce\xbb.exe";
    char *large = malloc(33001);
    for (int i = 0; i < 11000; i++) memcpy(large + 3 * i, "\xe4\xb8\x80", 3);
    large[33000] = 0;
    char *args[] = {(char *)program, "--child", (char *)isolated, "", "a b", "quote\"x", "tail\\", large, NULL};
    int fds[3] = {-1, -1, -1}; int64_t status[3];
    SetEnvironmentVariableW(L"RuneTextOrderFixture", NULL);
    SetEnvironmentVariableW(L"RuneChild\x3bb", isolated16);
    int64_t pid = sys_spawn(program, args, NULL, 0, fds);
    check("spawn-inherited-wide-env-and-arguments", pid >= 0 && sys_waitpid(pid, 0, status) == 0 && status[1] == 0 && status[2] == 0);
    char *env[] = {"\xee\x80\x80=private", "zebra=z", "\xf0\x9f\x9a\x80=rocket",
                   "RuneChild\xce\xbb=\xed\xa0\x80-x-\xed\xbf\xbf", "alpha=first", "RuneTextOrderFixture=1", NULL};
    pid = sys_spawn(program, args, env, 0, fds);
    check("spawn-explicit-wide-env", pid >= 0 && sys_waitpid(pid, 0, status) == 0 && status[1] == 0 && status[2] == 0);
    WCHAR cwd[32768], path[32768]; GetCurrentDirectoryW(32768, cwd);
    swprintf(path, 32768, L"%ls\\program-\x3bb", cwd);
    SetEnvironmentVariableW(L"PATH", path); SetEnvironmentVariableW(L"PATHEXT", L".EXE");
    pid = sys_spawn("child-\xce\xbb", args, env, 1, fds);
    check("unicode-path-search", pid >= 0 && sys_waitpid(pid, 0, status) == 0 && status[1] == 0 && status[2] == 0);
    free(large);
    large = malloc(100000); memset(large, 'x', 99999); large[99999] = 0;
    args[7] = large;
    check("command-line-limit", sys_spawn("missing.exe", args, env, 0, fds) < 0 && last == E2BIG);
    free(large);
    check("unicode-program-remove", DeleteFileW(L"program-\x3bb\\child-\x3bb.exe") && RemoveDirectoryW(L"program-\x3bb"));
}
int wmain(int argc, WCHAR **argv) {
    if (argc > 1 && !wcscmp(argv[1], L"--child")) return child(argc, argv);
    if (argc == 4 && !wcscmp(argv[1], L"--vm")) {
        SetEnvironmentVariableW(L"RuneTextInherited", isolated16);
        size_t cap = wcslen(argv[3]) + 128;
        WCHAR *tail = malloc(cap * sizeof *tail);
        swprintf(tail, cap, L"\"%ls\" \"%ls\" \"\" \"a b\" \"quote\\\"x\" tail\\", argv[3], isolated16);
        int status = native_run(argv[2], tail); free(tail); return status;
    }
    if (argc == 6 && !wcscmp(argv[1], L"--compile")) {
        const char source[] = "val () = print \"PASS windows.text/native-compile\\n\"\n";
        HANDLE f = CreateFileW(L"\x3bb.sml", GENERIC_WRITE, SHARE_ALL, NULL, CREATE_ALWAYS, 0, NULL);
        DWORD n;
        check("native-source", f != INVALID_HANDLE_VALUE && WriteFile(f, source, sizeof source - 1, &n, NULL));
        if (f != INVALID_HANDLE_VALUE) CloseHandle(f);
        size_t cap = wcslen(argv[3]) + wcslen(argv[4]) + 160;
        WCHAR *tail = malloc(cap * sizeof *tail);
        swprintf(tail, cap, L"\"%ls\" --lib \"%ls\" --target=%ls \"\x3bb.sml\" -o \"\x3bb.rbc\"", argv[3], argv[4], argv[5]);
        check("windows-compiler-unicode-source", native_run(argv[2], tail) == 0 && GetFileAttributesW(L"\x3bb.rbc") != INVALID_FILE_ATTRIBUTES);
        check("windows-compiler-result", native_run(argv[2], L"\"\x3bb.rbc\"") == 0);
        free(tail); DeleteFileW(L"\x3bb.sml"); DeleteFileW(L"\x3bb.rbc");
        return failures ? 1 : 0;
    }
    codec(); environment(); files(); registry(); processes();
    return failures ? 1 : 0;
}
