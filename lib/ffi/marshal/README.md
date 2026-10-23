# Foreign byte marshalling

Area: Foreign interfaces

Portable SML support for target integer, binary32 and binary64 representations,
explicit byte/text encodings and deterministic cleanup scopes. Native
addresses and VM operations belong to the runtime support library.

`ForeignBytes` always receives target byte order and object width.
`ForeignText` validates UTF-8, supports WTF-8, and preserves lone UTF-16
surrogate code units at Windows boundaries. Annotated extents bound every
read; terminators must lie inside them. Binary buffers use `Bytes` without
termination. UTF-16 surrogate pairs normalize to scalar UTF-8 on decoding.

`ForeignScope` attempts all cleanup actions in reverse registration order
on every returning path. An exception from the body takes precedence over
cleanup exceptions; a successful body propagates the first cleanup failure.
Actions are disarmed before running, so a failing action is never retried.
A cancelled ticket explicitly transfers cleanup responsibility to its caller.

Binary64 conversion uses the optional default-real packing structures and
checks their byte width. Rune supplies them; native SML/NJ hosts without
those structures have an explicit `HOST-ABSENT` record. Native MLKit's
known large `IntInf.~>>` fault is recorded separately from Rune validation.

Binary32 encoding rounds to nearest with ties to even, independently of native
floating-point environment changes. Overflow yields signed infinity; NaNs
receive a canonical quiet payload. Decoding widens finite binary32 values
exactly into the default binary64 real.
