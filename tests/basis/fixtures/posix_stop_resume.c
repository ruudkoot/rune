#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
static void one(int persistent) {
  pid_t child=fork(); assert(child>=0);
  if(child==0) { raise(SIGSTOP); if(!persistent)_exit(7); for(;;)pause(); }
  int status=0; assert(waitpid(child,&status,WUNTRACED)==child && WIFSTOPPED(status));
  assert(kill(child,SIGCONT)==0);
  pid_t result=0;
  if(!persistent) {
    for(int i=0;i<1000 && !result;i++) { result=waitpid(child,&status,WNOHANG); if(!result){struct timespec t={0,1000000};nanosleep(&t,NULL);} }
    assert(result==child && WIFEXITED(status) && WEXITSTATUS(status)==7);
  } else {
    struct timespec t={0,10000000};nanosleep(&t,NULL);
    result=waitpid(child,&status,WNOHANG); assert(result==0);
  }
  errno=0; int killed=kill(child,SIGKILL); int error=errno;
  if(!persistent)assert(killed==-1 && error==ESRCH);
  else assert(killed==0 && waitpid(child,&status,0)==child && WIFSIGNALED(status) && WTERMSIG(status)==SIGKILL);
  printf("%s after planted SIGCONT: wait=%s kill=%d errno=%d\n",persistent?"persistent":"old-exit7",result==0?"none":"reaped",killed,error);
}
int main(void){one(0);one(1);return 0;}
