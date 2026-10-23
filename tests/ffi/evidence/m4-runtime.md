# M4 guarded-destruction runtime component

Date: 2026-10-23. This is component evidence; M4 remains open until target
layout consumption, marshalling/ownership helpers and full acceptance join.

The generic bridge adds native destructor transactions, native-address
comparison and liveness queries. Pointer arguments are leased during calls;
live views and active uses prevent destruction before native entry. A
native failure retains ownership for retry. A successful destructor retires
its identity once. Return/error capture precedes cleanup. The result-slot
reservation also survives registry growth during reentry.

* The original standalone C fixture passes **73** checks.
* `tests/runtime/foreign_dispose_test.c` passes **55** independent checks:
  busy views, active arguments, reads/views/release during destruction,
  recursive destruction, allocation failures, all integral failure policies,
  immutable error capture, stale identities and registry relocation.
  This is C reentry, not a claim of implemented SML callbacks.
* Basis/signature/language and generic runtime fixtures pass under stack and
  register interpretation, both JIT tiers, native execution and sanitizers.
  The final focused selection passes **125/125**; generated docs validate.
* Three initial language failures used stale instrumented VMs. Rebuilding
  them passed the focused **9/9** repair selection.
* Five initial sanitizer language cases exposed the fixture's direct lookup
  of libc `strdup` and `free`: `strdup` can allocate through an interposed
  allocator while a per-library lookup of `free` bypasses that interposition.
  The independent C program `tests/ffi/research/libc-asan.c`, with no Rune or
  libffi, reproduces the same `munmap_chunk(): invalid pointer` abort.
  The language fixture now checks pointer provenance without allocating
  across that symbol boundary; **62/62** language-path checks pass.
  Successful native allocation/destruction remains covered by `rf_copy` and
  `rf_free`, whose allocator calls share the fixture library's namespace,
  including sanitizer executions. No loader symbol special cases were added.

The failed initial selection is not counted as success. Full repository,
host matrix, Windows, stress and portability acceptance remain to be
recorded after this component's commit.

```sh
make test-ffi-runtime test-ffi-runtime-asan
bin/rune-test run 'basis/runeforeign*' 'lang/*/basis.runeforeign*' \
  'documentation/*' -j 6
```

The strict memory lease contract does not automatically permit destruction
of an opaque GUI handle from a synchronous window procedure. That requires
the callback/lifecycle protocol documented and tested in M5/M8.
