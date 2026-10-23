# IntInf saved-policy fixture repair — 2026-10-23

The full check at `tests/out/r/20261023-112250-2501228` failed
`intinf/hardening/runtime`: the controller expected `bad IntInf policy` but
the patched image restored with exit 0. That failed receipt is preserved in
the delivery worktree; this successful rerun does not change its verdict.

Image format 15 inserts an eight-byte foreign identity floor after the image
kind. The fixture still patched the older policy offsets. Its old mode offset
28 changes the floating-point rounding-mode field; the old statistics offset
32 changes `heap_fill`. Neither mutation tests IntInf policy. An independent
replay of the old mode mutation with the current VM restored successfully,
reproducing the failure mechanism.

`IntInfHardening.savedPolicyLayout` now checks the exact image-15 header shape
and hexadecimal ISA fingerprint, then consumes the prefix's named fields in
order using their specified little-endian widths. It verifies a saved-image
kind, nonzero foreign identity floor and canonical saved policy before any
mutation. Unknown versions and truncated fields fail explicitly. The resulting
offsets, relative to the end of the NUL-terminated header, are:

| Field | Width | Image-15 offset |
| --- | --- | --- |
| IntInf backend mode | 4 | 36 |
| IntInf statistics | 4 | 40 |
| Magnitude limit | 8 | 60 |
| GMP memory limit | 8 | 68 |

The hardening report records its format version and located offsets.
`IntInfFaults` independently checks the expected image-15 positions and rejects
versions 14/16, a truncated prefix, a missing terminator, invalid fingerprint,
a fork image and a zero identity floor.

## Executed validation

The complete controller was rebuilt from the Makefile's `INTINF_SRCS` against
the current production library. The controller and every test artifact live
in the isolated release worktree. Runtime/compiler/native tools and fixtures
were read from the frozen production checkout through `RUNE_TEST_ROOT` and
`INTINF_*` overrides; no production source was edited.

| Check | Result |
| --- | --- |
| `rune-intinf.rbc hardening --native` | PASS, **63** bounded subprocesses, including interpreted and native real/emulated fork policy |
| `rune-intinf.rbc hardening --vm .../runevm-sml` | PASS, **37** bounded subprocesses |
| `rune-intinf.rbc faults` | PASS, including all new image-prefix guard cases |
| `rune-native-check.rbc native-images` | PASS, VM/native save/restore both directions and wrong-program refusal |
| `rune-test.rbc run 'limits/*' -j 2` | PASS, **7/7**: stack/register saved resource limits plus five runner canaries |
| `git diff --check` | PASS |

Both mode/statistics mutations now exit 2 with `bad IntInf policy`; the zero
and oversized magnitude/zero memory mutations exit 2 with `bad IntInf limits`.
The maximum 64-bit saved memory cap still restores successfully while the
restoring VM narrows it to the explicit 128-byte cap.

Commands, outcomes, located fields, bytecode/source/runtime hashes and the old
offset reproduction are retained in `intinf-image15.json`. Detailed subprocess
commands and streams remain under `tests/out/intinf-image15/`. The native image
and limits checks used their ordinary production controllers and current image
format. The failing full-check receipt remains distinct from these focused
successful checks.

The offset audit found no other saved-image byte patcher in tests/scripts/tools.
`src/opt/rbcimage.sml` already checks format 15 and consumes the identity floor
before its sequential policy reads. `IntInfStorage`'s fixed offsets address
independently assembled **RBC** fixtures, whose format did not change here.
