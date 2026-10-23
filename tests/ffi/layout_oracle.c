#include <stddef.h>
#include <stdio.h>
#include "layout.h"
#define SCALAR(type) #type ":%zu:%zu\n", sizeof(type), _Alignof(type)
#define TYPE(value) _Generic((value), int:"int",unsigned int:"unsigned int",long:"long",unsigned long:"unsigned long",long long:"long long",unsigned long long:"unsigned long long",default:"unsupported")
#define EXPR(expression) printf("expression|%s|%lld|%s\n",#expression,(long long)(expression),TYPE(expression))
#define LAYOUT(type,member) printf("layout|" #type "|%zu|%zu|" #member "|%zu\n",sizeof(type),_Alignof(type),offsetof(type,member))
int main(void) {
 printf(SCALAR(char)); printf(SCALAR(short)); printf(SCALAR(int)); printf(SCALAR(long));
 printf(SCALAR(long long)); printf(SCALAR(void *)); printf(SCALAR(float)); printf(SCALAR(double));
 printf("charSigned:%d\n",(char)-1<0);
 printf("sizeType:%s\n",TYPE(sizeof(int)));
 EXPR((unsigned int)-1 + 1); EXPR((unsigned char)257 + 1); EXPR((signed char)255 + 1);
 EXPR((unsigned short)65535 + 1); EXPR(-7 / 3); EXPR(-7 % 3);
 EXPR(-1L < 1U); EXPR(0xffffffff + 1); EXPR((1 ? -1 : 1U) > 0);
 EXPR(sizeof(long)); EXPR(sizeof(int[3][2])); EXPR(sizeof(void *)); EXPR(sizeof(1 / 0));
 EXPR(sizeof(1 ? 1L : 1U)); EXPR(_Alignof(double)); EXPR(2147483648);
 LAYOUT(struct pair,fraction); LAYOUT(union variant,real); LAYOUT(struct anonymous,y);
 LAYOUT(struct anonymous,tail); LAYOUT(struct matrix,cells); LAYOUT(struct flexible,bytes);
 LAYOUT(struct packed,value);
 return 0;
}
