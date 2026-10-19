# rune-test

RESULT: FAIL 16524 of 16524 tests (2 SKIP, 16521 PASS, 1 FAIL), 3225.5 s wall, 11069.3 s CPU (86% of 4)

| Test | Verdict | Why | Kept |
|---|---|---|---|
| make/test-opt | FAIL | exit 2; FAIL opt.check tests/out/exp.record_captured_virtual.rbc: runeopt: tests/out/exp.record_captured_virtual.rbc: unsupported bytecode version; make: *** [Makefile:1305: test-opt] Error 1 | tests/out/r/20261019-080844-107915/failed/make__test-opt |

Slowest: make/check-layouts 213.2 s, errors/smlnj-legacy/err.ty_astra-inference-limit 188.8 s, errors/smlnj-dev/err.ty_astra-inference-limit 169.1 s, laws/MONO_ARRAY2@LargeIntArray2 108.1 s, lang/register-gc-low-pause-cycles/rt.gc_stress 99.7 s
