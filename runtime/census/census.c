/* runtime/census/census.c -- the census VM (docs/census.md): every allocation,
   the tags of every field at the end of the allocating instruction, every
   store into an existing object, the lifetimes by forced collections, the
   values primitives give and calls carry, and the tables of census.txt.
   Built into bin/runevm-census by `make vm-census` (-DRUNE_CENSUS); the
   hooks are runtime/census/census.h's. Throwaway: an experiment's tool, not part of
   the VM. */
#include "vm.h"
#include "register/regvm.h"
#include "layouts.h"
#include "sys/sys.h"
#include <inttypes.h>
#include <errno.h>

int census_on;
uint64_t census_every;
uint64_t census_clock, census_last_sample_clock;
uint32_t census_site = UINT32_MAX, census_func = UINT32_MAX;
int census_prim = -1;
int census_runtime;
Obj *census_pending;
uint64_t *census_pcs;
uint64_t census_next_id;

uint32_t census_sample_no;

static VM *the_vm;
static int write_fields;
static int summary;                 /* --census-summary: no trace files, no per-object arrays */
static char dir[4096];
static int final_collection;        /* the one at exit: survivors are alive at exit */
static uint64_t live_objs_pass;     /* survivors of the pass of collect_into running */
static uint64_t samples_written;
/* the objects of the id word: its low CENSUS_ID_BITS the id, above them the birth sample */
#define OBJ_ID(o) ((o)->id & CENSUS_ID_MASK)
#define OBJ_SAMPLE(o) ((uint32_t)((o)->id >> CENSUS_ID_BITS))

/* ---------------------------------------------------------------- writers */

typedef struct Out { FILE *f; unsigned char *buf; size_t n, cap; } Out;
static Out out_alloc, out_fields, out_stores, out_samples;

static void die(const char *what) {
    fprintf(stderr, "runevm-census: %s: %s\n", what, strerror(errno));
    exit(2);
}

static void out_open(Out *o, const char *name) {
    char path[4200];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    o->f = fopen(path, "wb");
    if (!o->f) die(path);
    setvbuf(o->f, NULL, _IONBF, 0);    /* the buffer is ours: a fork's child drops it */
    o->cap = (size_t)4 << 20;
    o->buf = malloc(o->cap);
    if (!o->buf) die("out of memory");
    o->n = 0;
}
static void out_drain(Out *o) {
    if (o->n && fwrite(o->buf, 1, o->n, o->f) != o->n) die("write");
    o->n = 0;
}
static inline void out_put(Out *o, const void *p, size_t n) {
    if (o->n + n > o->cap) out_drain(o);
    if (n > o->cap) { if (fwrite(p, 1, n, o->f) != n) die("write"); return; }
    memcpy(o->buf + o->n, p, n);
    o->n += n;
}
static void out_close(Out *o) {
    if (!o->f) return;
    out_drain(o);
    fclose(o->f);
    o->f = NULL;
    free(o->buf);
    o->buf = NULL;
}
static inline void put_u8(unsigned char *p, uint8_t v) { p[0] = v; }
static inline void put_u16(unsigned char *p, uint16_t v) { p[0] = (unsigned char)v; p[1] = (unsigned char)(v >> 8); }
static inline void put_u32(unsigned char *p, uint32_t v) { for (int i = 0; i < 4; i++) p[i] = (unsigned char)(v >> (8 * i)); }
static inline void put_u64(unsigned char *p, uint64_t v) { for (int i = 0; i < 8; i++) p[i] = (unsigned char)(v >> (8 * i)); }

/* ---------------------------------------------------------------- per-id tables */

/* (full mode only: summary mode keeps nothing per object; the birth
   sample in the id word serves the ages there) */
static uint32_t *death;     /* the last sample survived (docs/census.md, death.bin) */
static uint32_t *birth8;    /* the allocation clock at birth, in 8-byte units (every L0 size is a multiple of 8; a trace of at most 32 GB) */
static uint8_t *homog;      /* arrays and vectors: bits 0-2 the elements' tag, 3-5 their largest bits class, bit 7 mixed */
static uint64_t ids_cap;
static uint64_t ids_hint;   /* --census-ids: the objects expected, so that the arrays are allocated once */

static void grow_ids(uint64_t id) {
    uint64_t cap = ids_cap ? ids_cap : ids_hint ? ids_hint + 2 : (1u << 20);
    while (cap <= id) cap *= 2;
    death = realloc(death, cap * sizeof *death);
    birth8 = realloc(birth8, cap * sizeof *birth8);
    homog = realloc(homog, cap);
    if (!death || !birth8 || !homog) die("out of memory (ids)");
    ids_cap = cap;
}

/* the samples: the clock at each collection (sample_clock[0] = 0), the
   live sizes; the survivors by age in samples, per pass and in all */
static uint64_t *sample_clock; static size_t sample_cap;
static uint64_t last_live_bytes, last_live_objs, sum_live_bytes, max_live_bytes;
#define NAGEB 128        /* exact ages 1..127, bucket 128 = ages >= 128 */
static uint64_t surv_bytes[NAGEB + 1], surv_objs[NAGEB + 1], pass_surv_bytes[NAGEB + 1], pass_surv_objs[NAGEB + 1];

/* the arrays and vectors, for the table by element tag and homogeneity */
typedef struct ArrEnt { uint32_t id_lo, id_hi_kind_site, len; } ArrEnt;
static uint64_t *arr_ids; static uint8_t *arr_kind, *arr_site; static uint32_t *arr_len;
static size_t arr_n, arr_cap;
static void arr_push(uint64_t id, uint8_t kind, uint8_t site_kind, uint32_t len) {
    if (arr_n == arr_cap) {
        arr_cap = arr_cap ? arr_cap * 2 : 4096;
        arr_ids = realloc(arr_ids, arr_cap * sizeof *arr_ids);
        arr_kind = realloc(arr_kind, arr_cap);
        arr_site = realloc(arr_site, arr_cap);
        arr_len = realloc(arr_len, arr_cap * sizeof *arr_len);
        if (!arr_ids || !arr_kind || !arr_site || !arr_len) die("out of memory (arrays)");
    }
    arr_ids[arr_n] = id; arr_kind[arr_n] = kind; arr_site[arr_n] = site_kind; arr_len[arr_n] = len;
    arr_n++;
}

/* ---------------------------------------------------------------- hash tables */

typedef struct HEnt { uint64_t key; uint64_t objects, bytes, sum; uint32_t aux; } HEnt;
typedef struct HTab { HEnt *e; size_t cap, n; } HTab;
static HTab shapes, sites;

static inline uint64_t hmix(uint64_t k) { k ^= k >> 33; k *= 0xff51afd7ed558ccdULL; k ^= k >> 33; k *= 0xc4ceb9fe1a85ec53ULL; k ^= k >> 33; return k; }
static void htab_grow(HTab *t);
static HEnt *htab_get(HTab *t, uint64_t key) {
    if (!t->e) { t->cap = 1 << 16; t->e = calloc(t->cap, sizeof(HEnt)); if (!t->e) die("out of memory (table)"); }
    if (t->n * 2 >= t->cap) htab_grow(t);
    size_t i = hmix(key) & (t->cap - 1);
    for (;;) {
        HEnt *e = &t->e[i];
        if (e->objects == 0) { e->key = key; t->n++; return e; }
        if (e->key == key) return e;
        i = (i + 1) & (t->cap - 1);
    }
}
static void htab_grow(HTab *t) {
    HTab n = { calloc(t->cap * 2, sizeof(HEnt)), t->cap * 2, 0 };
    if (!n.e) die("out of memory (table)");
    for (size_t i = 0; i < t->cap; i++) if (t->e[i].objects) {
        HEnt *e = htab_get(&n, t->e[i].key);
        *e = t->e[i];
    }
    free(t->e);
    *t = n;
}

/* ---------------------------------------------------------------- histograms */

#define NTAG 7
#define NBITS 65
#define NREP 10          /* REP_ANY..REP_UNIT (0..8), 9 = unknown (15) */
#define NBC 8
#define NAGE 5           /* <256K, <1M, <4M, <32M, >=32M */
#define NOP 5            /* CALL, TAILCALL, CALLK, TAILCALLK, RET */

static uint64_t kind_objs[16], kind_bytes[16];   /* by kind: a kind fits four bits (value.h) */
static uint64_t func_objs_cap; static uint64_t *func_objs, *func_bytes;   /* nfuncs + 1 (the runtime last) */
static uint64_t prim_hist[PRIM__COUNT][NTAG][NBITS];
static uint64_t call_hist[NOP][NTAG][NBITS][NREP];
static uint64_t field_total, field_tag[NTAG], field_bc[NTAG][NBC], field_rep[NTAG][NREP], field_ptr_kind[16];
static uint64_t field_real_zero;
static uint64_t store_hist[3][NTAG][NAGE][NAGE + 1];
static uint64_t store_total, store_old_young, store_ptr_new, store_ptr_old, store_field_clamped;
static uint64_t store_real, store_real_enc, store_real_zero;
static uint64_t prim_real, prim_real_enc, prim_real_zero;
static uint64_t call_real, call_real_enc, call_real_zero;
static uint64_t field_real, field_real_enc;
static uint64_t alloc_fields_bytes;       /* bytes of fields.bin */
/* tuples made by the TUPLE instruction, by homogeneity and element tag */
static uint64_t tuple_homog_objs[2][NTAG], tuple_homog_bytes[2][NTAG];
/* arrays and vectors at allocation: [ARRAY/TUPLE][site kind][homogeneous][tag][bc] */
static uint64_t arr_alloc_objs[2][3][2][NTAG][NBC], arr_alloc_bytes[2][3][2][NTAG][NBC];

/* the first-order size table */
typedef struct Var { enum Layout L; unsigned v; const char *name; } Var;
static const Var variants[] = {
    { L0, 0, "L0" },
    { L1, 0, "L1" },
    { L1, LV_HDR4, "L1+hdr4" },
    { L1, LV_ALIGN16, "L1+align16" },
    { L1, LV_PAIRS, "L1+pairs" },
    { L1, LV_HDR4 | LV_PAIRS, "L1+hdr4+pairs" },
    { L1, LV_REALIMM, "L1+realimm" },
    { L1, LV_COMPACT, "L1+compact" },
    { L1, LV_HDR4 | LV_PAIRS | LV_REALIMM | LV_COMPACT, "L1+hdr4+pairs+realimm+compact" },
    { L2, 0, "L2" },
    { L2, LV_HDR4, "L2+hdr4" },
    { L2, LV_HDR4 | LV_PAIRS | LV_COMPACT, "L2+hdr4+pairs+compact" },
    { L3, 0, "L3" },
    { L3, LV_NAN51, "L3+nan51" },
    { L3, LV_HDR4, "L3+hdr4" },
    { L3, LV_HDR4 | LV_PAIRS | LV_COMPACT, "L3+hdr4+pairs+compact" },
    { L3, LV_HDR4 | LV_PAIRS | LV_COMPACT | LV_NAN51, "L3+hdr4+pairs+compact+nan51" },
    { L4, 0, "L4-mono" },
    { L4, LV_L4UNIFORM, "L4-uniform" },
    { L4, LV_HDR4, "L4-mono+hdr4" },
    { L4, LV_HDR4 | LV_PAIRS | LV_COMPACT, "L4-mono+hdr4+pairs+compact" },
    { L4, LV_HDR4 | LV_PAIRS | LV_COMPACT | LV_L4UNIFORM, "L4-uniform+hdr4+pairs+compact" },
};
#define NVAR ((int)(sizeof variants / sizeof variants[0]))
static uint64_t var_obj_bytes[NVAR], var_boxes[NVAR], var_box_bytes[NVAR], var_unrep[NVAR], var_compact_objs[NVAR];

/* ---------------------------------------------------------------- values */

static inline unsigned clz64(uint64_t x) { return x ? (unsigned)__builtin_clzll(x) : 64; }

/* docs/census.md's bits: INT/CHAR/CON0 the two's-complement bits (1..64), WORD
   64 - clz (0..64), REAL 0 where value-encodable else 7, others 0 */
static inline unsigned bits_of(Value v) {
    switch (val_tag(v)) {
    case T_INT: case T_CHAR: case T_CON0: {
        uint64_t x = (uint64_t)(val_imm(v) ^ (val_imm(v) >> 63));
        return x ? 65 - clz64(x) : 1;
    }
    case T_WORD: return 64 - clz64(val_word(v));
    case T_REAL: {
        uint64_t b = val_bits(v);
        unsigned e = (unsigned)((b >> 52) & 0x7ff);
        return (e >= 0x3ff - 0x1ff && e < 0x3ff + 0x200) ? 0 : 7;
    }
    default: return 0;
    }
}
static inline unsigned bc_of(uint8_t tag, unsigned b) {
    if (tag == T_REAL) return b;
    if (tag == T_UNIT || tag == T_PTR) return 0;
    return b <= 8 ? 0 : b <= 31 ? 1 : b <= 48 ? 2 : b <= 51 ? 3 : b <= 62 ? 4 : b <= 63 ? 5 : 6;
}
static inline int is_zero_real(Value v) { return val_is(v, T_REAL) && val_real(v) == 0.0; }
static inline unsigned rep_idx(int rep) { return rep >= 0 && rep < REP__COUNT ? (unsigned)rep : NREP - 1; }
static inline unsigned age_class(uint64_t age) {
    return age < (256u << 10) ? 0 : age < (1u << 20) ? 1 : age < (4u << 20) ? 2 : age < (32u << 20) ? 3 : 4;
}
/* the age in bytes of an object born in sample k's window (sample_clock[k],
   sample_clock[k+1]], taken as born at the window's middle (the open
   window's: between its start and now); summary mode's stand-in for birth16 */
static inline uint64_t est_age(uint32_t k) {
    uint64_t lo = k < sample_cap ? sample_clock[k] : census_clock;
    uint64_t hi = k < census_sample_no && k + 1 < sample_cap ? sample_clock[k + 1] : census_clock;
    return census_clock - (lo + hi) / 2;
}
static const char *const tag_names[NTAG] = { "UNIT", "INT", "WORD", "REAL", "CHAR", "CON0", "PTR" };
static const char *const kind_names[16] = { "?", "TUPLE", "CON", "CLOSURE", "STRING", "REF", "ARRAY", "EXN", "EXNCON",
                                            "FORWARD", "REAL", "BOX", "BYTES", "REALS", "THUNK", "IND" };
static const char *const rep_names[NREP] = { "ANY", "INT", "WORD", "REAL", "CHAR", "CON0", "PTR", "CON", "UNIT", "unknown" };
static const char *const callop_names[NOP] = { "CALL", "TAILCALL", "CALLK", "TAILCALLK", "RET" };
static const char *const age_names[NAGE + 1] = { "<256K", "<1M", "<4M", "<32M", ">=32M", "none" };
static const char *const site_names[3] = { "SETENV", "ref_set", "array_update" };

/* ---------------------------------------------------------------- init */

void census_init(VM *vm, const char *d, uint64_t every, int fields, int summ, uint64_t hint) {
    the_vm = vm;
    snprintf(dir, sizeof dir, "%s", d);
    sys_mkdir(dir);   /* made if missing; an existing one is reused */
    summary = summ;
    write_fields = fields && !summary;
    ids_hint = hint;
    census_every = every;
    if (!summary) {
        out_open(&out_alloc, "alloc.bin");
        if (write_fields) out_open(&out_fields, "fields.bin");
        out_open(&out_stores, "stores.bin");
        out_open(&out_samples, "samples.bin");
        unsigned char zero[16] = { 0 };
        out_put(&out_alloc, zero, 16);      /* id 0: none */
        grow_ids(0);
        death[0] = 0; birth8[0] = 0; homog[0] = 0;
    }
    sample_cap = 1 << 16;
    sample_clock = calloc(sample_cap, sizeof *sample_clock);
    if (!sample_clock) die("out of memory (samples)");
    census_on = 1;
}

/* the program is loaded after census_init: the pc counts and the function table wait for it */
static void ensure_program(void) {
    if (!census_pcs && the_vm->prog.code_len) {
        census_pcs = calloc(the_vm->prog.code_len + 1, sizeof(uint64_t));
        if (!census_pcs) die("out of memory (pcs)");
    }
    if (!func_objs && the_vm->prog.nfuncs) {
        func_objs_cap = the_vm->prog.nfuncs + 1;
        func_objs = calloc(func_objs_cap, sizeof(uint64_t));
        func_bytes = calloc(func_objs_cap, sizeof(uint64_t));
        if (!func_objs || !func_bytes) die("out of memory (funcs)");
    }
}

/* ---------------------------------------------------------------- allocation */

static uint32_t pend_site, pend_func;
static uint8_t pend_site_kind;

void census_alloc(VM *vm, Obj *o, size_t size) {
    (void)vm;
    uint64_t id = OBJ_ID(o);
    if (census_next_id > CENSUS_ID_MASK) { fprintf(stderr, "runevm-census: more than 2^%d objects\n", CENSUS_ID_BITS); exit(2); }
    if (!summary && id >= ids_cap) grow_ids(id);
    ensure_program();
    uint8_t site_kind; uint32_t site, func;
    if (census_runtime || census_site == UINT32_MAX) { site_kind = 2; site = UINT32_MAX; func = UINT32_MAX; }
    else { site_kind = census_prim >= 0 ? 1 : 0; site = census_site; func = census_func; }
    size_t l0 = l0_obj_size(obj_kind(o), obj_len(o));
    if (l0 != size - 8) { fprintf(stderr, "runevm-census: size %zu of kind %u len %u is not l0 %zu + 8\n", size, obj_kind(o), obj_len(o), l0); exit(2); }
    if (!summary) {
        unsigned char rec[16];
        put_u8(rec, obj_kind(o)); put_u8(rec + 1, site_kind); put_u16(rec + 2, obj_contag(o)); put_u32(rec + 4, obj_len(o));
        put_u32(rec + 8, site); put_u32(rec + 12, func);
        out_put(&out_alloc, rec, 16);
        if ((census_clock >> 3) > UINT32_MAX) { fprintf(stderr, "runevm-census: the trace passes 32 GB: birth8 overflows (use --census-summary)\n"); exit(2); }
        birth8[id] = (uint32_t)(census_clock >> 3);
        death[id] = 0;
        homog[id] = 0;
    }
    census_clock += l0;
    kind_objs[obj_kind(o)]++; kind_bytes[obj_kind(o)] += l0;
    HEnt *e = htab_get(&shapes, ((uint64_t)obj_kind(o) << 48) | ((uint64_t)obj_contag(o) << 32) | obj_len(o));
    e->objects++; e->bytes += l0;
    e = htab_get(&sites, ((uint64_t)site << 8) | ((uint64_t)obj_kind(o)) | ((uint64_t)site_kind << 4));
    e->objects++; e->bytes += l0; e->sum += obj_len(o); e->aux = func;
    if (func_objs) {
        uint64_t fi = func == UINT32_MAX ? func_objs_cap - 1 : (func < func_objs_cap - 1 ? func : func_objs_cap - 1);
        func_objs[fi]++; func_bytes[fi] += l0;
    }
    if (!summary && (obj_kind(o) == K_ARRAY || (obj_kind(o) == K_TUPLE && site_kind == 1))) arr_push(id, obj_kind(o), site_kind, obj_len(o));
    census_pending = o;
    pend_site = site; pend_func = func; pend_site_kind = site_kind;
}

/* the source register of each field of the pending object, from the
   instruction that made it, into reps[]: 15 where there is none */
static void source_reps(Obj *o, uint8_t *reps, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) reps[i] = 15;
    if (pend_site_kind != 0 || pend_site == UINT32_MAX || pend_site >= the_vm->prog.code_len) return;
    const Program *p = &the_vm->prog;
    const uint8_t *code = p->code;
    uint32_t at = pend_site;
    const Function *fn = pend_func < p->nfuncs ? &p->funcs[pend_func] : NULL;
#define REPOF(r) ((fn && fn->has_meta && (uint32_t)(r) < fn->nlocals) ? fn->reps[(r)] : 15)
    switch (code[at]) {
    case ROP_TUPLE: {
        uint32_t n = (uint32_t)read_i32(code + at + 5);
        if (n != len) return;
        for (uint32_t i = 0; i < n; i++) reps[i] = REPOF(read_i32(code + at + 9 + 4 * i));
        break;
    }
    case ROP_CLOSURE: {
        uint32_t n = (uint32_t)read_i32(code + at + 9);
        if (n + 1 != len) return;
        reps[0] = REP_INT;
        for (uint32_t i = 0; i < n; i++) reps[i + 1] = REPOF(read_i32(code + at + 13 + 4 * i));
        break;
    }
    case ROP_CON:
        if (len != 1) return;
        reps[0] = REPOF(read_i32(code + at + 9));
        break;
    case ROP_CONN: {
        uint32_t n = (uint32_t)read_i32(code + at + 9);
        if (n != len) return;
        for (uint32_t i = 0; i < n; i++) reps[i] = REPOF(read_i32(code + at + 13 + 4 * i));
        break;
    }
    case ROP_NEWEXN:
        if (len == 1) reps[0] = REP_PTR;
        break;
    case ROP_MKEXN:
        if (len != 2) return;
        reps[0] = REPOF(read_i32(code + at + 5));
        reps[1] = REPOF(read_i32(code + at + 9));
        break;
    default: break;
    }
#undef REPOF
    (void)o;
}

/* a cell of the per-object tally of fields: tag, bits class, polymorphic (mono rule) */
typedef struct Cell { uint8_t tag, bc, poly; uint32_t n; } Cell;

void census_flush(void) {
    Obj *o = census_pending;
    census_pending = NULL;
    if (!o || !census_on) return;
    uint32_t len = obj_len(o);
    uint8_t kind = obj_kind(o);
    size_t l0 = l0_obj_size(kind, len);
    static uint8_t *reps; static size_t reps_cap;
    static Cell *cells;
    int homogeneous = 1; uint8_t elem_tag = 0, elem_bc = 0; int any_poly = 0;
    size_t ncells = 0;
    if (kind != K_STRING && len) {
        if (len > reps_cap) { reps_cap = len * 2; reps = realloc(reps, reps_cap); cells = realloc(cells, reps_cap * sizeof(Cell)); if (!reps || !cells) die("out of memory"); }
        source_reps(o, reps, len);
        Value *f = obj_fields(o);
        unsigned char *fb = NULL;
        if (write_fields) {
            if (out_fields.n + (size_t)len * 2 > out_fields.cap) out_drain(&out_fields);
            fb = (size_t)len * 2 <= out_fields.cap ? out_fields.buf + out_fields.n : malloc((size_t)len * 2);
            if (!fb) die("out of memory");
        }
        for (uint32_t i = 0; i < len; i++) {
            uint8_t tag = val_tag(f[i]) <= T_PTR ? val_tag(f[i]) : T_UNIT;
            unsigned b = bits_of(f[i]);
            uint8_t bc = (uint8_t)bc_of(tag, b);
            uint8_t pk = (tag == T_PTR && val_ptr(f[i])) ? obj_kind(val_ptr(f[i])) : 0;
            if (pk > K_EXNCON) pk = 0;
            uint8_t rep = reps[i];
            uint8_t poly = (rep == REP_ANY || rep == 15);
            if (fb) { fb[2 * i] = (uint8_t)(tag | (pk << 3)); fb[2 * i + 1] = (uint8_t)(bc | ((rep & 15) << 3)); }
            field_total++; field_tag[tag]++; field_bc[tag][bc]++; field_rep[tag][rep_idx(rep == 15 ? NREP - 1 : rep)]++;
            if (tag == T_PTR) field_ptr_kind[pk]++;
            if (tag == T_REAL) { field_real++; if (bc == 0) field_real_enc++; if (val_real(f[i]) == 0.0) field_real_zero++; }
            if (i == 0) { elem_tag = tag; elem_bc = bc; }
            else { if (tag != elem_tag) homogeneous = 0; if (bc > elem_bc) elem_bc = bc; }
            if (poly) any_poly = 1;
            /* tally (tag, bc, poly): the cells are few for an ordinary object */
            size_t c;
            for (c = 0; c < ncells; c++) if (cells[c].tag == tag && cells[c].bc == bc && cells[c].poly == poly) break;
            if (c == ncells) { cells[c].tag = tag; cells[c].bc = bc; cells[c].poly = poly; cells[c].n = 0; ncells++; }
            cells[c].n++;
        }
        if (fb) {
            if (fb == out_fields.buf + out_fields.n) out_fields.n += (size_t)len * 2;
            else { out_put(&out_fields, fb, (size_t)len * 2); free(fb); }
            alloc_fields_bytes += (size_t)len * 2;
        }
    }
    /* arrays and vectors: their elements' tag and class, for the stores to keep up */
    if (kind == K_ARRAY || (kind == K_TUPLE && pend_site_kind == 1)) {
        if (!summary) homog[OBJ_ID(o)] = (uint8_t)((len == 0 ? 0 : elem_tag) | (elem_bc << 3) | (homogeneous ? 0 : 0x80));
        unsigned t = len == 0 ? 0 : elem_tag, bc = elem_bc, sk = pend_site_kind < 3 ? pend_site_kind : 2;
        if (!homogeneous) { t = 0; bc = 0; }
        arr_alloc_objs[kind == K_ARRAY ? 0 : 1][sk][homogeneous][t][bc]++;
        arr_alloc_bytes[kind == K_ARRAY ? 0 : 1][sk][homogeneous][t][bc] += l0;
    } else if (kind == K_TUPLE && pend_site_kind == 0) {
        tuple_homog_objs[homogeneous][len ? elem_tag : 0]++;
        tuple_homog_bytes[homogeneous][len ? elem_tag : 0] += l0;
    }
    /* the first-order sizes: this object under every layout, with the boxes its fields need */
    int vector = (kind == K_ARRAY || (kind == K_TUPLE && pend_site_kind == 1)) && len > 0;
    for (int vi = 0; vi < NVAR; vi++) {
        enum Layout L = variants[vi].L; unsigned v = variants[vi].v;
        unsigned eb = layout_compact_elem(v, kind, vector && homogeneous, elem_tag, elem_bc);
        var_obj_bytes[vi] += layout_obj_size(L, v, kind, len, eb);
        if (eb) var_compact_objs[vi]++;
        if (L == L0 || eb) continue;    /* compact elements are unboxed by construction */
        for (size_t c = 0; c < ncells; c++) {
            int poly = cells[c].poly;
            if (L == L4 && (v & LV_L4UNIFORM)) {
                if (kind == K_CON || kind == K_REF || kind == K_ARRAY) poly = 1;
                else if (kind == K_TUPLE && any_poly) poly = 1;
            }
            int nb = layout_needs_box(L, v, cells[c].tag, cells[c].bc, poly);
            if (nb == 1) { var_boxes[vi] += cells[c].n; var_box_bytes[vi] += cells[c].n * layout_box_size(L, v); }
            else if (nb == 2) var_unrep[vi] += cells[c].n;
        }
    }
}

/* ---------------------------------------------------------------- collections */

void census_gc_begin(VM *vm) {
    (void)vm;
    census_sample_no++;
    if (census_sample_no >= (1u << (64 - CENSUS_ID_BITS))) { fprintf(stderr, "runevm-census: more than 2^%d samples\n", 64 - CENSUS_ID_BITS); exit(2); }
    if ((size_t)census_sample_no + 1 >= sample_cap) {
        sample_cap *= 2;
        sample_clock = realloc(sample_clock, sample_cap * sizeof *sample_clock);
        if (!sample_clock) die("out of memory (samples)");
    }
    sample_clock[census_sample_no] = census_clock;
}
/* a pass of collect_into: vm_gc runs two when the heap grows, and the
   survivors are those of the last */
void census_collect_begin(void) {
    live_objs_pass = 0;
    memset(pass_surv_bytes, 0, sizeof pass_surv_bytes);
    memset(pass_surv_objs, 0, sizeof pass_surv_objs);
}
void census_survive(Obj *n, size_t size) {
    uint64_t id = OBJ_ID(n);
    if (!summary && id < ids_cap) death[id] = final_collection ? UINT32_MAX : census_sample_no;
    live_objs_pass++;
    uint32_t age = census_sample_no - OBJ_SAMPLE(n);
    unsigned b = age >= NAGEB ? NAGEB : age;
    pass_surv_bytes[b] += size - 8;     /* the L0 size: the header's id word is not counted */
    pass_surv_objs[b]++;
}
void census_gc_end(VM *vm) {
    if (!summary) {
        unsigned char rec[24];
        put_u64(rec, census_clock);
        put_u64(rec + 8, vm->census_used_stock);
        put_u64(rec + 16, live_objs_pass);
        out_put(&out_samples, rec, 24);
    }
    samples_written++;
    last_live_bytes = vm->census_used_stock; last_live_objs = live_objs_pass;
    sum_live_bytes += last_live_bytes;
    if (last_live_bytes > max_live_bytes) max_live_bytes = last_live_bytes;
    for (unsigned b = 0; b <= NAGEB; b++) { surv_bytes[b] += pass_surv_bytes[b]; surv_objs[b] += pass_surv_objs[b]; }
    census_last_sample_clock = census_clock;
    /* a line of progress every 4096 samples (a GB of allocation at the default interval): the long runs are watched by it */
    static uint64_t progress_every;
    if (!progress_every) { const char *e = getenv("RUNE_CENSUS_PROGRESS"); progress_every = e && atoll(e) > 0 ? (uint64_t)atoll(e) : 4096; }
    if (samples_written % progress_every == 0)
        fprintf(stderr, "runevm-census: progress: sample %" PRIu64 ", clock %" PRIu64 ", live %" PRIu64 " bytes %" PRIu64 " objects\n", samples_written, census_clock, last_live_bytes, last_live_objs);
}

/* ---------------------------------------------------------------- stores */

void census_store(Obj *o, uint32_t field, Value v, int site, int rep) {
    if (!o || field >= obj_len(o)) return;
    Value old = obj_field(o, field);
    uint64_t src = OBJ_ID(o);
    uint64_t dst = (val_is(v, T_PTR) && val_ptr(v)) ? OBJ_ID(val_ptr(v)) : 0;
    uint8_t tag = val_tag(v) <= T_PTR ? val_tag(v) : T_UNIT;
    if (field > 0xffff) store_field_clamped++;
    if (!summary) {
        unsigned char rec[16];
        put_u32(rec, (uint32_t)(census_clock / 16));
        put_u32(rec + 4, (uint32_t)src);
        put_u32(rec + 8, (uint32_t)dst);
        put_u16(rec + 12, field > 0xffff ? 0xffff : (uint16_t)field);
        put_u8(rec + 14, (uint8_t)site);
        put_u8(rec + 15, (uint8_t)((val_is(old, T_PTR) ? 1 : 0) | (tag << 1) | ((rep & 15) << 4)));
        out_put(&out_stores, rec, 16);
    }
    store_total++;
    if (val_is(old, T_PTR)) store_ptr_old++;
    /* the ages: exact from birth8 in the full mode, from the birth samples in summary mode */
    unsigned cs = summary ? age_class(est_age(OBJ_SAMPLE(o))) : src < ids_cap ? age_class(census_clock - ((uint64_t)birth8[src] << 3)) : NAGE - 1;
    unsigned cd = NAGE;
    if (dst) {
        store_ptr_new++;
        if (summary) cd = age_class(est_age(OBJ_SAMPLE(val_ptr(v))));
        else if (dst < ids_cap) cd = age_class(census_clock - ((uint64_t)birth8[dst] << 3));
        if (dst > src) store_old_young++;     /* ids are in allocation order: the value is the younger */
    }
    if (site >= 0 && site < 3) store_hist[site][tag][cs][cd]++;
    if (tag == T_REAL) { store_real++; if (bits_of(v) == 0) store_real_enc++; if (val_real(v) == 0.0) store_real_zero++; }
    if (!summary && obj_kind(o) == K_ARRAY && src < ids_cap) {
        uint8_t h = homog[src];
        if (!(h & 0x80)) {
            uint8_t bc = (uint8_t)bc_of(tag, bits_of(v));
            if (tag != (h & 7)) homog[src] = (uint8_t)(h | 0x80);
            else if (bc > ((h >> 3) & 7)) homog[src] = (uint8_t)((h & 0x87) | (bc << 3));
        }
    }
}

void census_store_fast(Obj *o, uint32_t i, Value v, int32_t reg) {
    if (!census_on) return;
    int rep = CENSUS_REP(&the_vm->prog, census_func, reg);
    if (census_func >= the_vm->prog.nfuncs) rep = 15;
    census_store(o, i, v, obj_kind(o) == K_REF ? 1 : 2, rep);
}

/* ---------------------------------------------------------------- results and calls */

void census_prim_result(int prim, Value v) {
    if (prim < 0 || prim >= PRIM__COUNT) return;
    uint8_t tag = val_tag(v) <= T_PTR ? val_tag(v) : T_UNIT;
    unsigned b = bits_of(v);
    prim_hist[prim][tag][b]++;
    if (tag == T_REAL) { prim_real++; if (b == 0) prim_real_enc++; if (val_real(v) == 0.0) prim_real_zero++; }
}

void census_call(int op, Value v, int rep) {
    if (op < 0 || op >= NOP) return;
    uint8_t tag = val_tag(v) <= T_PTR ? val_tag(v) : T_UNIT;
    unsigned b = bits_of(v);
    call_hist[op][tag][b][rep_idx(rep == 15 ? NREP - 1 : rep)]++;
    if (tag == T_REAL) { call_real++; if (b == 0) call_real_enc++; if (val_real(v) == 0.0) call_real_zero++; }
}

/* ---------------------------------------------------------------- the fork's child */

void census_fork_child(void) {
    /* the parent's files stay the parent's: nothing more is written, and
       the buffers are dropped without a flush */
    census_on = 0;
    census_every = 0;
    census_pending = NULL;
    census_pcs = NULL;
    out_alloc.n = out_fields.n = out_stores.n = out_samples.n = 0;
}

/* ---------------------------------------------------------------- census.txt */

static int cmp_bytes_desc(const void *a, const void *b) {
    const HEnt *x = *(HEnt *const *)a, *y = *(HEnt *const *)b;
    return x->bytes < y->bytes ? 1 : x->bytes > y->bytes ? -1 : 0;
}
static HEnt **sorted(HTab *t, size_t *n) {
    HEnt **v = malloc((t->n ? t->n : 1) * sizeof *v);
    if (!v) die("out of memory");
    size_t k = 0;
    for (size_t i = 0; i < t->cap; i++) if (t->e[i].objects) v[k++] = &t->e[i];
    qsort(v, k, sizeof *v, cmp_bytes_desc);
    *n = k;
    return v;
}
static double pct(uint64_t a, uint64_t b) { return b ? 100.0 * (double)a / (double)b : 0.0; }
static const char *func_name(uint32_t f) {
    return f < the_vm->prog.nfuncs ? the_vm->prog.funcs[f].name : "<runtime>";
}
static void site_desc(uint32_t site, uint8_t site_kind, char *buf, size_t n) {
    const Program *p = &the_vm->prog;
    if (site_kind == 2 || site >= p->code_len) { snprintf(buf, n, "runtime"); return; }
    uint8_t op = p->code[site];
    if (op >= ROP__COUNT) { snprintf(buf, n, "?"); return; }
    if (op == ROP_PRIM || op == ROP_PRIMPUSH) {
        int32_t prim = read_i32(p->code + site + 1);
        snprintf(buf, n, "%s %s", rop_names[op], prim >= 0 && prim < PRIM__COUNT ? prim_names[prim] : "?");
    } else snprintf(buf, n, "%s", rop_names[op]);
}
static uint64_t sum_bits(const uint64_t *h, unsigned from, unsigned to) { uint64_t s = 0; for (unsigned b = from; b <= to; b++) s += h[b]; return s; }

static void write_census_txt(VM *vm) {
    char path[4200];
    snprintf(path, sizeof path, "%s/census.txt", dir);
    FILE *f = fopen(path, "w");
    if (!f) die(path);
    const Program *p = &vm->prog;
    uint64_t objects = census_next_id;
    fprintf(f, "# census.txt -- %s\n", vm->progname ? vm->progname : "?");
    fprintf(f, "# objects %" PRIu64 " (ids 1..%" PRIu64 "; alloc.bin has a record for id 0 too)\n", objects, objects);
    fprintf(f, "# bytes_l0 %" PRIu64 " (the sum of l0size; == --count's bytes)\n", census_clock);
    fprintf(f, "# instructions %" PRIu64 "\n", (uint64_t)vm->instructions);
    fprintf(f, "# samples %" PRIu64 " (forced collections every %" PRIu64 " bytes, plus every other collection, the last being the one at exit; sample k is record k, from 1)\n", samples_written, census_every);
    fprintf(f, "# collections %zu, live at exit (stock bytes) %zu\n", vm->gc_count, vm->census_used_stock);
    if (summary) fprintf(f, "# summary mode (--census-summary): no trace files but pcs.bin, no per-object arrays; the ages of the stores table from the birth samples (est_age), the arrays' homogeneity at allocation only\n");
    fprintf(f, "# fields.bin %s (%" PRIu64 " bytes); stores %" PRIu64 " (%" PRIu64 " with a field index clamped to 65535)\n",
            write_fields ? "written" : "not written", alloc_fields_bytes, store_total, store_field_clamped);
    fprintf(f, "# bits: docs/census.md's (INT/CHAR/CON0 two's-complement bits 1..64, WORD 64-clz, REAL 0 = value-encodable else 7)\n");
    fprintf(f, "# a real 0.0 has exponent 0 and so counts as NOT value-encodable under docs/census.md's rule; the zeros are counted apart\n\n");

    /* --- by kind */
    fprintf(f, "## alloc by kind: kind objects bytes share\n");
    for (int k = 1; k <= K_LAST; k++) if (kind_objs[k])
        fprintf(f, "%s\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", kind_names[k], kind_objs[k], kind_bytes[k], pct(kind_bytes[k], census_clock));
    fprintf(f, "\n");

    /* --- by shape */
    size_t n; HEnt **v = sorted(&shapes, &n);
    fprintf(f, "## alloc by (kind, contag, len): kind contag len objects bytes share  [%zu shapes; top 300 by bytes]\n", n);
    for (size_t i = 0; i < n && i < 300; i++) {
        uint64_t key = v[i]->key;
        fprintf(f, "%s\t%u\t%u\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", kind_names[(key >> 48) & 15], (unsigned)((key >> 32) & 0xffff), (unsigned)(key & 0xffffffffu),
                v[i]->objects, v[i]->bytes, pct(v[i]->bytes, census_clock));
    }
    free(v);
    fprintf(f, "\n## alloc by (kind, len) for len 0..8 and >8: kind len objects bytes\n");
    {
        uint64_t o2[9][10] = {{0}}, b2[9][10] = {{0}};
        for (size_t i = 0; i < shapes.cap; i++) if (shapes.e[i].objects) {
            uint64_t key = shapes.e[i].key; unsigned k = (key >> 48) & 15, len = (unsigned)(key & 0xffffffffu);
            unsigned li = len > 8 ? 9 : len;
            o2[k][li] += shapes.e[i].objects; b2[k][li] += shapes.e[i].bytes;
        }
        for (int k = 1; k <= 8; k++) for (int li = 0; li < 10; li++) if (o2[k][li])
            fprintf(f, "%s\t%s%d\t%" PRIu64 "\t%" PRIu64 "\n", kind_names[k], li == 9 ? ">" : "", li == 9 ? 8 : li, o2[k][li], b2[k][li]);
    }
    fprintf(f, "\n");

    /* --- by site */
    v = sorted(&sites, &n);
    fprintf(f, "## alloc by site: pc func funcname what kind avglen objects bytes share  [%zu sites; top 200 by bytes]\n", n);
    for (size_t i = 0; i < n && i < 200; i++) {
        uint64_t key = v[i]->key; uint32_t site = (uint32_t)(key >> 8); uint8_t kind = key & 15, sk = (key >> 4) & 15;
        char what[64]; site_desc(site, sk, what, sizeof what);
        fprintf(f, "%u\t%u\t%s\t%s\t%s\t%.1f\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", site, v[i]->aux, func_name(v[i]->aux), what, kind_names[kind],
                (double)v[i]->sum / (double)v[i]->objects, v[i]->objects, v[i]->bytes, pct(v[i]->bytes, census_clock));
    }
    /* known-rep sites: every source register's rep known (not ANY) */
    {
        uint64_t known_objs = 0, known_bytes = 0, site_objs = 0, site_bytes = 0;
        for (size_t i = 0; i < n; i++) {
            uint64_t key = v[i]->key; uint32_t site = (uint32_t)(key >> 8); uint8_t sk = (key >> 4) & 15;
            if (sk != 0 || site >= p->code_len) continue;
            site_objs += v[i]->objects; site_bytes += v[i]->bytes;
            const Function *fn = v[i]->aux < p->nfuncs ? &p->funcs[v[i]->aux] : NULL;
            if (!fn || !fn->has_meta) continue;
            const uint8_t *code = p->code; uint32_t at = site; int all = 1; uint32_t cnt = 0; const uint8_t *L = NULL;
            switch (code[at]) {
            case ROP_TUPLE: cnt = (uint32_t)read_i32(code + at + 5); L = code + at + 9; break;
            case ROP_CLOSURE: cnt = (uint32_t)read_i32(code + at + 9); L = code + at + 13; break;
            case ROP_CONN: cnt = (uint32_t)read_i32(code + at + 9); L = code + at + 13; break;
            case ROP_CON: cnt = 1; L = code + at + 9; break;
            case ROP_MKEXN: cnt = 2; L = code + at + 5; break;
            case ROP_NEWEXN: cnt = 0; break;
            default: all = 0; break;
            }
            for (uint32_t k = 0; k < cnt && all; k++) { int32_t r = read_i32(L + 4 * k); if (r < 0 || (uint32_t)r >= fn->nlocals || fn->reps[r] == REP_ANY) all = 0; }
            if (all) { known_objs += v[i]->objects; known_bytes += v[i]->bytes; }
        }
        fprintf(f, "\n## objects allocated at instruction sites whose sources are all of known rep: %" PRIu64 " objects, %" PRIu64 " bytes of %" PRIu64 " objects, %" PRIu64 " bytes at instruction sites (%.2f%% of bytes)\n",
                known_objs, known_bytes, site_objs, site_bytes, pct(known_bytes, site_bytes));
    }
    free(v);
    fprintf(f, "\n## alloc by site kind: kind objects bytes\n");
    {
        uint64_t so[3] = {0}, sb[3] = {0};
        for (size_t i = 0; i < sites.cap; i++) if (sites.e[i].objects) { unsigned sk = (sites.e[i].key >> 4) & 15; if (sk < 3) { so[sk] += sites.e[i].objects; sb[sk] += sites.e[i].bytes; } }
        static const char *const skn[3] = { "instruction", "primitive", "runtime" };
        for (int k = 0; k < 3; k++) fprintf(f, "%s\t%" PRIu64 "\t%" PRIu64 "\n", skn[k], so[k], sb[k]);
    }

    /* --- by function */
    fprintf(f, "\n## alloc by function: func name objects bytes share  [all with allocations, by bytes]\n");
    if (func_objs) {
        size_t nf = func_objs_cap;
        uint32_t *idx = malloc(nf * sizeof *idx); size_t k = 0;
        for (size_t i = 0; i < nf; i++) if (func_objs[i]) idx[k++] = (uint32_t)i;
        /* insertion-free sort by bytes: qsort with a global */
        for (size_t i = 1; i < k; i++) { uint32_t x = idx[i]; size_t j = i; while (j > 0 && func_bytes[idx[j - 1]] < func_bytes[x]) { idx[j] = idx[j - 1]; j--; } idx[j] = x; }
        for (size_t i = 0; i < k; i++) {
            uint32_t fi = idx[i];
            fprintf(f, "%u\t%s\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", fi == nf - 1 ? 0xffffffffu : fi, fi == nf - 1 ? "<runtime>" : func_name(fi), func_objs[fi], func_bytes[fi], pct(func_bytes[fi], census_clock));
        }
        free(idx);
    }

    /* --- fields */
    fprintf(f, "\n## fields at allocation: %" PRIu64 " fields (non-string objects)\n", field_total);
    fprintf(f, "## by tag: tag count share | bits classes <=8 <=31 <=48 <=51 <=62 <=63 64 (REAL: enc / boxed)\n");
    for (int t = 0; t < NTAG; t++) if (field_tag[t]) {
        fprintf(f, "%s\t%" PRIu64 "\t%.2f%%", tag_names[t], field_tag[t], pct(field_tag[t], field_total));
        if (t == T_INT || t == T_WORD || t == T_CHAR || t == T_CON0) { for (int b = 0; b < 7; b++) fprintf(f, "\t%" PRIu64, field_bc[t][b]); }
        else if (t == T_REAL) fprintf(f, "\tenc %" PRIu64 "\tboxed %" PRIu64 "\tzeros %" PRIu64, field_bc[t][0], field_bc[t][7], field_real_zero);
        fprintf(f, "\n");
    }
    fprintf(f, "## by tag x source rep: tag rep count\n");
    for (int t = 0; t < NTAG; t++) for (int r = 0; r < NREP; r++) if (field_rep[t][r])
        fprintf(f, "%s\t%s\t%" PRIu64 "\n", tag_names[t], rep_names[r], field_rep[t][r]);
    fprintf(f, "## pointer fields by pointee kind: kind count\n");
    for (int k = 0; k <= K_LAST; k++) if (field_ptr_kind[k]) fprintf(f, "%s\t%" PRIu64 "\n", kind_names[k], field_ptr_kind[k]);
    fprintf(f, "## tuples of the TUPLE instruction by homogeneity: homogeneous elemtag objects bytes\n");
    for (int h = 0; h < 2; h++) for (int t = 0; t < NTAG; t++) if (tuple_homog_objs[h][t])
        fprintf(f, "%d\t%s\t%" PRIu64 "\t%" PRIu64 "\n", h, tag_names[t], tuple_homog_objs[h][t], tuple_homog_bytes[h][t]);

    /* --- prim results */
    fprintf(f, "\n## prim results: prim tag total >31 >48 >51 >62 >63 =64 bits (REAL: enc boxed) | b:count...\n");
    for (int pr = 0; pr < PRIM__COUNT; pr++) for (int t = 0; t < NTAG; t++) {
        uint64_t total = sum_bits(prim_hist[pr][t], 0, 64);
        if (!total) continue;
        fprintf(f, "%s\t%s\t%" PRIu64, prim_names[pr], tag_names[t], total);
        if (t == T_REAL) fprintf(f, "\tenc %" PRIu64 "\tboxed %" PRIu64, prim_hist[pr][t][0], prim_hist[pr][t][7]);
        else fprintf(f, "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64,
                     sum_bits(prim_hist[pr][t], 32, 64), sum_bits(prim_hist[pr][t], 49, 64), sum_bits(prim_hist[pr][t], 52, 64),
                     sum_bits(prim_hist[pr][t], 63, 64), sum_bits(prim_hist[pr][t], 64, 64), prim_hist[pr][t][64]);
        fprintf(f, "\t|");
        for (int b = 0; b < NBITS; b++) if (prim_hist[pr][t][b]) fprintf(f, " %d:%" PRIu64, b, prim_hist[pr][t][b]);
        fprintf(f, "\n");
    }

    /* --- calls */
    fprintf(f, "\n## calls: op tag rep count >31 >48 >51 >62 >63 bits (REAL: enc boxed)\n");
    for (int op = 0; op < NOP; op++) {
        uint64_t optotal = 0, opany = 0;
        for (int t = 0; t < NTAG; t++) for (int r = 0; r < NREP; r++) {
            uint64_t tot = 0, g31 = 0, g48 = 0, g51 = 0, g62 = 0, g63 = 0;
            for (int b = 0; b < NBITS; b++) { uint64_t c = call_hist[op][t][b][r]; tot += c; if (b > 31) g31 += c; if (b > 48) g48 += c; if (b > 51) g51 += c; if (b > 62) g62 += c; if (b > 63) g63 += c; }
            if (!tot) continue;
            optotal += tot; if (r == REP_ANY || r == NREP - 1) opany += tot;
            fprintf(f, "%s\t%s\t%s\t%" PRIu64, callop_names[op], tag_names[t], rep_names[r], tot);
            if (t == T_REAL) fprintf(f, "\tenc %" PRIu64 "\tboxed %" PRIu64 "\n", call_hist[op][t][0][r], call_hist[op][t][7][r]);
            else fprintf(f, "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\n", g31, g48, g51, g62, g63);
        }
        fprintf(f, "%s\ttotal\t%" PRIu64 "\tANY/unknown\t%" PRIu64 "\t%.2f%%\n", callop_names[op], optotal, opany, pct(opany, optotal));
    }

    /* --- stores */
    fprintf(f, "\n## stores: %" PRIu64 " (SETENV, ref_set, array_update; not the fill of a fresh object); new value a pointer %" PRIu64 ", old value a pointer %" PRIu64 ", old->young (the object stored into older than the value) %" PRIu64 "\n",
            store_total, store_ptr_new, store_ptr_old, store_old_young);
    fprintf(f, "## by site x new tag x age class of the object stored into x age class of the value: site tag srcage dstage count\n");
    for (int s = 0; s < 3; s++) for (int t = 0; t < NTAG; t++) for (int a = 0; a < NAGE; a++) for (int d = 0; d <= NAGE; d++) if (store_hist[s][t][a][d])
        fprintf(f, "%s\t%s\t%s\t%s\t%" PRIu64 "\n", site_names[s], tag_names[t], age_names[a], age_names[d], store_hist[s][t][a][d]);
    fprintf(f, "## by site: site count\n");
    for (int s = 0; s < 3; s++) { uint64_t c = 0; for (int t = 0; t < NTAG; t++) for (int a = 0; a < NAGE; a++) for (int d = 0; d <= NAGE; d++) c += store_hist[s][t][a][d]; fprintf(f, "%s\t%" PRIu64 "\n", site_names[s], c); }

    /* --- reals */
    fprintf(f, "\n## reals: where produced enc boxed zeros share_enc\n");
    fprintf(f, "prim results\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", prim_real, prim_real_enc, prim_real - prim_real_enc, prim_real_zero, pct(prim_real_enc, prim_real));
    fprintf(f, "crossing calls\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", call_real, call_real_enc, call_real - call_real_enc, call_real_zero, pct(call_real_enc, call_real));
    fprintf(f, "stored at allocation\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", field_real, field_real_enc, field_real - field_real_enc, field_real_zero, pct(field_real_enc, field_real));
    fprintf(f, "stored later\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%.2f%%\n", store_real, store_real_enc, store_real - store_real_enc, store_real_zero, pct(store_real_enc, store_real));

    /* --- arrays */
    fprintf(f, "\n## arrays and vectors at allocation by (kind, made by, homogeneous, elem tag, max bits class): kind madeby homogeneous elemtag maxbc objects bytes  [ARRAY of any site; TUPLE made by a primitive = vector; homogeneity of the elements at the end of the allocating instruction]\n");
    {
        static const char *const skn[3] = { "instruction", "primitive", "runtime" };
        for (int ki = 0; ki < 2; ki++) for (int sk = 0; sk < 3; sk++) for (int hom = 1; hom >= 0; hom--) for (int t = 0; t < NTAG; t++) for (int bc = 0; bc < NBC; bc++) if (arr_alloc_objs[ki][sk][hom][t][bc])
            fprintf(f, "%s\t%s\t%d\t%s\t%d\t%" PRIu64 "\t%" PRIu64 "\n", ki == 0 ? "ARRAY" : "TUPLE", skn[sk], hom, hom ? tag_names[t] : "-", bc, arr_alloc_objs[ki][sk][hom][t][bc], arr_alloc_bytes[ki][sk][hom][t][bc]);
    }
    fprintf(f, "\n## arrays and vectors by (kind, made by, homogeneous, elem tag, max bits class): kind madeby homogeneous elemtag maxbc objects bytes  [ARRAY of any site; TUPLE made by a primitive = vector; homogeneity at allocation and after every store]\n");
    if (summary) fprintf(f, "not tracked in summary mode (no per-object memory): see the table at allocation above\n");
    else {
        uint64_t ao[2][3][2][NTAG][NBC] = {{{{{0}}}}}, ab[2][3][2][NTAG][NBC] = {{{{{0}}}}};
        for (size_t i = 0; i < arr_n; i++) {
            uint8_t h = homog[arr_ids[i]]; int hom = !(h & 0x80); unsigned t = h & 7, bc = (h >> 3) & 7;
            int ki = arr_kind[i] == K_ARRAY ? 0 : 1; unsigned sk = arr_site[i] < 3 ? arr_site[i] : 2;
            if (!hom) { t = 0; bc = 0; }
            ao[ki][sk][hom][t][bc]++; ab[ki][sk][hom][t][bc] += l0_obj_size(arr_kind[i], arr_len[i]);
        }
        static const char *const skn[3] = { "instruction", "primitive", "runtime" };
        for (int ki = 0; ki < 2; ki++) for (int sk = 0; sk < 3; sk++) for (int hom = 1; hom >= 0; hom--) for (int t = 0; t < NTAG; t++) for (int bc = 0; bc < NBC; bc++) if (ao[ki][sk][hom][t][bc])
            fprintf(f, "%s\t%s\t%d\t%s\t%d\t%" PRIu64 "\t%" PRIu64 "\n", ki == 0 ? "ARRAY" : "TUPLE", skn[sk], hom, hom ? tag_names[t] : "-", bc, ao[ki][sk][hom][t][bc], ab[ki][sk][hom][t][bc]);
    }

    /* --- first-order sizes */
    fprintf(f, "\n## first-order sizes (layouts.h): variant obj_bytes boxes box_bytes total ratio_to_L0 unrepresentable compact_objs  [compact: ARRAYs and primitive-made TUPLEs homogeneous at allocation; L4-uniform: every INT/WORD/REAL field of CON/REF/ARRAY and of tuples with a polymorphic source boxed; L4-mono: fields from ANY/unknown sources]\n");
    for (int vi = 0; vi < NVAR; vi++) {
        uint64_t total = var_obj_bytes[vi] + var_box_bytes[vi];
        fprintf(f, "%s\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%" PRIu64 "\t%.4f\t%" PRIu64 "\t%" PRIu64 "\n", variants[vi].name, var_obj_bytes[vi], var_boxes[vi], var_box_bytes[vi], total,
                census_clock ? (double)total / (double)census_clock : 0.0, var_unrep[vi], var_compact_objs[vi]);
    }

    /* --- survivors by age */
    fprintf(f, "\n## survivors by age (from the birth sample in the id word; a sample = a collection, forced every %" PRIu64 " bytes of L0 allocation, so age a ~ a x %" PRIu64 " bytes since birth; the last collection is the one at exit): age_samples bytes objects share_bytes share_objects | survival_bytes(N) survival_objects(N)\n"
               "##   alive(a) = the survivors of exactly age a summed over all collections (each object counts once at each age it reaches); share = alive(a) / allocated;\n"
               "##   survival(N) for a nursery of N samples = (1/N) * sum_{a=1..N} alive(a) / allocated (an object is born at a uniformly random offset in its nursery window, so faces its first collection at an age uniform in 1..N);\n"
               "##   >=%d: the survivors of every age >= %d summed (once per collection each survives): no share\n", census_every, census_every, NAGEB, NAGEB);
    fprintf(f, "# collections %" PRIu64 ", allocated %" PRIu64 " bytes %" PRIu64 " objects; live bytes: last %" PRIu64 " (%" PRIu64 " objects), mean %.0f, max %" PRIu64 "\n",
            samples_written, census_clock, objects, last_live_bytes, last_live_objs, samples_written ? (double)sum_live_bytes / (double)samples_written : 0.0, max_live_bytes);
    {
        static const unsigned ages[] = { 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128 };
        double cum_b = 0, cum_o = 0; unsigned next = 0;
        for (unsigned a = 1; a < NAGEB; a++) {
            cum_b += census_clock ? (double)surv_bytes[a] / (double)census_clock : 0.0;
            cum_o += objects ? (double)surv_objs[a] / (double)objects : 0.0;
            if (next < sizeof ages / sizeof ages[0] && a == ages[next]) {
                next++;
                fprintf(f, "%u\t%" PRIu64 "\t%" PRIu64 "\t%.4f%%\t%.4f%%\t%.4f%%\t%.4f%%\n", a, surv_bytes[a], surv_objs[a],
                        pct(surv_bytes[a], census_clock), pct(surv_objs[a], objects), 100.0 * cum_b / a, 100.0 * cum_o / a);
            }
        }
        /* age 128 exactly is in the >= 128 bucket: its row is the bucket's, marked */
        fprintf(f, ">=%d\t%" PRIu64 "\t%" PRIu64 "\t-\t-\t-\t-\n", NAGEB, surv_bytes[NAGEB], surv_objs[NAGEB]);
    }
    fclose(f);
}

/* ---------------------------------------------------------------- exit */

void census_exit(VM *vm) {
    if (!census_on) return;
    CENSUS_FLUSH();
    /* the last sample: what is alive at exit */
    final_collection = 1;
    vm_gc(vm, 0);
    final_collection = 0;
    census_on = 0;      /* nothing more is traced: the tables are written now */
    char path[4200];
    FILE *f;
    if (!summary) {
        out_close(&out_alloc);
        out_close(&out_fields);
        out_close(&out_stores);
        out_close(&out_samples);
        snprintf(path, sizeof path, "%s/death.bin", dir);
        f = fopen(path, "wb");
        if (!f) die(path);
        /* little-endian u32s: written as they lie on a little-endian machine */
        uint64_t n = census_next_id + 1;
        if (fwrite(death, sizeof(uint32_t), n, f) != n) die("write death.bin");
        fclose(f);
    }
    snprintf(path, sizeof path, "%s/pcs.bin", dir);
    f = fopen(path, "wb");
    if (!f) die(path);
    if (census_pcs && vm->prog.code_len && fwrite(census_pcs, sizeof(uint64_t), vm->prog.code_len, f) != vm->prog.code_len) die("write pcs.bin");
    fclose(f);
    write_census_txt(vm);
}
