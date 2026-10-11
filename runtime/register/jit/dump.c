/* --jit-dump=DIR (docs/plans/performance.md, M1): the code of every
   function the JIT compiles, as it is placed, with what each part of it
   is for -- the bytecode instruction it does and its role (masm.h,
   MsRole) -- so that the code can be read, and counted by role under
   callgrind (scripts/jit-dump.py), and perf's jitdump of the same code,
   so that `perf inject --jit` and `perf annotate` see it.

   In DIR, per function compiled, in the order compiled (NNNNN from 0):
     NNNNN.bin   the bytes, as placed at the address index.tsv gives
     NNNNN.lst   its parts: a line per offset where the bytecode
                 instruction or the role changes, "OFFSET PC ROLE TEXT"
                 (tab-separated; TEXT the instruction, its operands, and
                 where it came from), so that every machine instruction is
                 of the last part at or before its offset
     index.tsv   a line: NNNNN, the function's number, the tier, the
                 address (hex), the size, its registers, its arity, its
                 registers' representations (a digit or letter each, the
                 numbers of runtime/vm.h's enum Rep), the homes (register
                 = machine register, or -), and the name
     jit-PID.dump  perf's jitdump (tools/perf/Documentation/jitdump-specification.txt
                 in Linux's sources): a record of each function's code,
                 and of its parts as lines of NNNNN.lst, which
                 `perf record -k mono` finds by the first page of the file
                 mapped executable (sys_code_marker) and `perf inject --jit`
                 turns into objects that `perf annotate` reads, with the
                 parts as their source lines. */
#include "compile.h"
#include "sys/sys.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct JitDump {
    char dir[4096];     /* where the files go; absolute where it can be, since perf names the listings by it */
    FILE *index;
    FILE *perf;         /* perf's jitdump; NULL where it could not be made */
    uint32_t seq;
    uint32_t pid;
} JitDump;

/* perf's jitdump: its header and records, little-endian on the machines
   the JIT is for (jitdump-specification.txt) */
enum { JITDUMP_MAGIC = 0x4A695444, JITDUMP_VERSION = 1, JIT_CODE_LOAD = 0, JIT_CODE_DEBUG_INFO = 2 };
#if JIT_TARGET == 2
enum { DUMP_ELF_MACH = 183 };   /* EM_AARCH64 */
#else
enum { DUMP_ELF_MACH = 62 };    /* EM_X86_64 */
#endif
static void put32(FILE *o, uint32_t v) { fwrite(&v, 4, 1, o); }
static void put64(FILE *o, uint64_t v) { fwrite(&v, 8, 1, o); }

static JitDump *dump_open(JitProgram *jit, const char *dir) {
    JitDump *d = calloc(1, sizeof *d);
    if (!d) return NULL;
    const char *cwd = dir[0] == '/' ? NULL : sys_getcwd();
    snprintf(d->dir, sizeof d->dir, "%s%s%s", cwd ? cwd : "", cwd ? "/" : "", dir);
    char name[4200];
    snprintf(name, sizeof name, "%s/index.tsv", d->dir);
    d->index = fopen(name, "w");
    if (!d->index) {
        fprintf(stderr, "runevm: --jit-dump: cannot write %s\n", name);
        free(d);
        return NULL;
    }
    int64_t pid = sys_getpid();
    d->pid = (uint32_t)pid;
    snprintf(name, sizeof name, "%s/jit-%lld.dump", d->dir, (long long)pid);
    d->perf = fopen(name, "wb");
    if (d->perf) {
        put32(d->perf, JITDUMP_MAGIC); put32(d->perf, JITDUMP_VERSION);
        put32(d->perf, 40);   /* the header's size */
        put32(d->perf, DUMP_ELF_MACH); put32(d->perf, 0);
        put32(d->perf, (uint32_t)pid);
        put64(d->perf, (uint64_t)sys_clock_ns());
        put64(d->perf, 0);
        fflush(d->perf);
        sys_code_marker(name);   /* perf's to see; nothing lost where it cannot */
    }
    jit->dump = d;
    return d;
}

/* a register's machine register, by the target's name */
static void reg_name(char *out, size_t n, const Home *h) {
#if JIT_TARGET == 2
    snprintf(out, n, "%s%u", h->kind == HOME_XMM ? "v" : "x", (unsigned)h->reg);
#else
    static const char *const gpr[16] = { "rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
                                         "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15" };
    if (h->kind == HOME_XMM) snprintf(out, n, "xmm%u", (unsigned)h->reg);
    else snprintf(out, n, "%s", gpr[h->reg & 15]);
#endif
}

/* the instruction at pc as text: its name, its operands (a function's and
   a primitive's by name), and where it came from */
static void instruction_text(const VM *vm, uint32_t pc, char *out, size_t n) {
    const Program *p = &vm->prog;
    size_t k = 0;
    out[0] = 0;
    if (pc >= p->code_len) { snprintf(out, n, "?"); return; }
    const uint8_t *at = p->code + pc;
    uint8_t op = at[0];
    if (op >= ROP__COUNT) { snprintf(out, n, "?"); return; }
    uint32_t len = rop_length(at);
    k += (size_t)snprintf(out + k, n - k, "%s", rop_names[op]);
    for (uint32_t i = 0; 1 + 4 * i < len && k < n; i++) {
        int32_t v = read_i32(at + 1 + 4 * i);
        int kind = (int)i < rop_nfixed[op] ? rop_kinds[op][i] : RK_REGISTER;
        if (kind == RK_FUNCTION && v >= 0 && (uint32_t)v < p->nfuncs) k += (size_t)snprintf(out + k, n - k, " %s", p->funcs[v].name);
        else if (kind == RK_PRIMITIVE && v >= 0 && v < PRIM__COUNT) k += (size_t)snprintf(out + k, n - k, " %s", prim_names[v]);
        else k += (size_t)snprintf(out + k, n - k, " %d", v);
    }
    const LineEntry *e = line_at(p, pc);
    if (e && e->file < p->nfiles && k < n) snprintf(out + k, n - k, " ; %s:%u:%u", p->files[e->file], e->line, e->col);
}

/* The parts of the code (NNNNN.lst): where the instruction or the role
   changes, from the marks in the order they were made (offsets that never
   go back), several at one offset making one part. Returns how many. */
typedef struct Part { uint32_t off, pc; int role; } Part;
static uint32_t parts_of(const Jit *j, Part *out) {
    const MsMarks *mk = j->m.marks;
    uint32_t n = 0, pc = j->from;
    int role = MR_BODY;
    for (size_t i = 0; i < mk->n; ) {
        uint32_t off = mk->at[i].off;
        for (; i < mk->n && mk->at[i].off == off; i++) {
            if (mk->at[i].role < 0) pc = mk->at[i].pc;
            else role = mk->at[i].role;
        }
        if (off >= j->m.a.n) break;   /* nothing after it */
        if (n && out[n - 1].pc == pc && out[n - 1].role == role) continue;
        out[n].off = off; out[n].pc = pc; out[n].role = role;
        n++;
    }
    return n;
}

void jit_dump_function(Jit *j, const uint8_t *at) {
    VM *vm = j->vm;
    JitProgram *jit = j->jit;
    JitDump *d = jit->dump ? jit->dump : dump_open(jit, vm->jit.dump);
    if (!d || !j->m.marks) return;
    const Function *fn = &vm->prog.funcs[j->f];
    uint32_t k = d->seq++;
    size_t size = j->m.a.n;
    char name[4200], text[1024];
    snprintf(name, sizeof name, "%s/%05u.bin", d->dir, k);
    FILE *o = fopen(name, "wb");
    if (o) { fwrite(at, 1, size, o); fclose(o); }

    Part *parts = malloc((j->m.marks->n + 1) * sizeof *parts);
    uint32_t nparts = parts ? parts_of(j, parts) : 0;
    char lst[4200];
    snprintf(lst, sizeof lst, "%s/%05u.lst", d->dir, k);
    o = fopen(lst, "w");
    if (o) {
        for (uint32_t i = 0; i < nparts; i++) {
            instruction_text(vm, parts[i].pc, text, sizeof text);
            fprintf(o, "%u\t%u\t%s\t%s\n", parts[i].off, parts[i].pc, ms_role_names[parts[i].role], text);
        }
        fclose(o);
    }

    fprintf(d->index, "%05u\t%u\t%d\t%llx\t%u\t%u\t%u\t", k, j->f, j->tier, (unsigned long long)(uintptr_t)at,
            (unsigned)size, fn->nlocals, fn->has_meta ? fn->arity : 0);
    for (uint32_t r = 0; r < fn->nlocals; r++)
        fputc(fn->has_meta && fn->reps && fn->reps[r] < 36 ? "0123456789abcdefghijklmnopqrstuvwxyz"[fn->reps[r]] : '?', d->index);
    if (!fn->nlocals) fputc('-', d->index);
    fputc('\t', d->index);
    int any = 0;
    for (uint32_t r = 0; j->homes && r < fn->nlocals; r++)
        if (j->homes[r].kind != HOME_SLOT) {
            char reg[16];
            reg_name(reg, sizeof reg, &j->homes[r]);
            fprintf(d->index, "%s%u=%s", any ? "," : "", r, reg);
            any = 1;
        }
    if (!any) fputc('-', d->index);
    fprintf(d->index, "\t%s\n", fn->name);
    fflush(d->index);

    /* perf's records: the parts as the lines of the listing (its debug
       information, which must come first), then the code */
    if (d->perf) {
        FILE *p = d->perf;
        char fname[256];
        snprintf(fname, sizeof fname, "jit%d:%s", j->tier, fn->name);
        if (nparts) {
            /* the file named in full each time, as perf's own agent does
               (the specification's short form for the same file is not
               what perf's reader takes); padded to 8 bytes */
            size_t lstlen = strlen(lst) + 1;
            uint64_t total = 16 + 8 + 8 + (uint64_t)nparts * (8 + 4 + 4 + lstlen);
            uint32_t pad = (uint32_t)((8 - total % 8) % 8);
            put32(p, JIT_CODE_DEBUG_INFO); put32(p, (uint32_t)(total + pad)); put64(p, (uint64_t)sys_clock_ns());
            put64(p, (uint64_t)(uintptr_t)at);
            put64(p, nparts);
            for (uint32_t i = 0; i < nparts; i++) {
                put64(p, (uint64_t)(uintptr_t)(at + parts[i].off));
                put32(p, i + 1);   /* the line: the part's */
                put32(p, 0);
                fwrite(lst, 1, lstlen, p);
            }
            for (uint32_t i = 0; i < pad; i++) fputc(0, p);
        }
        size_t namelen = strlen(fname) + 1;
        uint64_t total = 16 + 4 + 4 + 8 + 8 + 8 + 8 + namelen + size;
        put32(p, JIT_CODE_LOAD); put32(p, (uint32_t)total); put64(p, (uint64_t)sys_clock_ns());
        put32(p, d->pid); put32(p, d->pid);   /* the thread: the VM has one */
        put64(p, (uint64_t)(uintptr_t)at); put64(p, (uint64_t)(uintptr_t)at);
        put64(p, size); put64(p, k);
        fwrite(fname, 1, namelen, p);
        fwrite(at, 1, size, p);
        fflush(p);
    }
    free(parts);
}
