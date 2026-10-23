/* Independent direct-C baseline. Keep the subject in a separate shared
   object so the compiler cannot inline calls across the measured boundary. */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#if defined(_WIN32)
#define RFP_EXPORT __declspec(dllexport)
#else
#define RFP_EXPORT
#endif
typedef uint64_t (*rfp_function)(uint64_t);
#ifndef RFP_MAIN
RFP_EXPORT uint64_t rfp_scalar(uint64_t value) { return value + 1; }
RFP_EXPORT uint64_t rfp_buffer(unsigned char *bytes, size_t length) {
    for (size_t i=0; i<length; i++) bytes[i]++;
    return length ? bytes[0] : 0;
}
RFP_EXPORT uint64_t rfp_callback(rfp_function function, uint64_t value) { return function(value); }
#else
extern uint64_t rfp_scalar(uint64_t);
extern uint64_t rfp_buffer(unsigned char *,size_t);
extern uint64_t rfp_callback(rfp_function,uint64_t);
static uint64_t direct_callback(uint64_t value) { return value+1; }
static void report(const char *phase, size_t iterations, clock_t start, uint64_t checksum) {
    printf("{\"implementation\":\"direct-c\",\"phase\":\"%s\",\"iterations\":%zu,\"cpuSeconds\":%.9f,\"checksum\":\"%llu\"}\n",
        phase,iterations,(double)(clock()-start)/CLOCKS_PER_SEC,(unsigned long long)checksum);
}
int main(int argc,char **argv) {
    if (argc!=2) return 2;
    size_t iterations=(size_t)strtoull(argv[1],NULL,10);
    if (!iterations || iterations>10000000) return 2;
    uint64_t value=0; clock_t start=clock();
    for(size_t i=0;i<iterations;i++) value=rfp_scalar(value);
    report("scalar",iterations,start,value);
    if(value!=iterations) return 1;
    unsigned char array[256]={0}; start=clock();
    for(size_t i=0;i<iterations;i++) {
        unsigned char *copy=malloc(sizeof array);
        if(!copy) return 1;
        memcpy(copy,array,sizeof array); value=rfp_buffer(copy,sizeof array);
        memcpy(array,copy,sizeof array); free(copy);
    }
    report("marshal-256",iterations,start,value);
    if(value!=(iterations%256)) return 1;
    value=0; start=clock();
    for(size_t i=0;i<iterations;i++) value=rfp_callback(direct_callback,value);
    report("callback",iterations,start,value);
    return value!=iterations;
}
#endif
