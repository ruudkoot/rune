#include "foreign.h"
#include "sys/sys.h"
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned checks;
#define CHECK(test) do { checks++; if (!(test)) { fprintf(stderr,"FAIL foreign runtime at %d: %s\n",__LINE__,foreign_error(f)->message); return 1; } } while (0)
/* Fail only the selected runtime operation, after fixture setup. */
static long remaining = -1;
void *__real_calloc(size_t count, size_t size);
void *__real_realloc(void *pointer, size_t size);
void *__wrap_calloc(size_t count, size_t size) {
    if (remaining == 0) { errno = ENOMEM; return NULL; }
    if (remaining > 0) remaining--;
    return __real_calloc(count, size);
}
void *__wrap_realloc(void *pointer, size_t size) {
    if (remaining == 0) { errno = ENOMEM; return NULL; }
    if (remaining > 0) remaining--;
    return __real_realloc(pointer, size);
}
static ForeignId prepare(Foreign *f,ForeignId lib,const char *name,ForeignType result,ForeignType argument){ForeignId s=foreign_symbol(f,lib,name,strlen(name));return s?foreign_prepare(f,s,0,result,&argument,1):0;}
int main(int argc,char **argv){
    if(argc!=2)return 2;
    ForeignSystem system={sys_library_open,sys_library_symbol,sys_library_close,sys_library_error,sys_foreign_capture};
    Foreign *f=foreign_create(&system);
    CHECK(f!=NULL);
    CHECK(foreign_live(f)==0);
    ForeignId lib=foreign_library(f,argv[1],strlen(argv[1]));
    CHECK(lib!=0);
    CHECK(foreign_library(f,"/nonexistent/runeffi",20)==0);
    CHECK(foreign_symbol(f,lib,"missing_symbol",14)==0);
    ForeignType kinds[]={FOREIGN_I8,FOREIGN_U8,FOREIGN_I16,FOREIGN_U16,FOREIGN_I32,FOREIGN_U32,FOREIGN_I64,FOREIGN_U64,FOREIGN_F32,FOREIGN_F64};
    const char *names[]={"rf_i8","rf_u8","rf_i16","rf_u16","rf_i32","rf_u32","rf_i64","rf_u64","rf_float","rf_double"};
    for(size_t i=0;i<sizeof kinds/sizeof kinds[0];i++){
        ForeignId call=prepare(f,lib,names[i],kinds[i],kinds[i]);
        CHECK(call!=0);
        ForeignValue argument={.type=kinds[i]},result={0};
        if(kinds[i]==FOREIGN_F32||kinds[i]==FOREIGN_F64)argument.value.real=0.25;
        else if(kinds[i]==FOREIGN_U64)argument.value.word=UINT64_MAX;
        else if(kinds[i]==FOREIGN_I64)argument.value.integer=INT64_MIN;
        else argument.value.integer=42;
        ForeignError captured;
        CHECK(foreign_call(f,call,&argument,1,&result,&captured)==0);
        if(kinds[i]==FOREIGN_F32||kinds[i]==FOREIGN_F64)CHECK(result.value.real==0.25);
        else if(kinds[i]==FOREIGN_U64)CHECK(result.value.word==UINT64_MAX);
        else if(kinds[i]==FOREIGN_I64)CHECK(result.value.integer==INT64_MIN);
        else CHECK(result.value.integer==42);
        if(kinds[i]==FOREIGN_I8){argument.value.integer=128;CHECK(foreign_call(f,call,&argument,1,&result,&captured)==-1);CHECK(foreign_error(f)->error_number==ERANGE);}
    }
    ForeignId memory=foreign_memory(f,6);
    CHECK(memory!=0);
    CHECK(foreign_write(f,memory,0,"owned",6)==0);
    ForeignId view=foreign_view(f,memory,1,3);
    CHECK(view!=0);
    CHECK(foreign_release(f,memory)==-1);
    char bytes[6]={0};
    CHECK(foreign_read(f,view,0,bytes,3)==0&&memcmp(bytes,"wne",3)==0);
    CHECK(foreign_read(f,view,2,bytes,2)==-1);
    ForeignId clone=prepare(f,lib,"rf_copy",FOREIGN_POINTER,FOREIGN_POINTER);
    CHECK(clone!=0);
    ForeignValue argument={.type=FOREIGN_POINTER,.value.pointer=memory},result;
    ForeignError captured;
    CHECK(foreign_call(f,clone,&argument,1,&result,&captured)==0&&result.value.pointer!=0);
    ForeignId owned=result.value.pointer;
    CHECK(foreign_read(f,owned,0,bytes,6)==0&&memcmp(bytes,"owned",6)==0);
    ForeignId release=prepare(f,lib,"rf_free",FOREIGN_VOID,FOREIGN_POINTER);
    CHECK(release!=0);
    argument.value.pointer=owned;
    CHECK(foreign_call(f,release,&argument,1,&result,&captured)==0);
    CHECK(foreign_release(f,owned)==0);
    CHECK(foreign_release(f,owned)==-1);
    CHECK(foreign_release(f,lib)==-1);
    CHECK(foreign_release(f,view)==0);
    CHECK(foreign_release(f,memory)==0);
    ForeignId fresh=foreign_memory(f,2);
    CHECK(fresh!=0&&fresh!=memory&&fresh!=owned);
    CHECK(foreign_read(f,memory,0,bytes,1)==-1);
    ForeignId error_call=prepare(f,lib,"rf_error",FOREIGN_I32,FOREIGN_I32);
    CHECK(error_call!=0);
    argument.type=FOREIGN_I32;argument.value.integer=ENOENT;
    CHECK(foreign_call(f,error_call,&argument,1,&result,&captured)==0&&result.value.integer==-1);
    CHECK(captured.error_number==ENOENT);
    Foreign *other=foreign_create(&system);
    CHECK(other!=NULL);
    CHECK(foreign_read(other,fresh,0,bytes,1)==-1);
    ForeignId other_memory=foreign_memory(other,2);
    CHECK(other_memory!=0&&other_memory!=fresh);
    foreign_destroy(other);
    size_t before=foreign_live(f);
    remaining=0;
    CHECK(foreign_memory(f,10)==0);
    remaining=-1;
    CHECK(foreign_live(f)==before);
    CHECK(foreign_error(f)->error_number==ENOMEM);
    /* Failure at each prepared-call allocation must leave no live entry. */
    ForeignId error_symbol=foreign_symbol(f,lib,"rf_error",8);
    CHECK(error_symbol!=0);
    ForeignId var_symbol=foreign_symbol(f,lib,"rf_variadic",11);
    CHECK(var_symbol!=0);
    ForeignType var_types[]={FOREIGN_U32,FOREIGN_I32,FOREIGN_I32,FOREIGN_I32};
    ForeignId var_call=foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,var_types,4,1);
    CHECK(var_call!=0);
    ForeignValue var_values[]={{.type=FOREIGN_U32,.value.word=3},
        {.type=FOREIGN_I32,.value.integer=3},{.type=FOREIGN_I32,.value.integer=14},
        {.type=FOREIGN_I32,.value.integer=25}};
    CHECK(foreign_call(f,var_call,var_values,4,&result,&captured)==0 && result.value.integer==42);
    CHECK(foreign_release(f,var_call)==0);
    CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,var_types,4,0)==0);
    CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,var_types,4,5)==0);
    CHECK(foreign_prepare_variadic(f,var_symbol,1,FOREIGN_I32,var_types,4,1)==0);
    CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,NULL,4,1)==0);
    ForeignType unpromoted[]={FOREIGN_U32,FOREIGN_F32};
    CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,unpromoted,2,1)==0);
    unpromoted[1]=FOREIGN_I8;
    CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,unpromoted,2,1)==0);
    before=foreign_live(f);
    ForeignType i32=FOREIGN_I32;
    for(long step=0;step<3;step++){
        remaining=step;
        CHECK(foreign_prepare(f,error_symbol,0,FOREIGN_I32,&i32,1)==0);
        remaining=-1;
        CHECK(foreign_live(f)==before);
        remaining=step;
        CHECK(foreign_prepare_variadic(f,var_symbol,0,FOREIGN_I32,var_types,4,1)==0);
        remaining=-1;
        CHECK(foreign_live(f)==before);
    }
    remaining=0;
    CHECK(foreign_call(f,error_call,&argument,1,&result,&captured)==-1);
    remaining=-1;
    CHECK(foreign_live(f)==before);
    foreign_destroy(f);
    printf("PASS generic foreign runtime: %u checks\n",checks);
    return 0;
}
