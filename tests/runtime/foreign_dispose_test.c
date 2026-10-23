#include "foreign.h"
#include "sys/sys.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned checks, frees, entries;
static Foreign *context;
static ForeignId active, destructor;
static int guarded, native_failure, return_value;
static long remaining = -1;
void *__real_calloc(size_t, size_t);
void *__real_realloc(void *, size_t);
void *__wrap_calloc(size_t n, size_t size) {
 if (remaining==0) { errno=ENOMEM; return NULL; }
 if (remaining>0) remaining--;
 return __real_calloc(n,size);
}
void *__wrap_realloc(void *p, size_t size) {
 if (remaining==0) { errno=ENOMEM; return NULL; }
 if (remaining>0) remaining--;
 return __real_realloc(p,size);
}
#define CHECK(condition) do { checks++; if (!(condition)) { fprintf(stderr,"FAIL disposal at %d: %s\n",__LINE__,foreign_error(context)->message); return 1; } } while (0)
static void grow(unsigned count) {
 ForeignId ids[512];
 for (unsigned i=0;i<count;i++) { ids[i]=foreign_memory(context,1); if (!ids[i]) guarded=0; }
 for (unsigned i=0;i<count;i++) if (ids[i] && foreign_release(context,ids[i])!=0) guarded=0;
}
static void *identity_probe(void *pointer) {
 guarded=foreign_release(context,active)==-1 && foreign_error(context)->error_number==EBUSY;
 grow(64);
 return pointer;
}
static void *make_probe(void) {
 void *pointer=malloc(6);
 if (pointer) memcpy(pointer,"owned",6);
 return pointer;
}
static int destroy_probe(void *pointer) {
 entries++;
 char byte;
 guarded=foreign_release(context,active)==-1 && foreign_error(context)->error_number==EBUSY;
 guarded=guarded && foreign_read(context,active,0,&byte,1)==-1 && foreign_error(context)->error_number==EBUSY;
 guarded=guarded && foreign_view(context,active,0,1)==0 && foreign_error(context)->error_number==EBUSY;
 guarded=guarded && foreign_same(context,active,active)==1 && foreign_alive(context,active);
 ForeignValue arg={.type=FOREIGN_POINTER,.value.pointer=active}, result;
 ForeignError captured;
 int disposed;
 guarded=guarded && foreign_dispose(context,active,destructor,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1;
 guarded=guarded && foreign_call(context,destructor,&arg,1,&result,&captured)==-1;
 grow(512);
 if (!native_failure) { free(pointer); frees++; }
 errno=native_failure ? EACCES : ERANGE;
 return return_value;
}
static void destroy_void(void *pointer) { (void)destroy_probe(pointer); }
static int matches(const char *s,size_t n,const char *expected) { return strlen(expected)==n && memcmp(s,expected,n)==0; }
static void *symbol(void *library,const char *name,size_t n) {
 void (*entry)(void)=NULL;
 if (matches(name,n,"make_probe")) entry=(void (*)(void))make_probe;
 else if (matches(name,n,"identity_probe")) entry=(void (*)(void))identity_probe;
 else if (matches(name,n,"destroy_probe")) entry=(void (*)(void))destroy_probe;
 else if (matches(name,n,"destroy_void")) entry=(void (*)(void))destroy_void;
 else return sys_library_symbol(library,name,n);
 void *address=NULL;
 if (sizeof address!=sizeof entry) return NULL;
 memcpy(&address,&entry,sizeof address);
 return address;
}
static ForeignId prepare(ForeignId library,const char *name,ForeignType result,const ForeignType *arguments,size_t count) {
 ForeignId function=foreign_symbol(context,library,name,strlen(name));
 return function ? foreign_prepare(context,function,0,result,arguments,count) : 0;
}
int main(int argc,char **argv) {
 if (argc!=2) return 2;
 ForeignSystem system={sys_library_open,symbol,sys_library_close,sys_library_error,sys_foreign_capture};
 context=foreign_create(&system);
 CHECK(context!=NULL);
 ForeignId library=foreign_library(context,argv[1],strlen(argv[1]));
 CHECK(library!=0);
 ForeignType pointer_type=FOREIGN_POINTER;
 ForeignId make=prepare(library,"make_probe",FOREIGN_POINTER,NULL,0);
 ForeignId identity=prepare(library,"identity_probe",FOREIGN_POINTER,&pointer_type,1);
 destructor=prepare(library,"destroy_probe",FOREIGN_I32,&pointer_type,1);
 ForeignId void_call=prepare(library,"destroy_void",FOREIGN_VOID,&pointer_type,1);
 CHECK(make && identity && destructor && void_call);
 ForeignId memory=foreign_memory(context,6);
 CHECK(memory && foreign_write(context,memory,0,"owned",6)==0);
 ForeignId view=foreign_view(context,memory,0,6), different=foreign_view(context,memory,1,5);
 CHECK(view && different && foreign_same(context,memory,view)==1 && foreign_same(context,memory,different)==0);
 CHECK(foreign_same(context,library,memory)==-1);
 active=memory;
 ForeignValue arg={.type=FOREIGN_POINTER,.value.pointer=memory},result;
 ForeignError captured;
 size_t live=foreign_live(context);
 CHECK(foreign_call(context,identity,&arg,1,&result,&captured)==0 && guarded);
 ForeignId alias=result.value.pointer;
 CHECK(alias && foreign_alive(context,alias) && foreign_live(context)==live+1);
 char bytes[6];
 CHECK(foreign_read(context,alias,0,bytes,6)==0 && memcmp(bytes,"owned",6)==0);
 int disposed;
 CHECK(foreign_dispose(context,alias,destructor,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1);
 CHECK(foreign_release(context,alias)==0 && !foreign_alive(context,alias));
 CHECK(foreign_release(context,different)==0 && foreign_release(context,view)==0 && foreign_release(context,memory)==0);
 for (unsigned predicate=FOREIGN_FAIL_NEVER;predicate<=FOREIGN_FAIL_NEGATIVE;predicate++) {
  CHECK(foreign_call(context,make,NULL,0,&result,&captured)==0 && result.value.pointer);
  active=result.value.pointer;
  arg.value.pointer=active;
  view=foreign_view(context,active,0,6);
  unsigned before=entries;
  CHECK(foreign_dispose(context,active,destructor,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1 && !disposed && entries==before);
  CHECK(foreign_release(context,view)==0);
  CHECK(foreign_dispose(context,active,void_call,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1 && entries==before);
  remaining=0;
  CHECK(foreign_dispose(context,active,destructor,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1 && entries==before);
  remaining=-1;
  CHECK(foreign_read(context,active,0,bytes,6)==0 && memcmp(bytes,"owned",6)==0);
  if (predicate!=FOREIGN_FAIL_NEVER) {
   native_failure=1;
   return_value=predicate==FOREIGN_FAIL_ZERO ? 0 : predicate==FOREIGN_FAIL_NONZERO ? 1 : -1;
   CHECK(foreign_dispose(context,active,destructor,&arg,1,(ForeignFailure)predicate,&result,&captured,&disposed)==0 && !disposed && guarded);
   CHECK(captured.error_number==EACCES && result.value.integer==return_value && foreign_alive(context,active));
  }
  native_failure=0;return_value=predicate==FOREIGN_FAIL_ZERO ? 1 : 0;
  CHECK(foreign_dispose(context,active,predicate==FOREIGN_FAIL_NEVER ? void_call : destructor,&arg,1,(ForeignFailure)predicate,&result,&captured,&disposed)==0 && disposed && guarded);
  CHECK(captured.error_number==ERANGE && !foreign_alive(context,active));
  before=entries;
  CHECK(foreign_dispose(context,active,destructor,&arg,1,FOREIGN_FAIL_ZERO,&result,&captured,&disposed)==-1 && entries==before);
 }
 CHECK(frees==4);
 foreign_destroy(context);
 printf("PASS guarded native disposal/reentry: %u checks\n",checks);
 return 0;
}
