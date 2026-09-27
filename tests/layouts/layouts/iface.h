/* iface.h -- the interface every layout header (L0.h .. L4.h) implements.
   This file is documentation: it defines nothing but the dispatch on
   -DLAYOUT=LX. Kernels include harness.h, which includes the chosen
   layout, which includes gc_core.h in the middle (the representation first,
   the collector, then the allocating constructors).

   TYPES
     val         a value: the layout's word (16-byte struct in L0, uint64_t
                 elsewhere). Passed and returned by value.
     obj         a heap object with a header (opaque struct; fields follow
                 the header). str = obj (a K_STRING).
     A "position" is a field, a local or an argument. MONO positions are
     those whose type the compiler knows to be int/real (rep INT/REAL in
     src/backend/rep.sml); POLY positions have a type variable ('a) there.
     Only L4 tells them apart; in L0-L3 both are the same tagged val.

   IMMEDIATES (never allocate in L0; may allocate in L1-L4 as noted)
     val mk_unit(void)                  unit
     val mk_int(int64_t)                an int the layout can hold immediate
                                        (L2/L3: boxed when it cannot; L4: raw)
     int is_int(val)                    L0: tag test; L1-L3: low-bit / high-bits
                                        test (an int, immediate or boxed);
                                        L4: 1 (untyped raw word)
     int64_t unbox_int(val)             the int (tests for the box in L2/L3)
     val mk_word(uint64_t); uint64_t unbox_word(val)
                                        L1: ALWAYS a K_BOX (Word64 is a boxed
                                        type in L1); L2/L3: boxed when > 63/48
                                        bits; L0/L4: free
     val mk_char(int); int unbox_char(val)
     val mk_con0(int tag); int con0_tag(val)   a nullary constructor
     val mk_bool(int); int unbox_bool(val)
     val mk_real(double); double unbox_real(val)
                                        L0/L3/L4: free; L1/L2: K_BOX (with
                                        -DREALIMM: Koka's A1 encoding when the
                                        exponent fits 10 bits, else a box)
     val NIL                            mk_con0(0); int is_nil(val)
   TYPE-DIRECTED POSITIONS (macros)
     MONO_INT(x)  MONO_REAL(x)          the value at a MONO position:
                                        mk_int/mk_real in L0-L3, raw in L4
     MONO_INT_OF(v) MONO_REAL_OF(v)     read back
     POLY_VAL_INT(x) POLY_VAL_REAL(x)   the value at a POLY position: mk_*
                                        in L0-L3; L4: a K_BOX under
                                        -DL4_UNIFORM, raw under -DL4_MONO
     POLY_INT_OF(v) POLY_REAL_OF(v)     read back
     POLY_PTRBIT                        1 when a POLY int occupies a pointer
                                        field (all but L4_MONO); the field
                                        mask bit for such a field
   ARITHMETIC on tagged values, overflow-checked (SML Overflow -> nonzero)
     int add_ov(val a, val b, val *r); sub_ov; mul_ov
                                        L2: a 63-bit overflow boxes instead
                                        of raising; only 64-bit overflow raises
   OBJECTS
     obj *alloc(int kind, int contag, uint32_t nfields, uint32_t ptrmask)
                                        bump + gc; fields uninitialised;
                                        ptrmask (bit i = field i is a
                                        pointer) is used by L4 only
     size_t alloc_size(int kind, int contag, uint32_t n)   the bytes alloc will take
     obj *alloc_bytes(uint32_t len)     a K_STRING of len bytes
     val field_get(obj *, uint32_t i); void field_set(obj *, uint32_t i, val)
                                        field_set is THE write-barrier hook:
                                        a plain store, or with -DBARRIER_CARD
                                        a card-mark byte store beside it
     uint32_t obj_len(obj *); int obj_kind(obj *); int obj_contag(obj *)
     val ptr_val(obj *)                 the val of a headered object
     int is_ptr(val); obj *ptr_of(val)  (ptr_of strips L5's tag bits)
     int con_tag(val)                   constructor tag of a CON/CONN val
                                        (header contag; L5: pointer bits)
   PAIRS (2-field immutable CON/TUPLE objects; headerless under -DPAIRS)
     val mk_pair(int kind, int contag, val a, val b, uint32_t ptrmask)
     val pair_get(val p, int i)         field i of a pair val
     val cons(val hd, val tl)           mk_pair(K_CON, 1, hd, tl, POLY_PTRBIT|2)
     val cons_p(val hd, val tl)         a cons whose head is a pointer (mask 3)
     val head(val); val tail(val)
   REFS, ARRAYS, CLOSURES, STRINGS
     obj *ref_new(val v, int isptr); val ref_get(obj *); void ref_set(obj *, val)
     obj *array_new(uint32_t n, val init, int isptr); array_get/array_set
     obj *real_array_new(n)             a real array: boxed elements in L1/L2
                                        (and L4_UNIFORM) unless -DFLATREAL
     void real_array_set(obj *, i, double); double real_array_get(obj *, i)
     obj *char_array_new(n)             a CharArray: one val per char (16 B in
                                        L0, 8 B in L1-L4) unless
                                        -DCOMPACTBYTES (1 B)
     void char_array_set(obj *, i, int c); int char_array_get(obj *, i)
     val closure_new(int fn, int nfree, const val *env, uint32_t envmask)
     val closure_call(val clo, val arg) fntab[fn](clo, arg) through a volatile
                                        pointer to the table, as the VM's CALL
     val closure_env(obj *clo, int i)
     int poly_eq(val a, val b)          structural equality (L4: driven by the
                                        header's pointer mask)
     str *string_new(uint32_t len); char *string_bytes(str *); uint32_t string_len(str *)
     val string_concat(val a, val b); val string_sub(val s, uint32_t i, uint32_t n)
     int string_compare(val a, val b)   String.compare: memcmp then length
   ROOTS (shadow stacks; the collector's only roots)
     val *PROOT_PUSH(val v)             push a pointer/tagged value; returns
                                        its slot (the collector updates it)
     val *RROOT_PUSH(val v)             push a raw MONO value (L4: the raw
                                        stack; elsewhere the same stack)
     val *IROOT_PUSH(val v)             push a POLY int (L4_MONO: raw stack)
     ROOT_POP(); RROOT_POP(); IROOT_POP()
     ROOT_MARK / ROOT_RESET(m)          save/restore the stack tops
   HEAP
     void heap_init(size_t semispace_bytes); void heap_reset(void)
     void gc_collect(size_t need)       the collector; gc_cycles/gc_count
     int heap_fits(size_t bytes)        room without a collection
   The kernels keep live values in root slots across allocations; the fast
   path of an allocation does not spill (as native code with a stack map
   would not), the slow path collects and every root slot is updated.
   Layout-specific hooks used by gc_core.h are prefixed lay_. */
#ifndef HARNESS_IFACE_H
#define HARNESS_IFACE_H
#define LAYOUT_ID_L0 0
#define LAYOUT_ID_L1 1
#define LAYOUT_ID_L2 2
#define LAYOUT_ID_L3 3
#define LAYOUT_ID_L4 4
#define LAYOUT_CAT_(a, b) a##b
#define LAYOUT_CAT(a, b) LAYOUT_CAT_(a, b)
#ifndef LAYOUT
#error "build with -DLAYOUT=L0 .. L4"
#endif
#define LAYOUT_ID LAYOUT_CAT(LAYOUT_ID_, LAYOUT)
#endif
