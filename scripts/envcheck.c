/* The measurements of scripts/envcheck.sh (docs/envcheck.md): one program,
   one command per measurement, each printing key=value lines.

     envcheck-probe cpuid                       vendor, model, caches, topology
     envcheck-probe isa                         each extension: claimed, and run
     envcheck-probe clock SECS                  dependent adds, one core and all
     envcheck-probe fma SECS                    256- and 512-bit FMA throughput
     envcheck-probe pairs SECS all|sample       port sharing of pairs of CPUs
     envcheck-probe pingpong ROUNDS all|sample  a cache line between two CPUs
     envcheck-probe cachecurve MAXKIB           latency of a pointer chase by size
     envcheck-probe cachesizes l1|all MAXKIB    the caches' sizes from that latency,
                                                and L1i from the speed of fetching
     envcheck-probe membw MIB SECS              copy and triad, one thread and all
     envcheck-probe jitter SECS                 pauses of every CPU at once
     envcheck-probe disk DIR MIB SECS NFILES    sequential, random, fsync, files
     envcheck-probe commit STEPMIB CAPMIB FILE  allocate until killed

   Linux, and x86-64 for what reads cpuid or runs instructions of its own;
   elsewhere those commands print KEY.unsupported=... and exit 3, which the
   driver reports as something to add. A command that fails exits 1 with
   error=... on standard output. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <math.h>
#if defined(__x86_64__)
#include <cpuid.h>
#include <sys/syscall.h>
#endif

/* ---------------------------------------------------------------- helpers */

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

static void kv(const char *key, const char *fmt, ...)
{
    va_list ap;
    printf("%s=", key);
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    printf("\n");
}

static int die(const char *what)
{
    kv("error", "%s: %s", what, strerror(errno));
    return 1;
}

/* the CPUs this process may run on, in order */
static int cpus[1024], ncpus;

static void find_cpus(void)
{
    cpu_set_t s;
    ncpus = 0;
    if (sched_getaffinity(0, sizeof s, &s) == 0) {
        for (int c = 0; c < CPU_SETSIZE && ncpus < 1024; c++)
            if (CPU_ISSET(c, &s)) cpus[ncpus++] = c;
    }
    if (ncpus == 0) { cpus[0] = 0; ncpus = 1; }
}

static void pin(int cpu)
{
    cpu_set_t s;
    CPU_ZERO(&s);
    CPU_SET(cpu, &s);
    sched_setaffinity(0, sizeof s, &s);
}

static int cmp_double(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return x < y ? -1 : x > y;
}

/* ---------------------------------------------------------------- threads */

/* A kernel runs for about secs seconds and returns its rate. */
typedef double (*kernel_fn)(double secs, void *arg);

struct job {
    int cpu;
    kernel_fn k;
    double secs;
    void *arg;
    double rate;
    pthread_barrier_t *bar;
};

static void *job_run(void *p)
{
    struct job *j = p;
    if (j->cpu >= 0) pin(j->cpu);
    pthread_barrier_wait(j->bar);
    j->rate = j->k(j->secs, j->arg);
    return 0;
}

/* run k on each of the n CPUs at once; rates[i] is the rate on on[i] */
static void run_on(const int *on, int n, kernel_fn k, double secs, void *arg, double *rates)
{
    pthread_t t[1024];
    struct job j[1024];
    pthread_barrier_t bar;
    pthread_barrier_init(&bar, 0, n);
    for (int i = 0; i < n; i++) {
        j[i].cpu = on[i]; j[i].k = k; j[i].secs = secs; j[i].arg = arg; j[i].bar = &bar;
        pthread_create(&t[i], 0, job_run, &j[i]);
    }
    for (int i = 0; i < n; i++) {
        pthread_join(t[i], 0);
        rates[i] = j[i].rate;
    }
    pthread_barrier_destroy(&bar);
}

#if defined(__x86_64__)

/* ---------------------------------------------------------------- cpuid */

static unsigned maxleaf, maxext;
static char vendor[13];

static void cpuid(unsigned leaf, unsigned sub, unsigned r[4])
{
    r[0] = r[1] = r[2] = r[3] = 0;
    if ((leaf < 0x80000000u && leaf > maxleaf) || (leaf >= 0x80000000u && leaf > maxext)) return;
    __cpuid_count(leaf, sub, r[0], r[1], r[2], r[3]);
}

static void cpuid_init(void)
{
    unsigned r[4];
    __cpuid(0, r[0], r[1], r[2], r[3]);
    maxleaf = r[0];
    memcpy(vendor, &r[1], 4); memcpy(vendor + 4, &r[3], 4); memcpy(vendor + 8, &r[2], 4);
    vendor[12] = 0;
    __cpuid(0x80000000u, r[0], r[1], r[2], r[3]);
    maxext = r[0];
}

static unsigned family, model, stepping;

static void cpuid_fms(void)
{
    unsigned r[4];
    cpuid(1, 0, r);
    stepping = r[0] & 0xf;
    model = (r[0] >> 4) & 0xf;
    family = (r[0] >> 8) & 0xf;
    if (family == 0xf) family += (r[0] >> 20) & 0xff;
    if (family == 6 || family >= 0xf) model += ((r[0] >> 16) & 0xf) << 4;
}

/* Family, model and stepping to a microarchitecture. A server part and a
   client part of one generation have different models. Add rows as new
   machines turn up: an unknown one is reported for that. */
static const struct { const char *vendor; unsigned fam, model, smin, smax; const char *name; } uarchs[] = {
    {"GenuineIntel", 6, 0x2d, 0, 15, "Sandy Bridge-EP"},
    {"GenuineIntel", 6, 0x3e, 0, 15, "Ivy Bridge-EP"},
    {"GenuineIntel", 6, 0x3f, 0, 15, "Haswell-EP"},
    {"GenuineIntel", 6, 0x4f, 0, 15, "Broadwell-EP"},
    {"GenuineIntel", 6, 0x55, 0, 4, "Skylake-SP"},
    {"GenuineIntel", 6, 0x55, 5, 7, "Cascade Lake"},
    {"GenuineIntel", 6, 0x55, 10, 11, "Cooper Lake"},
    {"GenuineIntel", 6, 0x6a, 0, 15, "Ice Lake-SP"},
    {"GenuineIntel", 6, 0x6c, 0, 15, "Ice Lake-D"},
    {"GenuineIntel", 6, 0x8f, 0, 15, "Sapphire Rapids"},
    {"GenuineIntel", 6, 0xcf, 0, 15, "Emerald Rapids"},
    {"GenuineIntel", 6, 0xad, 0, 15, "Granite Rapids"},
    {"GenuineIntel", 6, 0xaf, 0, 15, "Sierra Forest"},
    {"GenuineIntel", 0x13, 0x01, 0, 15, "Diamond Rapids"},
    {"GenuineIntel", 6, 0x4e, 0, 15, "Skylake (client)"},
    {"GenuineIntel", 6, 0x5e, 0, 15, "Skylake (client)"},
    {"GenuineIntel", 6, 0x8e, 0, 15, "Kaby/Coffee/Whiskey Lake (mobile)"},
    {"GenuineIntel", 6, 0x9e, 0, 15, "Kaby/Coffee Lake"},
    {"GenuineIntel", 6, 0xa5, 0, 15, "Comet Lake"},
    {"GenuineIntel", 6, 0xa6, 0, 15, "Comet Lake"},
    {"GenuineIntel", 6, 0x7d, 0, 15, "Ice Lake (client)"},
    {"GenuineIntel", 6, 0x7e, 0, 15, "Ice Lake (client)"},
    {"GenuineIntel", 6, 0x8c, 0, 15, "Tiger Lake"},
    {"GenuineIntel", 6, 0x8d, 0, 15, "Tiger Lake"},
    {"GenuineIntel", 6, 0xa7, 0, 15, "Rocket Lake"},
    {"GenuineIntel", 6, 0x97, 0, 15, "Alder Lake"},
    {"GenuineIntel", 6, 0x9a, 0, 15, "Alder Lake"},
    {"GenuineIntel", 6, 0xb7, 0, 15, "Raptor Lake"},
    {"GenuineIntel", 6, 0xba, 0, 15, "Raptor Lake"},
    {"GenuineIntel", 6, 0xbf, 0, 15, "Raptor Lake"},
    {"GenuineIntel", 6, 0xaa, 0, 15, "Meteor Lake"},
    {"GenuineIntel", 6, 0xac, 0, 15, "Meteor Lake"},
    {"GenuineIntel", 6, 0xbd, 0, 15, "Lunar Lake"},
    {"GenuineIntel", 6, 0xc5, 0, 15, "Arrow Lake"},
    {"GenuineIntel", 6, 0xc6, 0, 15, "Arrow Lake"},
    {"AuthenticAMD", 0x17, 0x01, 0, 15, "Zen (Naples)"},
    {"AuthenticAMD", 0x17, 0x08, 0, 15, "Zen+"},
    {"AuthenticAMD", 0x17, 0x31, 0, 15, "Zen 2 (Rome)"},
    {"AuthenticAMD", 0x17, 0x60, 0, 15, "Zen 2 (Renoir)"},
    {"AuthenticAMD", 0x17, 0x71, 0, 15, "Zen 2 (Matisse)"},
    {"AuthenticAMD", 0x19, 0x01, 0, 15, "Zen 3 (Milan)"},
    {"AuthenticAMD", 0x19, 0x21, 0, 15, "Zen 3 (Vermeer)"},
    {"AuthenticAMD", 0x19, 0x44, 0, 15, "Zen 3+ (Rembrandt)"},
    {"AuthenticAMD", 0x19, 0x50, 0, 15, "Zen 3 (Cezanne)"},
    {"AuthenticAMD", 0x19, 0x11, 0, 15, "Zen 4 (Genoa)"},
    {"AuthenticAMD", 0x19, 0x61, 0, 15, "Zen 4 (Raphael)"},
    {"AuthenticAMD", 0x19, 0x74, 0, 15, "Zen 4 (Phoenix)"},
    {"AuthenticAMD", 0x19, 0xa0, 0, 15, "Zen 4c (Bergamo)"},
    {"AuthenticAMD", 0x1a, 0x02, 0, 15, "Zen 5 (Turin)"},
    {"AuthenticAMD", 0x1a, 0x11, 0, 15, "Zen 5c (Turin dense)"},
    {"AuthenticAMD", 0x1a, 0x24, 0, 15, "Zen 5 (Strix Point)"},
    {"AuthenticAMD", 0x1a, 0x44, 0, 15, "Zen 5 (Granite Ridge)"},
};

static int cmd_cpuid(void)
{
    unsigned r[4];
    char brand[49] = "";
    cpuid_init();
    cpuid_fms();
    kv("cpu.vendor", "%s", vendor);
    kv("cpu.family", "%u", family);
    kv("cpu.model", "%u", model);
    kv("cpu.model_hex", "0x%x", model);
    kv("cpu.stepping", "%u", stepping);
    if (maxext >= 0x80000004u) {
        for (unsigned i = 0; i < 3; i++) {
            cpuid(0x80000002u + i, 0, r);
            memcpy(brand + 16 * i, r, 16);
        }
        brand[48] = 0;
        char *b = brand;
        while (*b == ' ') b++;
        kv("cpu.brand", "%s", b);
    }
    const char *ua = 0;
    for (size_t i = 0; i < sizeof uarchs / sizeof uarchs[0]; i++)
        if (!strcmp(uarchs[i].vendor, vendor) && uarchs[i].fam == family && uarchs[i].model == model
            && stepping >= uarchs[i].smin && stepping <= uarchs[i].smax) { ua = uarchs[i].name; break; }
    kv("cpu.uarch", "%s", ua ? ua : "unknown");
    cpuid(1, 0, r);
    if (r[2] >> 31 & 1) {
        char hv[13];
        unsigned h[4];
        __cpuid(0x40000000u, h[0], h[1], h[2], h[3]);
        memcpy(hv, &h[1], 4); memcpy(hv + 4, &h[2], 4); memcpy(hv + 8, &h[3], 4);
        hv[12] = 0;
        kv("cpu.hypervisor", "%s", hv);
    } else kv("cpu.hypervisor", "none");
    /* caches: leaf 4 (Intel), 0x8000001d (AMD) */
    unsigned leaf = !strcmp(vendor, "AuthenticAMD") ? 0x8000001du : 4;
    for (unsigned i = 0; i < 16; i++) {
        cpuid(leaf, i, r);
        unsigned type = r[0] & 0x1f;
        if (type == 0) break;
        unsigned level = (r[0] >> 5) & 7;
        unsigned sharing = ((r[0] >> 14) & 0xfff) + 1;
        unsigned line = (r[1] & 0xfff) + 1, parts = ((r[1] >> 12) & 0x3ff) + 1, ways = (r[1] >> 22) + 1;
        unsigned long sets = (unsigned long)r[2] + 1;
        char key[64];
        const char *t = type == 1 ? "d" : type == 2 ? "i" : "";
        snprintf(key, sizeof key, "cache.L%u%s", level, t);
        kv(key, "%lu KiB, %u-way, %u-byte lines, shared by up to %u logical CPUs",
           (unsigned long)ways * parts * line * sets / 1024, ways, line, sharing);
    }
    /* topology: leaf 0xb, as the hypervisor presents it */
    if (maxleaf >= 0xb) {
        cpuid(0xb, 0, r);
        if (r[1]) kv("topo.logical_per_core", "%u", r[1] & 0xffff);
        cpuid(0xb, 1, r);
        if (r[1]) kv("topo.logical_per_package", "%u", r[1] & 0xffff);
    }
    if (maxleaf >= 0x16) {
        cpuid(0x16, 0, r);
        if (r[0]) kv("cpu.base_mhz_cpuid", "%u", r[0] & 0xffff);
        if (r[1]) kv("cpu.max_mhz_cpuid", "%u", r[1] & 0xffff);
    }
    return 0;
}

/* ---------------------------------------------------------------- isa */

static sigjmp_buf jb;
static void on_sigill(int s) { (void)s; siglongjmp(jb, 1); }
static unsigned char membuf[128] __attribute__((aligned(64)));

#define T(fn, body) static void fn(void) { __asm__ volatile(body ::: "memory", "cc", "xmm0", "xmm1", "xmm2"); }
T(t_sse42, "crc32l %%eax, %%eax")
T(t_popcnt, "popcnt %%eax, %%eax")
T(t_avx, "vxorps %%ymm0, %%ymm0, %%ymm0")
T(t_avx2, "vpaddd %%ymm0, %%ymm1, %%ymm2")
T(t_fma, "vfmadd231ps %%ymm0, %%ymm1, %%ymm2")
T(t_f16c, "vcvtph2ps %%xmm0, %%xmm1")
T(t_bmi1, "andn %%eax, %%eax, %%eax")
T(t_bmi2, "pdep %%eax, %%eax, %%eax")
T(t_adx, "adcx %%eax, %%eax")
T(t_aes, "aesenc %%xmm0, %%xmm1")
T(t_pclmul, "pclmulqdq $0, %%xmm0, %%xmm1")
T(t_sha, "sha256rnds2 %%xmm0, %%xmm1, %%xmm2")
T(t_vaes, "vaesenc %%ymm0, %%ymm1, %%ymm2")
T(t_vpclmul, "vpclmulqdq $0, %%ymm0, %%ymm1, %%ymm2")
T(t_gfni, "gf2p8mulb %%xmm0, %%xmm1")
T(t_avxvnni, "%{vex%} vpdpbusd %%ymm0, %%ymm1, %%ymm2")
T(t_avx512f, "vpaddd %%zmm0, %%zmm1, %%zmm2")
T(t_avx512dq, "vpmullq %%zmm0, %%zmm1, %%zmm2")
T(t_avx512bw, "vpaddb %%zmm0, %%zmm1, %%zmm2")
T(t_avx512vl, "vpaddd %%ymm0, %%ymm1, %%ymm2%{%%k1%}")
T(t_avx512cd, "vplzcntd %%zmm0, %%zmm1")
T(t_avx512ifma, "vpmadd52luq %%zmm0, %%zmm1, %%zmm2")
T(t_avx512vbmi, "vpermb %%zmm0, %%zmm1, %%zmm2")
T(t_avx512vbmi2, "vpshldw $1, %%zmm0, %%zmm1, %%zmm2")
T(t_avx512vnni, "vpdpbusd %%zmm0, %%zmm1, %%zmm2")
T(t_avx512bitalg, "vpopcntb %%zmm0, %%zmm1")
T(t_avx512vpopcntdq, "vpopcntd %%zmm0, %%zmm1")
T(t_avx512bf16, "vdpbf16ps %%zmm0, %%zmm1, %%zmm2")
T(t_avx512fp16, "vaddph %%zmm0, %%zmm1, %%zmm2")
T(t_amx, "tilerelease")
T(t_rdrand, "rdrand %%eax")
T(t_rdseed, "rdseed %%eax")
T(t_rdpid, "rdpid %%rax")
T(t_serialize, "serialize")
static void t_movbe(void) { __asm__ volatile("movbe (%0), %%eax" :: "r"(membuf) : "eax", "memory"); }
static void t_movdiri(void) { __asm__ volatile("movdiri %%eax, (%0)" :: "r"(membuf) : "memory"); }
static void t_clflushopt(void) { __asm__ volatile("clflushopt (%0)" :: "r"(membuf) : "memory"); }
static void t_clwb(void) { __asm__ volatile("clwb (%0)" :: "r"(membuf) : "memory"); }
/* A tile multiply of an AMX extension needs the tiles configured, and Linux
   lets a process use the tile data only once it has asked
   (ARCH_REQ_XCOMP_PERM for XTILEDATA); without it the multiply faults too.
   The newer extensions are what tells the newest hardware under an older
   CPU model, where the AMX state is on already. The instructions are given
   as bytes, from binutils 2.47: older assemblers do not know them. */
static void amx_config(void)
{
    static unsigned char cfg[64] __attribute__((aligned(64)));
    memset(cfg, 0, sizeof cfg);
    cfg[0] = 1;   /* palette 1; tiles 0 to 2 of 16 rows of 64 bytes */
    for (int i = 0; i < 3; i++) { cfg[16 + 2 * i] = 64; cfg[48 + i] = 16; }
    syscall(SYS_arch_prctl, 0x1023, 18);
    __asm__ volatile("ldtilecfg %0" :: "m"(cfg) : "memory");
}
#define AMX_T(fn, bytes) \
    static void fn(void) { amx_config(); __asm__ volatile(".byte " bytes "\n\ttilerelease" ::: "memory"); }
AMX_T(t_amxfp16, "0xc4, 0xe2, 0x6b, 0x5c, 0xc1")   /* tdpfp16ps %tmm2, %tmm1, %tmm0: Granite Rapids on */
AMX_T(t_amxfp8, "0xc4, 0xe5, 0x68, 0xfd, 0xc1")    /* tdpbf8ps %tmm2, %tmm1, %tmm0: Diamond Rapids on */
/* AVX10.2 (Diamond Rapids on, and Intel's client parts from Nova Lake):
   vminmaxps $0, %zmm0, %zmm1, %zmm2, which needs only the AVX-512 state */
T(t_avx102, ".byte 0x62, 0xf3, 0x75, 0x48, 0x52, 0xd0, 0x00")

/* An extension: where cpuid claims it (leaf, subleaf, register eax=0 ebx=1
   ecx=2 edx=3, bit), what state the operating system must have enabled
   (1 AVX, 2 AVX-512, 3 AMX), and one instruction of it, or none where
   running one says nothing (lzcnt runs as bsr without it). */
static const struct { const char *name; unsigned leaf, sub, reg, bit, os; void (*test)(void); } isas[] = {
    {"sse4.2", 1, 0, 2, 20, 0, t_sse42},
    {"popcnt", 1, 0, 2, 23, 0, t_popcnt},
    {"aes", 1, 0, 2, 25, 0, t_aes},
    {"pclmulqdq", 1, 0, 2, 1, 0, t_pclmul},
    {"movbe", 1, 0, 2, 22, 0, t_movbe},
    {"cx16", 1, 0, 2, 13, 0, 0},
    {"rdrand", 1, 0, 2, 30, 0, t_rdrand},
    {"avx", 1, 0, 2, 28, 1, t_avx},
    {"fma", 1, 0, 2, 12, 1, t_fma},
    {"f16c", 1, 0, 2, 29, 1, t_f16c},
    {"lzcnt", 0x80000001u, 0, 2, 5, 0, 0},
    {"bmi1", 7, 0, 1, 3, 0, t_bmi1},
    {"avx2", 7, 0, 1, 5, 1, t_avx2},
    {"bmi2", 7, 0, 1, 8, 0, t_bmi2},
    {"rdseed", 7, 0, 1, 18, 0, t_rdseed},
    {"adx", 7, 0, 1, 19, 0, t_adx},
    {"clflushopt", 7, 0, 1, 23, 0, t_clflushopt},
    {"clwb", 7, 0, 1, 24, 0, t_clwb},
    {"sha", 7, 0, 1, 29, 0, t_sha},
    {"rtm", 7, 0, 1, 11, 0, 0},
    {"gfni", 7, 0, 2, 8, 0, t_gfni},
    {"vaes", 7, 0, 2, 9, 1, t_vaes},
    {"vpclmulqdq", 7, 0, 2, 10, 1, t_vpclmul},
    {"rdpid", 7, 0, 2, 22, 0, t_rdpid},
    {"movdiri", 7, 0, 2, 27, 0, t_movdiri},
    {"serialize", 7, 0, 3, 14, 0, t_serialize},
    {"avx-vnni", 7, 1, 0, 4, 1, t_avxvnni},
    {"avx512f", 7, 0, 1, 16, 2, t_avx512f},
    {"avx512dq", 7, 0, 1, 17, 2, t_avx512dq},
    {"avx512ifma", 7, 0, 1, 21, 2, t_avx512ifma},
    {"avx512cd", 7, 0, 1, 28, 2, t_avx512cd},
    {"avx512bw", 7, 0, 1, 30, 2, t_avx512bw},
    {"avx512vl", 7, 0, 1, 31, 2, t_avx512vl},
    {"avx512vbmi", 7, 0, 2, 1, 2, t_avx512vbmi},
    {"avx512vbmi2", 7, 0, 2, 6, 2, t_avx512vbmi2},
    {"avx512vnni", 7, 0, 2, 11, 2, t_avx512vnni},
    {"avx512bitalg", 7, 0, 2, 12, 2, t_avx512bitalg},
    {"avx512vpopcntdq", 7, 0, 2, 14, 2, t_avx512vpopcntdq},
    {"avx512bf16", 7, 1, 0, 5, 2, t_avx512bf16},
    {"avx512fp16", 7, 0, 3, 23, 2, t_avx512fp16},
    {"amx-tile", 7, 0, 3, 24, 3, t_amx},
    {"amx-fp16", 7, 1, 0, 21, 3, t_amxfp16},
    {"amx-fp8", 0x1e, 1, 0, 4, 3, t_amxfp8},
    /* leaf 0x24: EBX[7:0] is the AVX10 version; bit 1 is set in 2 and 3 */
    {"avx10.2", 0x24, 0, 1, 1, 2, t_avx102},
};

static unsigned long long xcr0(void)
{
    unsigned r[4];
    cpuid(1, 0, r);
    if (!(r[2] >> 27 & 1)) return 0;   /* no OSXSAVE */
    unsigned lo, hi;
    __asm__ volatile("xgetbv" : "=a"(lo), "=d"(hi) : "c"(0));
    return (unsigned long long)hi << 32 | lo;
}

static int cmd_isa(void)
{
    cpuid_init();
    unsigned long long x = xcr0();
    int os_ok[4] = {1, (x & 6) == 6, (x & 0xe6) == 0xe6, (x & 0x60000) == 0x60000};
    kv("isa.xcr0", "0x%llx", x);
    struct sigaction sa, old;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_sigill;
    sigaction(SIGILL, &sa, &old);
    for (size_t i = 0; i < sizeof isas / sizeof isas[0]; i++) {
        unsigned r[4];
        cpuid(isas[i].leaf, isas[i].sub, r);
        int claimed = r[isas[i].reg] >> isas[i].bit & 1;
        const char *v;
        char key[64];
        snprintf(key, sizeof key, "isa.%s", isas[i].name);
        if (!isas[i].test) v = claimed ? "yes (claimed; not run)" : "no";
        else {
            int runs;
            if (sigsetjmp(jb, 1) == 0) { isas[i].test(); runs = 1; } else runs = 0;
            if (claimed && runs) v = "yes";
            else if (!claimed && !runs) v = "no";
            else if (claimed && !os_ok[isas[i].os]) v = "claimed, but not enabled by the OS (XCR0)";
            else if (claimed) v = "MISMATCH: claimed by cpuid but faults";
            else v = "MISMATCH: runs but cpuid does not claim it";
        }
        kv(key, "%s", v);
    }
    sigaction(SIGILL, &old, 0);
    return 0;
}

/* ---------------------------------------------------------------- kernels */

/* dependent adds: one a cycle, so adds a second is the clock. What is added
   is a register, not an immediate: from Golden Cove on (Alder Lake, Sapphire
   and Emerald Rapids) the renamer does adds of an immediate and `inc`
   itself, several of one chain a cycle, and the clock came out at 16 GHz */
static double k_chain(double secs, void *arg)
{
    (void)arg;
    unsigned long x = 0, n = 0, one = 1;
    double t0 = now(), t;
    do {
        for (int i = 0; i < 1000000; i++)
            __asm__ volatile("add %1,%0\n\tadd %1,%0\n\tadd %1,%0\n\tadd %1,%0\n\t"
                             "add %1,%0\n\tadd %1,%0\n\tadd %1,%0\n\tadd %1,%0" : "+r"(x) : "r"(one));
        n += 8000000;
        t = now() - t0;
    } while (t < secs);
    return n / t;
}

/* independent adds: as many a cycle as there are integer ports (of a
   register, as in k_chain, or they would be done by the renamer) */
static double k_alu(double secs, void *arg)
{
    (void)arg;
    unsigned long a = 0, b = 0, c = 0, d = 0, e = 0, f = 0, g = 0, h = 0, n = 0, one = 1;
    double t0 = now(), t;
    do {
        for (int i = 0; i < 1000000; i++)
            __asm__ volatile("add %8,%0\n\tadd %8,%1\n\tadd %8,%2\n\tadd %8,%3\n\t"
                             "add %8,%4\n\tadd %8,%5\n\tadd %8,%6\n\tadd %8,%7"
                             : "+r"(a), "+r"(b), "+r"(c), "+r"(d), "+r"(e), "+r"(f), "+r"(g), "+r"(h)
                             : "r"(one));
        n += 8000000;
        t = now() - t0;
    } while (t < secs);
    return n / t;
}

/* 12 independent FMAs a round, 256 or 512 bits wide */
#define FMA12(w) \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "1\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "2\n\t" \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "3\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "4\n\t" \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "5\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "6\n\t" \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "7\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "8\n\t" \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "9\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "10\n\t" \
    "vfmadd231ps %%" w "0, %%" w "0, %%" w "11\n\tvfmadd231ps %%" w "0, %%" w "0, %%" w "12\n\t"
#define FMA_CLOBBERS "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "xmm8", \
    "xmm9", "xmm10", "xmm11", "xmm12", "cc"

static double k_fma256(double secs, void *arg)
{
    (void)arg;
    double t0 = now(), t;
    unsigned long n = 0;
    do {
        long k = 1000000;
        __asm__ volatile("vxorps %%ymm0, %%ymm0, %%ymm0\n1:\n\t" FMA12("ymm") "dec %0\n\tjnz 1b"
                         : "+r"(k) :: FMA_CLOBBERS);
        n += 12000000;
        t = now() - t0;
    } while (t < secs);
    __asm__ volatile("vzeroupper");
    return n / t;
}

static double k_fma512(double secs, void *arg)
{
    (void)arg;
    double t0 = now(), t;
    unsigned long n = 0;
    do {
        long k = 1000000;
        __asm__ volatile("vxorps %%zmm0, %%zmm0, %%zmm0\n1:\n\t" FMA12("zmm") "dec %0\n\tjnz 1b"
                         : "+r"(k) :: FMA_CLOBBERS);
        n += 12000000;
        t = now() - t0;
    } while (t < secs);
    __asm__ volatile("vzeroupper");
    return n / t;
}

static int has(const char *name)
{
    unsigned long long x = xcr0();
    for (size_t i = 0; i < sizeof isas / sizeof isas[0]; i++)
        if (!strcmp(isas[i].name, name)) {
            unsigned r[4];
            cpuid(isas[i].leaf, isas[i].sub, r);
            int os = isas[i].os == 1 ? (x & 6) == 6 : isas[i].os == 2 ? (x & 0xe6) == 0xe6 : 1;
            return (r[isas[i].reg] >> isas[i].bit & 1) && os;
        }
    return 0;
}

/* rates of k on one core alone, then on every CPU at once: summary lines */
static void one_and_all(const char *key, kernel_fn k, double secs, double scale, const char *unit)
{
    double one, all[1024], sum = 0, lo = 1e30, hi = 0;
    run_on(cpus, 1, k, secs, 0, &one);
    run_on(cpus, ncpus, k, secs, 0, all);
    for (int i = 0; i < ncpus; i++) { sum += all[i]; if (all[i] < lo) lo = all[i]; if (all[i] > hi) hi = all[i]; }
    char kk[96];
    snprintf(kk, sizeof kk, "%s.one_core", key);
    kv(kk, "%.2f %s", one / scale, unit);
    snprintf(kk, sizeof kk, "%s.all_cores_each", key);
    kv(kk, "%.2f %s on average (%.2f to %.2f)", sum / ncpus / scale, unit, lo / scale, hi / scale);
}

static int cmd_clock(double secs)
{
    find_cpus();
    cpuid_init();
    /* repeated on one core, for the spread that neighbours cause */
    double r[5], sum = 0, sq = 0;
    for (int i = 0; i < 5; i++) { run_on(cpus, 1, k_chain, secs / 5, 0, &r[i]); sum += r[i]; }
    double mean = sum / 5;
    for (int i = 0; i < 5; i++) sq += (r[i] - mean) * (r[i] - mean);
    one_and_all("clock.scalar", k_chain, secs, 1e9, "GHz");
    kv("clock.scalar.spread_of_5_runs", "%.1f%% (coefficient of variation)", 100 * sqrt(sq / 5) / mean);
    return 0;
}


static int cmd_fma(double secs)
{
    find_cpus();
    cpuid_init();
    double clock;
    run_on(cpus, 1, k_chain, secs / 4, 0, &clock);
    if (has("fma")) {
        double one;
        run_on(cpus, 1, k_fma256, secs / 2, 0, &one);
        kv("fma.256.one_core", "%.2f G FMA instructions/s = %.2f a cycle at the scalar clock", one / 1e9, one / clock);
    } else kv("fma.256", "not available");
    if (has("avx512f")) {
        double one;
        run_on(cpus, 1, k_fma512, secs / 2, 0, &one);
        kv("fma.512.one_core", "%.2f G FMA instructions/s = %.2f a cycle at the scalar clock", one / 1e9, one / clock);
        kv("fma.512.note", "%s", "2 a cycle is two FMA units at full clock; less is fewer units or a lower AVX-512 clock");
    } else kv("fma.512", "not available");
    return 0;
}

/* pairs of CPUs: all of them, or CPU 0 with each other (at most 16) */
static int pairs_of(const char *which, int (*p)[2])
{
    int n = 0;
    if (!strcmp(which, "all") && ncpus <= 24) {
        for (int i = 0; i < ncpus; i++)
            for (int j = i + 1; j < ncpus; j++) { p[n][0] = cpus[i]; p[n][1] = cpus[j]; n++; }
    } else {
        for (int j = 1; j < ncpus && j <= 16; j++) { p[n][0] = cpus[0]; p[n][1] = cpus[j]; n++; }
    }
    return n;
}

/* Each pair three times: the host can move a vCPU from one core to
   another, so two vCPUs may share a core only now and then. */
static int cmd_pairs(double secs, const char *which)
{
    static int p[300][2];
    find_cpus();
    cpuid_init();
    if (ncpus < 2) { kv("pairs", "only one CPU"); return 0; }
    int n = pairs_of(which, p), reps = 3;
    double alone[1024];
    for (int i = 0; i < ncpus; i++) run_on(&cpus[i], 1, k_alu, secs, 0, &alone[i]);
    double worst = 1e9;
    int always = 0, sometimes = 0;
    char la[2048] = "", ls[2048] = "";
    for (int k = 0; k < n; k++) {
        int ia = 0, ib = 0;
        for (int i = 0; i < ncpus; i++) { if (cpus[i] == p[k][0]) ia = i; if (cpus[i] == p[k][1]) ib = i; }
        double lo = 1e9, hi = 0;
        for (int rep = 0; rep < reps; rep++) {
            double r[2];
            run_on(p[k], 2, k_alu, secs / reps, 0, r);
            double ratio = (r[0] / alone[ia] + r[1] / alone[ib]) / 2;
            if (ratio < lo) lo = ratio;
            if (ratio > hi) hi = ratio;
        }
        if (lo < worst) worst = lo;
        char *l = hi < 0.75 ? la : lo < 0.75 ? ls : 0;
        if (l) {
            size_t m = strlen(l);
            snprintf(l + m, 2048 - m, "%s%d+%d", m ? " " : "", p[k][0], p[k][1]);
            if (hi < 0.75) always++; else sometimes++;
        }
        char key[64];
        snprintf(key, sizeof key, "pairs.cpu%d+cpu%d", p[k][0], p[k][1]);
        kv(key, "%.2f to %.2f of the throughput alone (%d rounds)", lo, hi, reps);
    }
    kv("pairs.tested", "%d (%s)", n, !strcmp(which, "all") && ncpus <= 24 ? "all pairs" : "CPU 0 with the others");
    kv("pairs.lowest_ratio", "%.2f", worst);
    kv("pairs.always_sharing_a_core", "%s", always ? la : "none");
    kv("pairs.sometimes_sharing_a_core", "%s", sometimes ? ls : "none");
    kv("pairs.note", "%s", "below 0.75 two vCPUs ran on two threads of one core; sometimes means the host moved them there for a while");
    return 0;
}

/* ---------------------------------------------------------------- pingpong */

static volatile int flag __attribute__((aligned(64)));
static int pong_cpu, pong_rounds;

static void *pong(void *a)
{
    (void)a;
    pin(pong_cpu);
    for (int i = 0; i < pong_rounds; i++) { while (flag != 1) ; flag = 0; }
    return 0;
}

static double pingpong(int a, int b, int rounds)
{
    pthread_t t;
    flag = 0; pong_cpu = b; pong_rounds = rounds;
    pthread_create(&t, 0, pong, 0);
    pin(a);
    double t0 = now();
    for (int i = 0; i < rounds; i++) { flag = 1; while (flag != 0) ; }
    double dt = now() - t0;
    pthread_join(t, 0);
    return dt / rounds / 2 * 1e9;
}

static int cmd_pingpong(int rounds, const char *which)
{
    static int p[300][2];
    find_cpus();
    if (ncpus < 2) { kv("pingpong", "only one CPU"); return 0; }
    int n = pairs_of(which, p), reps = 3;
    double all[900];
    int m = 0;
    for (int k = 0; k < n; k++) {
        double lo = 1e30, hi = 0;
        for (int r = 0; r < reps; r++) {
            double ns = pingpong(p[k][0], p[k][1], rounds);
            all[m++] = ns;
            if (ns < lo) lo = ns;
            if (ns > hi) hi = ns;
        }
        char key[64];
        snprintf(key, sizeof key, "pingpong.cpu%d+cpu%d", p[k][0], p[k][1]);
        kv(key, "%.0f to %.0f ns one way (%d rounds)", lo, hi, reps);
    }
    qsort(all, m, sizeof all[0], cmp_double);
    int near = 0;
    for (int i = 0; i < m; i++) if (all[i] <= 30) near++;
    kv("pingpong.summary", "min %.0f, median %.0f, max %.0f ns; %d of %d rounds at 30 ns or less (two threads of one core)",
       all[0], all[m / 2], all[m - 1], near, m);
    kv("pingpong.note", "%s", "about 20 ns is two threads of one core, 40 to 80 ns one socket, 120 ns or more another socket; a pair that changes between rounds is moved by the host");
    return 0;
}

/* ---------------------------------------------------------------- l1i */

/* The L1 instruction cache as fetching shows it: a straight line of 8-byte
   NOPs, run over and over, is fetched at full speed while it fits and from
   L2 past it, at less than half the bytes a nanosecond. The step as it
   outgrows the decoded-uop cache, earlier, is smaller. cpuid's size is the
   one of the CPU model presented: Granite Rapids showed its 64 KiB under an
   Emerald Rapids model of 32. Three sweeps, keeping the largest edge, as
   for L1d: another VM's thread on the core makes the cache look smaller. */
static void l1i_size(void)
{
    static const unsigned char nop8[8] = {0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00};
    size_t max = 256 * 1024 + 4096;
    unsigned char *code = mmap(0, max, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (code == MAP_FAILED) { kv("cachesize.L1i", "not measured (mmap)"); return; }
    long edge = 0, past = 0;
    double below = 0, above = 0;
    int measured = 0;
    for (int sweep = 0; sweep < 3; sweep++) {
        long kib[64];
        double rate[64];
        int n = 0;
        for (long k = 8; k <= 256; k += k < 96 ? 8 : 32) {
            size_t len = (size_t)k * 1024;
            if (mprotect(code, max, PROT_READ | PROT_WRITE)) break;
            for (size_t i = 0; i < len; i += 8) memcpy(code + i, nop8, 8);
            code[len] = 0xc3;   /* ret */
            if (mprotect(code, max, PROT_READ | PROT_EXEC)) break;
            void (*f)(void);
            memcpy(&f, &code, sizeof f);
            size_t reps = ((size_t)64 << 20) / len;
            double best = 1e30;
            for (int t = 0; t < 5; t++) {
                double t0 = now();
                for (size_t r = 0; r < reps; r++) f();
                double dt = now() - t0;
                if (dt < best) best = dt;
            }
            kib[n] = k;
            rate[n++] = (double)len * reps / best / 1e9;
        }
        if (n < 2) break;
        measured = 1;
        /* the edge: the largest fall from one size to the next, by more than half */
        int e = 0;
        for (int i = 1; i + 1 < n; i++) if (rate[i + 1] / rate[i] < rate[e + 1] / rate[e]) e = i;
        if (rate[e + 1] / rate[e] <= 0.5 && kib[e] > edge) {
            edge = kib[e]; past = kib[e + 1]; below = rate[e]; above = rate[e + 1];
        }
    }
    munmap(code, max);
    if (!measured) kv("cachesize.L1i", "not measured (no memory both written and run)");
    else if (!edge) kv("cachesize.L1i", "no step found (the fetch never falls by half)");
    else kv("cachesize.L1i", "%ld KiB (%.0f bytes of code a ns below it, %.0f past it; exact: the edge is between %ld and %ld KiB; the largest of three sweeps)",
            edge, below, above, edge, past);
}

#endif /* __x86_64__ */

/* ---------------------------------------------------------------- memory */

/* latency of a pointer chase through a random cycle of cache lines */
static int cmd_cachecurve(long maxkib)
{
    find_cpus();
    pin(cpus[0]);
    for (long kib = 4; kib <= maxkib; kib *= 2) {
        size_t n = (size_t)kib * 1024 / 64;
        void **buf;
        if (posix_memalign((void **)&buf, 64, n * 64)) return die("posix_memalign");
        size_t *order = malloc(n * sizeof *order);
        if (!order) return die("malloc");
        for (size_t i = 0; i < n; i++) order[i] = i;
        unsigned long s = 88172645463325252ul;
        for (size_t i = n - 1; i > 0; i--) {
            s ^= s << 13; s ^= s >> 7; s ^= s << 17;
            size_t j = s % (i + 1), t = order[i];
            order[i] = order[j]; order[j] = t;
        }
        for (size_t i = 0; i < n; i++) buf[order[i] * 8] = &buf[order[(i + 1) % n] * 8];
        free(order);
        void **q = &buf[0];
        long steps = 2000000;
        for (long i = 0; i < steps / 4; i++) q = *q;          /* warm */
        double t0 = now();
        for (long i = 0; i < steps; i++) q = *q;
        double ns = (now() - t0) / steps * 1e9;
        if (!q) printf("#\n");
        char key[64];
        if (kib < 1024) snprintf(key, sizeof key, "cachecurve.%ldKiB", kib);
        else snprintf(key, sizeof key, "cachecurve.%ldMiB", kib / 1024);
        kv(key, "%.1f ns a load", ns);
        free(buf);
    }
    kv("cachecurve.note", "%s", "the steps are the caches; the last value is the latency of memory");
    return 0;
}

/* ---------------------------------------------------------------- sizes */

/* The latency of a pointer chase through a random cycle of the cache lines
   of the first bytes of arena, the best of two passes. The arena asks for
   huge pages, so that misses in the TLB blur the steps less. */
static char *arena;
static size_t arena_size;

static double chase_ns(size_t bytes, long loads)
{
    size_t n = bytes / 64;
    void **b = (void **)arena;
    size_t *order = malloc(n * sizeof *order);
    if (!order) return -1;
    for (size_t i = 0; i < n; i++) order[i] = i;
    unsigned long s = 88172645463325252ul;
    for (size_t i = n - 1; i > 0; i--) {
        s ^= s << 13; s ^= s >> 7; s ^= s << 17;
        size_t j = s % (i + 1), t = order[i];
        order[i] = order[j]; order[j] = t;
    }
    for (size_t i = 0; i < n; i++) b[order[i] * 8] = &b[order[(i + 1) % n] * 8];
    free(order);
    void **q = &b[0];
    for (long i = 0; i < loads / 4; i++) q = *q;
    double best = 1e9;
    for (int r = 0; r < 2; r++) {
        double t0 = now();
        for (long i = 0; i < loads; i++) q = *q;
        double ns = (now() - t0) / loads * 1e9;
        if (ns < best) best = ns;
    }
    if (!q) printf("#\n");
    return best;
}

/* Sweep sizes from lo to hi KiB, eight steps an octave (or step KiB apart
   when step > 0), and find the edge: the last size before the latency
   crosses the geometric middle of the plateau at the start and the one at
   the end, for two sizes in a row. Returns the edge in KiB, 0 when there
   is none, and the two plateaus. */
static long sweep(long lo, long hi, long step, long loads, double *plo, double *phi)
{
    long size[256];
    double lat[256];
    int n = 0;
    for (double k = lo; k <= hi && n < 256; k = step > 0 ? k + step : k * 1.0905077) {
        long kib = ((long)(k + 0.5) + 3) / 4 * 4;
        if (n && kib == size[n - 1]) continue;
        if ((size_t)kib * 1024 > arena_size) break;
        size[n] = kib;
        lat[n] = chase_ns((size_t)kib * 1024, loads);
        n++;
    }
    if (n < 6) return 0;
    double a = lat[0], z = lat[n - 1];
    for (int i = 1; i < 3; i++) if (lat[i] < a) a = lat[i];
    for (int i = n - 3; i < n - 1; i++) if (lat[i] < z) z = lat[i];
    *plo = a; *phi = z;
    if (z < a * 1.5) return 0;                 /* no step in this range */
    double mid = sqrt(a * z);
    for (int i = 1; i + 1 < n; i++)
        if (lat[i] > mid && lat[i + 1] > mid) return size[i - 1];
    return 0;
}

static void size_kv(const char *key, long kib, double a, double z, const char *how)
{
    if (!kib) { kv(key, "no step found (%s)", how); return; }
    if (kib >= 1024 && kib % 1024 == 0) kv(key, "%ld MiB (%.1f ns a load below it, %.1f ns past it; %s)", kib / 1024, a, z, how);
    else if (kib >= 1024) kv(key, "%.2f MiB (%.1f ns a load below it, %.1f ns past it; %s)", kib / 1024.0, a, z, how);
    else kv(key, "%ld KiB (%.1f ns a load below it, %.1f ns past it; %s)", kib, a, z, how);
}

/* The caches' sizes as the latency shows them: L1 always, L2 and L3 when
   levels is "all". What a VM gets of a shared L3 can be far less than the
   L3 that cpuid reports. */
static int cmd_cachesizes(const char *levels, long maxkib)
{
    find_cpus();
    pin(cpus[0]);
    arena_size = (size_t)maxkib * 1024;
    arena = mmap(0, arena_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (arena == MAP_FAILED) return die("mmap");
#ifdef MADV_HUGEPAGE
    madvise(arena, arena_size, MADV_HUGEPAGE);
#endif
    memset(arena, 0, arena_size);
    double a, z;
    /* three times, keeping the largest edge: a thread of another VM on the
       other hyperthread of the core shares the L1 for a while, and makes it
       look smaller (40 KiB of 48 in one sweep in four on Granite Rapids) */
    long l1 = 0;
    for (int r = 0; r < 3; r++) {
        double ra, rz;
        long e = sweep(8, 160, 4, 2000000, &ra, &rz);
        if (e > l1 || r == 0) { l1 = e; a = ra; z = rz; }
    }
    size_kv("cachesize.L1d", l1, a, z, "exact: its edge is sharp; the largest of three sweeps");
#if defined(__x86_64__)
    l1i_size();
#endif
    if (strcmp(levels, "all")) return 0;
    long from = l1 ? l1 * 4 : 256;
    long l2 = sweep(from, 4096, 0, 1000000, &a, &z);
    size_kv("cachesize.L2", l2, a, z, "about: an effective size, where the latency is halfway to the next level");
    long l3 = sweep(l2 ? l2 * 2 : 4096, maxkib, 0, 300000, &a, &z);
    size_kv("cachesize.L3", l3, a, z, "about: what this process gets of it, which in a VM can be far less than the whole");
    return 0;
}

struct bw { double *a, *b, *c; size_t n; int op; };

static double k_bw(double secs, void *arg)
{
    struct bw *w = arg;
    double best = 0, t0 = now();
    do {
        double t1 = now();
        if (w->op == 0) for (size_t i = 0; i < w->n; i++) w->a[i] = w->b[i];
        else for (size_t i = 0; i < w->n; i++) w->a[i] = w->b[i] + 3.0 * w->c[i];
        double dt = now() - t1, bytes = (w->op == 0 ? 16.0 : 24.0) * w->n, r = bytes / dt;
        if (r > best) best = r;
    } while (now() - t0 < secs);
    return best;
}

static int cmd_membw(long mib, double secs)
{
    find_cpus();
    size_t n = (size_t)mib * 1024 * 1024 / 8;
    double *a = malloc(n * 8), *b = malloc(n * 8), *c = malloc(n * 8);
    if (!a || !b || !c) return die("malloc");
    for (size_t i = 0; i < n; i++) { a[i] = 0; b[i] = i; c[i] = 1; }
    for (int op = 0; op < 2; op++) {
        const char *name = op ? "triad" : "copy";
        struct bw one = {a, b, c, n, op};
        double r1;
        run_on(cpus, 1, k_bw, secs, &one, &r1);
        static struct bw parts[1024];
        static void *dummy;
        (void)dummy;
        double rates[1024], sum = 0;
        size_t per = n / ncpus;
        /* each thread its own slice; run_on passes one arg, so a small shim */
        pthread_t t[1024];
        struct job j[1024];
        pthread_barrier_t bar;
        pthread_barrier_init(&bar, 0, ncpus);
        for (int i = 0; i < ncpus; i++) {
            parts[i].a = a + i * per; parts[i].b = b + i * per; parts[i].c = c + i * per;
            parts[i].n = per; parts[i].op = op;
            j[i].cpu = cpus[i]; j[i].k = k_bw; j[i].secs = secs; j[i].arg = &parts[i]; j[i].bar = &bar;
            pthread_create(&t[i], 0, job_run, &j[i]);
        }
        for (int i = 0; i < ncpus; i++) { pthread_join(t[i], 0); rates[i] = j[i].rate; sum += rates[i]; }
        pthread_barrier_destroy(&bar);
        char key[64];
        snprintf(key, sizeof key, "membw.%s.one_thread", name);
        kv(key, "%.1f GB/s", r1 / 1e9);
        snprintf(key, sizeof key, "membw.%s.all_threads", name);
        kv(key, "%.1f GB/s (%d threads)", sum / 1e9, ncpus);
    }
    kv("membw.note", "best of repeated passes over arrays of %ld MiB, far larger than the caches; copy counts 16 bytes an element, triad 24", mib);
    free(a); free(b); free(c);
    return 0;
}

/* ---------------------------------------------------------------- jitter */

struct gaps { long g100, g1000; double max; };

static double k_gaps(double secs, void *arg)
{
    struct gaps *g = arg;
    double t0 = now(), last = t0, t;
    do {
        t = now();
        double d = t - last;
        last = t;
        if (d > 100e-6) g->g100++;
        if (d > 1e-3) g->g1000++;
        if (d > g->max) g->max = d;
    } while (t - t0 < secs);
    return 0;
}

static void steal(unsigned long long *st, unsigned long long *total)
{
    FILE *f = fopen("/proc/stat", "r");
    unsigned long long v[10] = {0};
    *st = *total = 0;
    if (!f) return;
    if (fscanf(f, "cpu %llu %llu %llu %llu %llu %llu %llu %llu", &v[0], &v[1], &v[2], &v[3], &v[4], &v[5], &v[6], &v[7]) == 8) {
        *st = v[7];
        for (int i = 0; i < 8; i++) *total += v[i];
    }
    fclose(f);
}

static int cmd_jitter(double secs)
{
    find_cpus();
    static struct gaps g[1024];
    pthread_t t[1024];
    struct job j[1024];
    pthread_barrier_t bar;
    unsigned long long s0, t0, s1, t1;
    steal(&s0, &t0);
    pthread_barrier_init(&bar, 0, ncpus);
    for (int i = 0; i < ncpus; i++) {
        memset(&g[i], 0, sizeof g[i]);
        j[i].cpu = cpus[i]; j[i].k = k_gaps; j[i].secs = secs; j[i].arg = &g[i]; j[i].bar = &bar;
        pthread_create(&t[i], 0, job_run, &j[i]);
    }
    for (int i = 0; i < ncpus; i++) pthread_join(t[i], 0);
    pthread_barrier_destroy(&bar);
    steal(&s1, &t1);
    long a = 0, b = 0;
    double mx = 0;
    for (int i = 0; i < ncpus; i++) { a += g[i].g100; b += g[i].g1000; if (g[i].max > mx) mx = g[i].max; }
    kv("jitter.pauses_over_100us", "%.1f a second per CPU", a / secs / ncpus);
    kv("jitter.pauses_over_1ms", "%.1f a second per CPU", b / secs / ncpus);
    kv("jitter.longest_pause", "%.1f ms", mx * 1e3);
    if (t1 > t0) kv("jitter.steal", "%.2f%% of CPU time, every CPU busy for %.0f s", 100.0 * (s1 - s0) / (t1 - t0), secs);
    return 0;
}

/* ---------------------------------------------------------------- disk */

struct rio { const char *path; long blocks; int write; double secs; double *lat; long cap; long n; };

static void *rio_run(void *p)
{
    struct rio *r = p;
    int fd = open(r->path, (r->write ? O_WRONLY : O_RDONLY) | O_DIRECT);
    if (fd < 0) fd = open(r->path, r->write ? O_WRONLY : O_RDONLY);
    void *buf;
    if (fd < 0 || posix_memalign(&buf, 4096, 4096)) return 0;
    memset(buf, 7, 4096);
    unsigned s = (unsigned)(uintptr_t)r;
    double t0 = now();
    while (now() - t0 < r->secs && r->n < r->cap) {
        off_t off = (off_t)(rand_r(&s) % r->blocks) * 4096;
        double a = now();
        ssize_t k = r->write ? pwrite(fd, buf, 4096, off) : pread(fd, buf, 4096, off);
        if (k != 4096) break;
        r->lat[r->n++] = now() - a;
    }
    close(fd);
    free(buf);
    return 0;
}

static void random_io(const char *path, long blocks, int write, int threads, double secs)
{
    static struct rio r[64];
    pthread_t t[64];
    long cap = 400000;
    double t0 = now();
    for (int i = 0; i < threads; i++) {
        r[i].path = path; r[i].blocks = blocks; r[i].write = write; r[i].secs = secs;
        r[i].lat = malloc(cap * sizeof(double)); r[i].cap = cap; r[i].n = 0;
        pthread_create(&t[i], 0, rio_run, &r[i]);
    }
    long n = 0;
    for (int i = 0; i < threads; i++) { pthread_join(t[i], 0); n += r[i].n; }
    double el = now() - t0;
    double *all = malloc((n ? n : 1) * sizeof(double));
    long m = 0;
    for (int i = 0; i < threads; i++) { memcpy(all + m, r[i].lat, r[i].n * sizeof(double)); m += r[i].n; free(r[i].lat); }
    char key[64];
    snprintf(key, sizeof key, "disk.random_4k_%s.%d_thread%s", write ? "write" : "read", threads, threads > 1 ? "s" : "");
    if (!n) { kv(key, "failed"); free(all); return; }
    qsort(all, n, sizeof all[0], cmp_double);
    kv(key, "%.0f IOPS, median %.0f us, p99 %.0f us, max %.1f ms", n / el, all[n / 2] * 1e6, all[n * 99 / 100] * 1e6, all[n - 1] * 1e3);
    free(all);
}

static int cmd_disk(const char *dir, long mib, double secs, long nfiles)
{
    char path[4096];
    snprintf(path, sizeof path, "%s/envcheck-disk.bin", dir);
    size_t bs = 1 << 20;
    void *buf;
    if (posix_memalign(&buf, 4096, bs)) return die("posix_memalign");
    memset(buf, 1, bs);
    int direct = 1;
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_DIRECT, 0600);
    if (fd < 0 && errno == EINVAL) { direct = 0; fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600); }
    if (fd < 0) return die(path);
    kv("disk.direct_io", "%s", direct ? "yes (O_DIRECT: the page cache is bypassed)" : "no (this filesystem refuses O_DIRECT; figures include the page cache)");
    double t0 = now();
    for (long i = 0; i < mib; i++) if (write(fd, buf, bs) != (ssize_t)bs) { close(fd); unlink(path); return die("write"); }
    fsync(fd);
    close(fd);
    kv("disk.sequential_write", "%.0f MB/s (%ld MiB, 1 MiB blocks, then fsync)", mib * bs / (now() - t0) / 1e6, mib);
    fd = open(path, O_RDONLY | (direct ? O_DIRECT : 0));
    t0 = now();
    while (read(fd, buf, bs) > 0) ;
    close(fd);
    kv("disk.sequential_read", "%.0f MB/s (just written)", mib * bs / (now() - t0) / 1e6);
    if (geteuid() == 0) {
        sync();
        int dc = open("/proc/sys/vm/drop_caches", O_WRONLY);
        if (dc >= 0 && write(dc, "3", 1) == 1) {
            close(dc);
            fd = open(path, O_RDONLY);
            t0 = now();
            while (read(fd, buf, bs) > 0) ;
            close(fd);
            kv("disk.sequential_read_cold", "%.0f MB/s (buffered, after dropping the page cache)", mib * bs / (now() - t0) / 1e6);
        } else if (dc >= 0) close(dc);
    }
    long blocks = mib * 256;
    int many = sysconf(_SC_NPROCESSORS_ONLN);
    if (many > 8) many = 8;
    if (many < 2) many = 2;
    random_io(path, blocks, 0, 1, secs);
    random_io(path, blocks, 0, many, secs);
    random_io(path, blocks, 1, 1, secs);
    random_io(path, blocks, 1, many, secs);
    unlink(path);
    /* 4 KiB appends, each made durable */
    fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    long n = 0;
    double mx = 0;
    t0 = now();
    while (now() - t0 < secs) {
        double a = now();
        if (write(fd, buf, 4096) != 4096 || fdatasync(fd)) break;
        double d = now() - a;
        if (d > mx) mx = d;
        n++;
    }
    double el = now() - t0;
    close(fd);
    unlink(path);
    if (n) kv("disk.fdatasync_4k", "%.0f a second, mean %.0f us, max %.1f ms", n / el, el / n * 1e6, mx * 1e3);
    /* small files: create, stat, read, delete */
    char sub[4096], f[4200];
    snprintf(sub, sizeof sub, "%s/envcheck-files", dir);
    mkdir(sub, 0700);
    double tc = now();
    for (long i = 0; i < nfiles; i++) {
        snprintf(f, sizeof f, "%s/f%ld", sub, i);
        int h = open(f, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (h < 0 || write(h, buf, 1024) != 1024) return die("small file");
        close(h);
    }
    tc = now() - tc;
    double ts = now();
    struct stat st;
    for (long i = 0; i < nfiles; i++) { snprintf(f, sizeof f, "%s/f%ld", sub, i); stat(f, &st); }
    ts = now() - ts;
    double tr = now();
    for (long i = 0; i < nfiles; i++) {
        snprintf(f, sizeof f, "%s/f%ld", sub, i);
        int h = open(f, O_RDONLY);
        if (h >= 0) { if (read(h, buf, 1024) < 0) break; close(h); }
    }
    tr = now() - tr;
    double tu = now();
    for (long i = 0; i < nfiles; i++) { snprintf(f, sizeof f, "%s/f%ld", sub, i); unlink(f); }
    tu = now() - tu;
    rmdir(sub);
    kv("disk.small_files", "%ld files of 1 KiB: create %.0f, stat %.0f, read %.0f, delete %.0f a second",
       nfiles, nfiles / tc, nfiles / ts, nfiles / tr, nfiles / tu);
    free(buf);
    return 0;
}

/* ---------------------------------------------------------------- commit */

/* Allocate and touch stepmib at a time up to capmib, writing the total to
   file after each step, so that it is known after the kernel kills this
   process. It asks to be the first process killed. */
static int cmd_commit(long stepmib, long capmib, const char *file)
{
    FILE *adj = fopen("/proc/self/oom_score_adj", "w");
    if (adj) { fputs("1000", adj); fclose(adj); }
    size_t step = (size_t)stepmib << 20;
    for (long total = stepmib; total <= capmib; total += stepmib) {
        char *p = malloc(step);
        if (!p) { kv("commit.malloc_failed_at", "%ld MiB", total); return 0; }
        memset(p, 1, step);
        FILE *f = fopen(file, "w");
        if (f) { fprintf(f, "%ld\n", total); fflush(f); fsync(fileno(f)); fclose(f); }
    }
    kv("commit.reached_cap", "%ld MiB", capmib);
    return 0;
}

/* ---------------------------------------------------------------- main */

static int usage(void)
{
    fprintf(stderr, "usage: envcheck-probe COMMAND ... (see the head of scripts/envcheck.c)\n");
    return 2;
}

#if !defined(__x86_64__)
static int unsupported(const char *what)
{
    kv("unsupported", "%s needs x86-64; this is another architecture", what);
    return 3;
}
#endif

int main(int argc, char **argv)
{
    setvbuf(stdout, 0, _IOLBF, 0);
    if (argc < 2) return usage();
    const char *c = argv[1];
#define ARG(i) (argc > (i) ? argv[i] : "")
#if defined(__x86_64__)
    if (!strcmp(c, "cpuid")) return cmd_cpuid();
    if (!strcmp(c, "isa")) return cmd_isa();
    if (!strcmp(c, "clock")) return cmd_clock(atof(ARG(2)));
    if (!strcmp(c, "fma")) return cmd_fma(atof(ARG(2)));
    if (!strcmp(c, "pairs")) return cmd_pairs(atof(ARG(2)), ARG(3));
    if (!strcmp(c, "pingpong")) return cmd_pingpong(atoi(ARG(2)), ARG(3));
#else
    if (!strcmp(c, "cpuid") || !strcmp(c, "isa") || !strcmp(c, "clock") || !strcmp(c, "fma")
        || !strcmp(c, "pairs") || !strcmp(c, "pingpong")) return unsupported(c);
#endif
    if (!strcmp(c, "cachecurve")) return cmd_cachecurve(atol(ARG(2)));
    if (!strcmp(c, "cachesizes")) return cmd_cachesizes(ARG(2), atol(ARG(3)));
    if (!strcmp(c, "membw")) return cmd_membw(atol(ARG(2)), atof(ARG(3)));
    if (!strcmp(c, "jitter")) return cmd_jitter(atof(ARG(2)));
    if (!strcmp(c, "disk")) return cmd_disk(ARG(2), atol(ARG(3)), atof(ARG(4)), atol(ARG(5)));
    if (!strcmp(c, "commit")) return cmd_commit(atol(ARG(2)), atol(ARG(3)), ARG(4));
    return usage();
}
