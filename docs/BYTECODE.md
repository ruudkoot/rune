# Rune bytecode, version 1

Version 1 supports the M1 expression language. The VM is an ISO C11 stack
interpreter requiring 8-bit bytes and exact 32- and 64-bit integer types.

## Encoding

All unsigned integer fields are little-endian. No alignment or padding is used.

| Field | Encoding |
| --- | --- |
| Magic | Eight bytes: `RUNEBC\r\n` |
| Version | u32, currently 1 |
| Local slots | u32, at most 65,536 |
| String constants | u32, at most 65,536 |
| Instructions | u32, 1 through 65,536 |
| Source filename | u32 byte length, then bytes (basename only) |
| String pool | Each constant: u32 byte length, then bytes |
| Code | Each instruction: u8 opcode, u32 operand, u32 line, u32 column |

The entry point is instruction zero; this version has one implicit function.
Integers use 32-bit two's-complement bit encoding. Strings preserve embedded NUL.
Source filenames cannot contain NUL. Line and column numbers are one-based byte
positions. Output contains no timestamps or absolute source paths.

Branches name absolute instruction indexes and must go forward. Unused operands
must be zero. The loader checks the whole file, including unreachable instruction
encodings, and verifies stack heights on reachable control-flow paths. It checks
that reachable HALT instructions have an empty stack and paths cannot fall off
the code. Runtime checks cover tags and uninitialized locals; loading does not
perform a full static type proof.

## Instructions

Generated from `spec/opcodes.tsv`; `make check-docs` checks for drift.

<!-- opcodes:start -->
| Code | Instruction | Operand | Pops | Pushes |
| --- | --- | --- | --- | --- |
| 0 | HALT | none | 0 | 0 |
| 1 | INT | int | 0 | 1 |
| 2 | BOOL | bool | 0 | 1 |
| 3 | UNIT | none | 0 | 1 |
| 4 | STRING | constant | 0 | 1 |
| 5 | BUILTIN | builtin | 0 | 1 |
| 6 | LOAD | local | 0 | 1 |
| 7 | STORE | local | 1 | 0 |
| 8 | POP | none | 1 | 0 |
| 9 | ADD | none | 2 | 1 |
| 10 | SUB | none | 2 | 1 |
| 11 | MUL | none | 2 | 1 |
| 12 | DIV | none | 2 | 1 |
| 13 | MOD | none | 2 | 1 |
| 14 | CONCAT | none | 2 | 1 |
| 15 | EQ | none | 2 | 1 |
| 16 | NE | none | 2 | 1 |
| 17 | LT | none | 2 | 1 |
| 18 | LE | none | 2 | 1 |
| 19 | GT | none | 2 | 1 |
| 20 | GE | none | 2 | 1 |
| 21 | CALL | none | 2 | 1 |
| 22 | JUMP | target | 0 | 0 |
| 23 | JUMP_FALSE | target | 1 | 0 |
<!-- opcodes:end -->

Binary operations pop right then left operands. STORE consumes a value; LOAD
copies it. CALL consumes a built-in function followed by its argument, returning
one value. Built-in IDs are 0 = `print`, 1 = `Int.toString`, 2 = `not`, 3 = `~`.
JUMP_FALSE consumes a boolean and branches when false. HALT ends execution.

Signed integer arithmetic is checked. `div` rounds down, and `mod` has the
divisor's sign. The minimum integer divided by `~1` raises `Overflow`; its
remainder is zero. Equality is defined for integers, booleans, strings, and unit;
function equality is rejected. Arithmetic exceptions terminate with status 3.

## Limits and errors

Bytecode files are limited to 16 MiB, strings to 1 MiB each, local and operand
stacks to 65,536 values, and arena allocations to 64 MiB including metadata.
The M1 VM frees the arena at process exit; garbage collection arrives in M3.
Allocation failure is reported. Bytecode format errors exit with status 2;
runtime failures exit with status 3; usage and file I/O errors use status 1.
Output is flushed and checked before successful exit.

The compiler's disassembler validates encoding and indexes; the VM additionally
performs the control-flow stack verification. This VM is not an execution sandbox
for hostile code. Incompatible encoding or semantic changes require a version
increment and new compatibility/rejection fixtures.
