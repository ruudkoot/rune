# Rune bytecode contract

The bytecode format is a portable interchange format between the Standard ML
compiler and the C runtime. It is not a dump of C or SML/NJ runtime values.

Every future instruction must document:

1. opcode and format version;
2. operand widths and signedness;
3. byte order;
4. stack/register effects;
5. allocation and control-flow effects;
6. malformed-input behavior;
7. compatibility impact.

The runtime must validate the complete bytecode header and instruction stream
before execution when validation is requested. Execution of malformed input
must fail with a structured status, never undefined behavior.

The initial format is version 1. Each program starts with the five-byte header
`RUNE` followed by version byte `1`. Integers and byte offsets are unsigned
big-endian 32-bit operands; integer values are signed two's-complement
32-bit values. The current opcodes are:

| Opcode | Operand | Stack effect |
| --- | --- | --- |
| `0` Halt | none | terminates successfully |
| `1` PushInt | signed 32-bit integer | `-> int` |
| `2` PushBool | byte `0` or `1` | `-> bool` |
| `3` Load | local index | `-> value` |
| `4` Store | local index | `value ->` |
| `5`-`8` arithmetic | none | `int int -> int` |
| `9`-`14` comparison | none | `value value -> bool` |
| `15` JumpFalse | absolute byte offset | `bool ->` |
| `16` Jump | absolute byte offset | `->` |
| `17` Pop | none | `value ->` |

The VM rejects invalid headers, truncated operands, invalid local indices,
stack underflow, type-incompatible operations, and out-of-range jumps.
