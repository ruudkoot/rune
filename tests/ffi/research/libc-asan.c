#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
 void *lib=dlopen("libc.so.6",RTLD_NOW|RTLD_LOCAL);
 void *address=dlsym(lib,"strdup"); char *(*copy)(const char *)=NULL;
 memcpy(&copy,&address,sizeof copy);
 address=dlsym(lib,"free"); void (*destroy)(void *)=NULL;
 memcpy(&destroy,&address,sizeof destroy);
 char *text=copy("hello"); destroy(text);
 dlclose(lib); return 0;
}
