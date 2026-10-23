# Raw outgoing variadic calls — 2026-10-23

Component `17c471463` closes the roadmap's explicit `ffi_prep_cif_var`
contract. `RuneForeign.prepareVariadic` retains a complete scalar signature
and a nonempty fixed prefix. Callers supply C-promoted tail types and values;
unpromoted tails, invalid counts and nondefault ABIs reject before entry.
An empty tail still uses the variadic CIF. Prepared calls are explicitly
reused and released; no format-string inference or variadic callback is added.
Generic operation 18 extends the existing primitive without changing the ISA
or adding a primitive per bound function.

The shared preparation path preserves symbol/library dependencies, active
pointer leases, captured native errors and callback exception containment.
Read-only review found no implementation defect and requested the additional
mixed and fixed-prefix tests recorded below.

Executed on Linux x86-64:

- Standalone generic runtime: **89/89 checks**, also **89/89** under ASan/UBSan,
  including each prepared-call allocation failure and rejected interfaces.
- Strict C99 disabled runtime: PASS, including deterministic ENOSYS for
  variadic preparation without libffi.
- Independent direct C oracle: **31 checks**. Its mixed variadic subject
  validates wide signed/unsigned bits and an exact `958.5` result.
- Expanded `tests/ffi/calls.sml`: PASS in stack interpretation and register
  off/baseline/optimizing modes, all with collection stress 7 and heap
  verification. Baseline and optimizing runs force compilation after one call.
- The same four executions PASS with instrumented VMs and an ASan/UBSan
  instrumented native provider, including LeakSanitizer at exit.
- The mixed subject leaves Float32/SInt8 fixed arguments unpromoted and
  passes 84 interleaved tail arguments through GP/FP registers and the stack:
  int, double, signed/unsigned 64-bit, object/function/context pointers.
  Twelve callbacks force full collection while its native `va_list` is live.
- Empty tails, multiple complete signatures, repeated calls, arity/type
  rejection, parent-release guards and stale-call rejection PASS; every
  successful fixture ends with zero live native resources.
- The new language fixture uses the platform C library's real `sprintf`
  with pointer/int/double arguments, checks `-42:0.25`, rejects an unpromoted
  float, and releases every resource. Optimizing JIT/stress execution PASS.
- Documentation generation and `make check-docs`: **11/11 PASS**, run
  `20261023-115406-464`, 19.6 seconds.

The first documentation attempt incorrectly set `RUNE` and `RUNE_STACK`
to the same temporary wrapper path. Make overwrote it with a recursive
stack wrapper; the two verified processes were terminated. The corrected
invocation uses distinct paths and passes. This was a local command error,
not a successful check or a repository workaround.

Reproduction uses the ordinary runtime coordinator after building its
prerequisites; it includes the expanded provider, C oracle and SML fixture:

```sh
bin/rune-ffi-check native
bin/rune-ffi-check runtime native
bin/rune-ffi-check runtime asan
```

Cross-target and cumulative acceptance are recorded separately after final
integration; these local results do not stand for those gates.
