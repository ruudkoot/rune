/* A resize already delivered before a blocking terminal read must wake it.
   No timing race: raise returns only after the resize handler has run. */
#define _XOPEN_SOURCE 700
/* Only the system layer's poll is redirected by the compile command. */
#undef poll
#include "sys/sys.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t expired;
static int resize_at_poll;
int rune_test_poll(struct pollfd *fds, nfds_t n, int ms) {
    if (resize_at_poll) { resize_at_poll = 0; raise(SIGWINCH); }
    return poll(fds, n, ms);
}
static void timeout(int sig) { (void)sig; expired = 1; }
static void need(int ok, const char *why) {
    if (!ok) { fprintf(stderr, "FAIL resize read: %s\n", why); exit(1); }
}
static void wake(int fd) {
    char buf[16];
    expired = 0;
    alarm(2);
    int64_t got = sys_term_read(fd, buf, sizeof buf, -1);
    alarm(0);
    need(!expired && got == 0, "resize did not wake a read without keys");
}
int main(void) {
    int master = posix_openpt(O_RDWR | O_NOCTTY);
    need(master >= 0 && grantpt(master) == 0 && unlockpt(master) == 0, "open PTY");
    int fd = open(ptsname(master), O_RDWR | O_NOCTTY);
    need(fd >= 0 && sys_term_enter(fd, fd, "", 0, 0) == 0, "enter terminal");
    struct sigaction sa = {0};
    sa.sa_handler = timeout;
    sigemptyset(&sa.sa_mask);
    need(sigaction(SIGALRM, &sa, NULL) == 0, "catch timeout");
    int64_t before = sys_term_resizes();
    need(before >= 0, "start resize count");
    errno = EDOM;
    need(raise(SIGWINCH) == 0 && errno == EDOM, "resize handler changed errno");
    need(sys_term_resizes() != before, "resize was not counted before read");
    wake(fd);

    /* Inject at the actual wait boundary too: checking the counter just
       before poll would pass the first check but still lose this resize. */
    resize_at_poll = 1;
    wake(fd);
    need(!resize_at_poll, "wait boundary was not exercised");

    /* A burst must not block the handler even when its notification fills. */
    alarm(5);
    for (int i = 0; i < 100000; i++) raise(SIGWINCH);
    alarm(0);
    need(!expired, "resize burst blocked");
    wake(fd);

    /* A fork must not let its child consume the parent's notification. The
       child receives its own signal before its first terminal operation. */
    raise(SIGWINCH);
    pid_t child = fork();
    need(child >= 0, "fork");
    if (child == 0) { raise(SIGWINCH); wake(fd); _exit(0); }
    int status;
    need(waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0, "child wake");
    wake(fd);

    /* Notifications are drained; ordinary input remains readable. */
    need(write(master, "x", 1) == 1, "write key");
    raise(SIGWINCH);
    wake(fd);
    char buf[16];
    need(sys_term_read(fd, buf, sizeof buf, 2000) == 1 && buf[0] == 'x', "key after resize");
    need(sys_term_read(fd, buf, sizeof buf, 0) == 0, "empty nonblocking read");
    need(sys_term_leave() == 0, "leave terminal");
    close(fd); close(master);
    puts("PASS pending resize, burst, fork and input");
    return 0;
}
