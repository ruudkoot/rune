/* Independent C facts for checked cross-generator profiles. */
#include <stdio.h>
#include <stddef.h>
#include <limits.h>
#include <wchar.h>
#define FACT(label,type) printf("\"%s\":{\"size\":%u,\"alignment\":%u}",label,(unsigned)sizeof(type),(unsigned)_Alignof(type))
int main(void) {
    const unsigned endian=1;
    printf("{\"charSigned\":%s,\"byteOrder\":\"%s\",\"scalars\":{",CHAR_MIN<0?"true":"false",*(const unsigned char *)&endian?"little":"big");
    FACT("char",char); putchar(','); FACT("short",short); putchar(','); FACT("int",int); putchar(',');
    FACT("long",long); putchar(','); FACT("longLong",long long); putchar(','); FACT("pointer",void *); putchar(',');
    FACT("wchar",wchar_t); putchar(','); FACT("float",float); putchar(','); FACT("double",double); putchar(','); FACT("bool",_Bool);
    puts("}}"); return 0;
}
