# Rune bytecode, version 2

Version 2 adds explicit functions, closures, tuples, and call frames for M2.
The VM is an ISO C11 stack interpreter requiring 8-bit bytes and exact 32- and
64-bit integer types. Version 1 files must be recompiled: the v2 VM and
disassembler reject v1 and unknown versions. Opcode numbers 0–23 are preserved,
but CALL now also accepts user closures and branches are function-relative.

## Encoding

All unsigned integer fields are little-endian. No alignment or padding is used.

| Field | Encoding |
| --- | --- |
| Magic | Eight bytes: `RUNEBC\r\n` |
| Version | u32, currently 2 |
| Entry function | u32, must be 0 |
| Functions | u32, 1 through 65,536 |
| String constants | u32, at most 65,536 |
| Source filename | u32 byte length, then bytes (basename only) |
| String pool | Each constant: u32 byte length, then bytes |
| Functions, in ID order | u32 local count, u32 environment count, u32 instruction count, then code |
| Code | Each instruction: u8 opcode, u32 operand, u32 line, u32 column |

Each function starts at its instruction zero. Function 0 has no argument or
closure environment and ends with HALT. Every other function has at least one
local: slot 0 initially holds its unary argument. Other locals start uninitialized.
The current closure supplies immutable environment slots and SELF. Functions
return one value with RETURN or transfer control with TAILCALL.

Integers use 32-bit two's-complement bit encoding. Strings preserve embedded NUL.
Source filenames cannot contain NUL. Line and column numbers are one-based byte
positions. Output contains no timestamps or absolute source paths. Functions and
captures use deterministic binding/traversal order.

Branches name instruction indexes within the current function and must go forward.
Unused operands must be zero. The loader checks all instruction encodings,
including unreachable instructions, and verifies reachable stack heights from
entry to every function. Branches cannot cross functions. HALT is only legal in
function 0 with an empty stack; RETURN and TAILCALL are only legal in other
functions, with exactly one and two operands respectively. Paths cannot fall off
code. Runtime checks cover tags, tuple shape, and uninitialized locals; loading
does not perform a full static type proof.

## Instructions

Generated from `spec/opcodes.tsv`; `make check-docs` checks for drift. A pops value
of -1 means a dynamic count: CLOSURE consumes the target function's environment
count, and TUPLE consumes its arity operand.

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
| 24 | ENV | environment | 0 | 1 |
| 25 | SELF | none | 0 | 1 |
| 26 | CLOSURE | function | -1 | 1 |
| 27 | RETURN | none | 1 | 0 |
| 28 | TAILCALL | none | 2 | 0 |
| 29 | TUPLE | arity | -1 | 1 |
| 30 | GET | index | 1 | 1 |
| 31 | DUP | none | 1 | 2 |
| 32 | CHECK_UNIT | none | 1 | 0 |
| 33 | CHECK_TUPLE | arity | 1 | 1 |
<!-- opcodes:end -->

Binary operations pop right then left operands. STORE consumes a value; LOAD
copies it. CALL consumes a function followed by its argument, returning one value.
Built-in IDs are 0 = `print`, 1 = `Int.toString`, 2 = `not`, 3 = `~`.
JUMP_FALSE consumes a boolean and branches when false. HALT ends execution.

ENV copies a captured value. SELF copies the current closure. CLOSURE consumes
captures in ascending environment-slot order and constructs a closure for a
non-entry function. RETURN restores the caller and pushes the result. TAILCALL
replaces the current frame; a tail call to a built-in returns its result directly.
Calls use explicit VM frames, never recursive C interpreter calls.

TUPLE consumes at least two elements, in source order. GET replaces a tuple with
its zero-based indexed element. DUP duplicates the top operand. CHECK_UNIT
consumes a unit; CHECK_TUPLE checks the exact arity without consuming the tuple.
Tuple values and closure environments are immutable.

Signed integer arithmetic is checked. `div` rounds down, and `mod` has the
divisor's sign. The minimum integer divided by `~1` raises `Overflow`; its
remainder is zero. Equality is structural for tuples of equality values and is
also defined for integers, booleans, strings, and unit. Functions do not admit
equality. Arithmetic exceptions terminate with status 3.

## Limits and errors

Bytecode files are limited to 16 MiB and strings to 1 MiB each. There are at most
65,536 functions, string constants, and instructions (summed across functions).
Each function has at most 65,536 locals and captured values. Tuple arity,
operand stack values, active local slots, and active frames are capped at 65,536.
Frames and locals grow on demand and are reused by tail calls.
Arena allocations for strings, tuples, and closures are limited to 64 MiB,
including metadata. Equality uses an explicit work stack of at most 65,536 pairs and permits at most
1,000,000 comparison steps per operation.

The M2 VM frees the arena at process exit; garbage collection arrives in M3.
Tail calls bound frame space; allocations can still exhaust the arena.
Allocation failure is reported. Bytecode format errors exit with status 2;
runtime failures exit with status 3; usage and file I/O errors use status 1.
Output is flushed and checked before successful exit.

The compiler's disassembler validates encoding and indexes; the VM additionally
performs control-flow stack verification. This VM is not an execution sandbox
for hostile code. Incompatible encoding or semantic changes require a version
increment and new compatibility/rejection fixtures.
