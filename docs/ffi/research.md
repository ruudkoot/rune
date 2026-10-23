# Runeffi research record (2026-10-22)

The [roadmap comparison](../plans/runeffi.md#research-and-design-consequences)
records the adopted and rejected ideas from No-Longer-Foreign, the modular
FFI paper, MLton, Poly/ML, Python ctypes and the libffi manual. This record
pins the implementation evidence used for M0; agreement is a cross-check,
not a replacement for a declared Rune contract.

| Reference source | Reviewed revision | Consequence |
|---|---|---|
| SML/NJ `libraries/ckit`, `tools/nlffi` | `6c476227198c39566a23fb9aa2952dc268006138` | Separate reusable C syntax/types from FFI projection. Retain abstract types; do not require C lvalue encodings in the idiomatic API. Modern headers require new extension coverage. |
| MLton `mlnlffigen`, guide FFI types | `b15e2d289c3d701131733665a74e2dd8438410b6` | Target widths are explicit. MLton's direct imports exclude tuple/datatype representations and strings need explicit terminators. Do not copy its compiler syntax, static linking or heap assumptions. |
| Poly/ML `basis/Foreign.sml` | `4557554077078decce4ce5f90da00a713cfc32e4` | Separate symbol/call objects, conversions and callback allocation. Explicitly release Rune registrations; the compatibility `buildClosure` operations persist for a process and are not Rune's lifecycle contract. |
| OCaml source reference | `46e1c324fb9e9f21f52c9cc3399020f7ef8b9b91` | Compiler representation is not a foreign binding specification. The modular FFI paper supplies the separation of specification from implementation, rather than OCaml compiler internals. |
| Python ctypes runtime | CPython 3.12.3 | Specify signatures, keep callbacks strongly referenced, copy owned results before freeing; implicit attachment of foreign threads is not adopted. |
| libffi | 3.4.6, pinned release manifest | Reuse CIFs, struct descriptors, promoted variadic lists and closures. None supplies SML roots, ownership, error timing or a VM callback delimiter. |

Executable comparisons use `tests/ffi/fixture.c`, independent of the Rune
VM. `oracle.c` exercises 24 direct C checks and 39 checks when built with
`RUNEFFI_TEST_LIBFFI`. Both ctypes and Poly/ML cover an exact signed 64-bit
scalar, `{int32_t,double}` returned by value, an owned returned string with
its matching deallocator, and a retained callback explicitly unregistered
before exit. Poly/ML runs with the repository-pinned **5.9.2** host. Its
compatibility closure lasts until the comparison process exits. Rune must
provide deterministic release instead.

Reproduction from the repository root:

```sh
make test-ffi-contracts test-ffi-libffi JOBS=8
cc -std=c17 -Wall -Wextra -Werror -pedantic -fPIC -shared \
  tests/ffi/fixture.c -o build/libruneffi-subject.so
python3 tests/ffi/research/python_ctypes.py build/libruneffi-subject.so
RUNEFFI_FIXTURE="$PWD/build/libruneffi-subject.so" \
  "$HOME/.local/rune-hosts/polyml/bin/poly" --script tests/ffi/research/polyml.sml
make test-ffi-windows JOBS=8
```

The comparison does not assert callback-exception or worker-thread behavior
for those other runtimes. Rune's stricter boundary is specified in
[contracts.md](contracts.md) and exercised by the callback and lifecycle
fixtures recorded in [M5 evidence](../../tests/ffi/evidence/m5.md).
