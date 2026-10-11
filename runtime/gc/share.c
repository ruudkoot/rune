/* Runtime.share (docs/runtime.md, *Sharing*): the immutable objects of the
   heap that are equal made one, as Poly/ML's PolyML.shareCommonData does
   before a heap is saved. A program that builds the same values again and
   again -- HOL's terms and types, a compiler's environments -- keeps one of
   each, in its heap and in the images it writes (docs/plans/hol4.md).

   Equal is SML's equality of values that have no identity: two tuples,
   vectors or constructed values of the same constructor whose fields are
   equal, strings of the same bytes, reals and boxed words of the same bits,
   and exception values of the same constructor and argument. A ref, an
   array, an array of bytes or of reals, an exception constructor and a
   closure keep their identity and are never one with another. Nothing
   writes into an object of the other kinds once it is made -- a closure's
   environment is the one thing filled after (SETENV), and a vector or a
   string is made whole by its primitive -- so an object the stack points
   at is shared as any other, the stack pointed at the one kept.

   It runs after a full collection, so that every object is in the old
   space: each is given a number bottom-up, the same number where the kind,
   the tag, the length and the fields' values -- a pointer by the number of
   what it points at -- are the same; every field and root that points at
   an object of a number is then pointed at the first object of that
   number, and a second collection frees the others. Old points at old, so
   the write barrier has nothing to record. What it needs beside the heap
   is a table of every object, about as large as the heap's objects' count
   times 24 bytes; where that cannot be had it does nothing. */
#include "gc/gc.h"
#include <stdlib.h>
#include <string.h>

typedef struct { Obj *o; uint32_t id; uint8_t state; } Node;   /* state: 0 new, 1 open, 2 numbered */
enum { PINNED = 4 };

typedef struct {
    Node *nodes; size_t ncap;            /* every object, by address */
    uint32_t *classes; size_t ccap;      /* the numbers of the immutable objects, by their contents */
    Obj **reps; size_t nreps, repcap;    /* each number's first object */
    uint64_t saved;                      /* the bytes of the objects made one with another */
} Share;

static size_t hash_ptr(const Obj *o) { return (size_t)(((uintptr_t)o >> 3) * 0x9E3779B97F4A7C15ull); }
static Node *node(Share *s, const Obj *o) {
    size_t j = hash_ptr(o) & (s->ncap - 1);
    while (s->nodes[j].o && s->nodes[j].o != o) j = (j + 1) & (s->ncap - 1);
    return &s->nodes[j];
}
static int is_ptr(Value v) { return !val_is_imm(v) && v != 0; }
static int mergeable(int k) { return k == K_TUPLE || k == K_CON || k == K_STRING || k == K_REAL || k == K_BOX || k == K_EXN; }
static size_t raw_len(const Obj *o) { return obj_kind(o) == K_STRING ? obj_len(o) : 8; }

static uint64_t mix(uint64_t h, uint64_t x) { return (h ^ x) * 0x100000001B3ull + (h >> 29); }
static uint64_t contents_hash(Share *s, const Obj *o) {
    uint64_t h = mix(mix(mix(0xcbf29ce484222325ull, (uint64_t)obj_kind(o)), obj_contag(o)), obj_len(o));
    if (!obj_has_fields(o)) {
        const unsigned char *b = (const unsigned char *)obj_bytes_c(o);
        for (size_t i = 0; i < raw_len(o); i++) h = mix(h, b[i]);
        return h;
    }
    for (uint32_t i = 0; i < obj_len(o); i++) {
        Value f = obj_field(o, i);
        h = mix(h, is_ptr(f) ? ((uint64_t)node(s, val_ptr(f))->id << 1) : (uint64_t)f);
    }
    return h;
}
static int same_contents(Share *s, const Obj *a, const Obj *b) {
    if (obj_kind(a) != obj_kind(b) || obj_contag(a) != obj_contag(b) || obj_len(a) != obj_len(b)) return 0;
    if (!obj_has_fields(a)) return memcmp(obj_bytes_c(a), obj_bytes_c(b), raw_len(a)) == 0;
    for (uint32_t i = 0; i < obj_len(a); i++) {
        Value x = obj_field(a, i), y = obj_field(b, i);
        if (is_ptr(x) != is_ptr(y)) return 0;
        if (is_ptr(x) ? node(s, val_ptr(x))->id != node(s, val_ptr(y))->id : x != y) return 0;
    }
    return 1;
}
/* a number of its own, the object its first */
static int fresh(Share *s, Obj *o, uint32_t *id) {
    if (s->nreps == s->repcap) {
        size_t cap = s->repcap ? s->repcap * 2 : 1u << 16;
        Obj **r = realloc(s->reps, cap * sizeof *r);
        if (!r) return 0;
        s->reps = r; s->repcap = cap;
    }
    s->reps[s->nreps] = o;
    *id = (uint32_t)s->nreps++;
    return 1;
}
/* the number of an immutable object: that of the first object equal to it */
static int number(Share *s, Obj *o, uint32_t *id) {
    uint64_t h = contents_hash(s, o);
    size_t j = h & (s->ccap - 1);
    for (; s->classes[j] != UINT32_MAX; j = (j + 1) & (s->ccap - 1)) {
        Obj *r = s->reps[s->classes[j]];
        if (same_contents(s, r, o)) { *id = s->classes[j]; s->saved += obj_size(o); return 1; }
    }
    if (!fresh(s, o, id)) return 0;
    s->classes[j] = *id;
    return 1;
}

/* every object numbered, children first; 0 where memory ran out */
typedef struct { Obj *o; uint32_t i; } ShareFrame;
static int number_all(Share *s, Obj *root) {
    Node *n = node(s, root);
    if (n->state & 3) return 1;
    size_t sp = 0, cap = 1024;
    ShareFrame *st = malloc(cap * sizeof *st);
    if (!st) return 0;
    n->state = (uint8_t)((n->state & PINNED) | 1);
    st[sp++] = (ShareFrame){root, 0};
    while (sp) {
        ShareFrame *f = &st[sp - 1];
        Obj *o = f->o;
        if (obj_has_fields(o) && f->i < obj_scanned_fields(o)) {
            Value v = obj_field(o, f->i++);
            if (!is_ptr(v)) continue;
            Node *c = node(s, val_ptr(v));
            if (!c->o || (c->state & 3)) continue;
            c->state = (uint8_t)((c->state & PINNED) | 1);
            if (sp == cap) {
                ShareFrame *t = realloc(st, 2 * cap * sizeof *st);
                if (!t) { free(st); return 0; }
                st = t; cap *= 2; f = &st[sp - 1];
            }
            st[sp++] = (ShareFrame){val_ptr(v), 0};
            continue;
        }
        sp--;
        Node *me = node(s, o);
        int merge = mergeable(obj_kind(o)) && !(me->state & PINNED);
        /* a field whose object is still open is a cycle, which only a
           mutable object closes: the object keeps its identity */
        if (merge && obj_has_fields(o))
            for (uint32_t i = 0; i < obj_len(o); i++) {
                Value v = obj_field(o, i);
                if (is_ptr(v) && (node(s, val_ptr(v))->state & 3) == 1) { merge = 0; break; }
            }
        uint32_t id;
        if (!(merge ? number(s, o, &id) : fresh(s, o, &id))) { free(st); return 0; }
        me->id = id;
        me->state = (uint8_t)((me->state & PINNED) | 2);
    }
    free(st);
    return 1;
}

static Share *the_share;
static Obj *rep_of(Obj *o) {
    Node *n = node(the_share, o);
    return n->o ? the_share->reps[n->id] : o;
}
static void redirect_value(VM *vm, Value *v) {
    (void)vm;
    if (is_ptr(*v)) *v = mk_ptr(rep_of(val_ptr(*v)));
}
#define SHARE_VALUE(p) redirect_value(vm, (p))
#define SHARE_OBJ(p) (*(p) = rep_of(*(p)))

static int add_node(Share *s, Obj *o) { Node *n = node(s, o); n->o = o; n->id = 0; n->state = 0; return 1; }

uint64_t vm_share(VM *vm) {
    vm_collect(vm);
    /* every object, the large ones and any the nursery still has too */
    size_t count = 0;
    for (Chunk *c = heap_first(vm); c; c = c->next)
        for (size_t at = chunk_object(vm, c, 0); at != CHUNK_END; at = chunk_object(vm, c, at + obj_size((Obj *)(chunk_payload(c) + at))))
            count++;
    for (Obj *o = los_first(vm); o; o = los_next(vm, o)) count++;
    size_t young = vm->gc.nursery ? vm->alloc.used : 0;
    for (size_t at = 0; at < young; at += obj_size((Obj *)(vm->alloc.from + at))) count++;

    Share s;
    memset(&s, 0, sizeof s);
    for (s.ncap = 1024; s.ncap < count + count / 2; s.ncap *= 2) {}
    for (s.ccap = 1024; s.ccap < count + count / 2; s.ccap *= 2) {}
    s.nodes = calloc(s.ncap, sizeof *s.nodes);
    s.classes = malloc(s.ccap * sizeof *s.classes);
    if (!s.nodes || !s.classes) { free(s.nodes); free(s.classes); return 0; }
    memset(s.classes, 0xff, s.ccap * sizeof *s.classes);
    the_share = &s;
    for (Chunk *c = heap_first(vm); c; c = c->next)
        for (size_t at = chunk_object(vm, c, 0); at != CHUNK_END; at = chunk_object(vm, c, at + obj_size((Obj *)(chunk_payload(c) + at))))
            add_node(&s, (Obj *)(chunk_payload(c) + at));
    for (Obj *o = los_first(vm); o; o = los_next(vm, o)) add_node(&s, o);
    /* what the nursery has keeps its identity: an old object made to point
       at it would want the barrier */
    for (size_t at = 0; at < young; at += obj_size((Obj *)(vm->alloc.from + at))) {
        add_node(&s, (Obj *)(vm->alloc.from + at));
        node(&s, (Obj *)(vm->alloc.from + at))->state = PINNED;
    }
    int ok = 1;
    for (size_t j = 0; ok && j < s.ncap; j++)
        if (s.nodes[j].o) ok = number_all(&s, s.nodes[j].o);
    if (ok) {
        /* every field and root to the first object of its number */
        for (size_t j = 0; j < s.ncap; j++) {
            Obj *o = s.nodes[j].o;
            if (!o || !obj_has_fields(o)) continue;
            for (uint32_t i = 0; i < obj_scanned_fields(o); i++) redirect_value(vm, &obj_fields(o)[i]);
        }
        gc_stack_roots(vm, redirect_value);
        OTHER_ROOTS(vm, SHARE_VALUE, SHARE_OBJ);
    }
    uint64_t saved = ok ? s.saved : 0;
    the_share = NULL;
    free(s.nodes); free(s.classes); free(s.reps);
    if (ok) vm_collect(vm);
    return saved;
}
