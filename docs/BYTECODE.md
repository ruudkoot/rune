# Rune bytecode, version 3

Version 3 adds constructor values, constructor tests/payload access, and uncaught
match failures for M5a. The writer, disassembler, and VM reject v1/v2 and unknown
versions; source programs must be recompiled. The v2 header/section layout and
opcodes 0–33 are preserved. CALL and TAILCALL additionally accept unary
constructor functions. Fields remain explicitly little-endian on every platform.

M5b lists reuse these instructions and representations without a format or VM
behavior change. Existing v3 files remain compatible, and bytecode containing
lists runs on the M5a v3 VM. Recompilation can change constructor descriptors
because the compiler now installs the initial list constructors before user
declarations; descriptors are local to a bytecode file, not a cross-file ABI.

The VM is an ISO C11 stack interpreter requiring 8-bit bytes and exact 32- and
64-bit integer types. M2 introduced version 2; M3 collection and the Rune 0.1.0
M4 checks retained it. See [BUILD.md](BUILD.md#portability-checks) and the
[implementation checkpoint](PLAN.md) for tested targets and remaining gaps.

## Encoding

### Constructor representation

A descriptor is `2 * constructor ID + arity`, where IDs are assigned first to
the initial list constructors (`nil`: ID 0, `::`: ID 1), then in lexical user
declaration order, are less than 65,536, and arity is 0 or 1. Operands must be
less than 131,072; PAYLOAD additionally requires odd parity. Descriptors are
explicit u32 fields, independent of host word width. IDs are static identities;
datatype declarations have no runtime allocation or generative exception state.
The loader checks operand ranges, stack effects and branch joins; FAIL is a
terminal instruction allowed at any stack height. Unreachable instructions
still receive ordinary operand validation.

Nullary values and unary constructor functions are scalar VM tags. Applying a
unary constructor allocates an aggregate containing its descriptor and one
traced payload value, with the argument explicitly rooted across collection.
CALL and TAILCALL support constructor functions. IS_CON accepts either datatype
value tag; PAYLOAD checks both the unary value tag and exact descriptor before
reading. These checks prevent malformed bytecode from reading invalid storage;
bytecode validation does not prove nominal source types or global consistency
of descriptors. Equality compares descriptors then recursively compares payloads
using the existing bounded iterative worklist; constructor functions reject
equality. The existing aggregate collector traces unary values without recursive
C traversal. Aggregate heap accounting and the current local-retention policy
also apply to constructor payloads and match temporaries.

### File layout

All unsigned integer fields are little-endian. No alignment or padding is used.

| Field | Encoding |
| --- | --- |
| Magic | Eight bytes: `RUNEBC\r\n` |
| Version | u32, currently 3 |
| Entry function | u32, must be 0 |
| Functions | u32, 1 through 65,536 |
| String constants | u32, at most 65,536 |
| Source filename | u32 byte length, then bytes (basename only) |
| String pool | Each constant: u32 byte length, then bytes |
| Functions, in ID order | u32 local count, u32 environment count, u32 instruction count, then code |
| Code | Each instruction: u8 opcode, u32 operand, u32 line, u32 column |

Each function starts at its instruction zero. Function 0 has no argument or
closure environment and completes with HALT (or terminates with FAIL). Every
other function has at least one local: slot 0 initially holds its unary argument. Other locals start uninitialized.
The current closure supplies immutable environment slots and SELF. Functions
return one value with RETURN, transfer control with TAILCALL, or terminate with FAIL.

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
| 34 | CONSTRUCTOR | constructor | 0 | 1 |
| 35 | IS_CON | constructor | 1 | 1 |
| 36 | PAYLOAD | constructor | 1 | 1 |
| 37 | FAIL | failure | 0 | 0 |
<!-- opcodes:end -->

Binary operations pop right then left operands. STORE consumes a value; LOAD
copies it. CALL consumes a function followed by its argument, returning one value.
Built-in IDs are 0 = `print`, 1 = `Int.toString`, 2 = `not`, 3 = `~`.
JUMP_FALSE consumes a boolean and branches when false. HALT ends execution.

ENV copies a captured value. SELF copies the current closure. CLOSURE consumes
captures in ascending environment-slot order and constructs a closure for a
non-entry function. RETURN restores the caller and pushes the result. TAILCALL
replaces the current frame; a tail call to a built-in or constructor function returns its result directly.
Calls use explicit VM frames, never recursive C interpreter calls.

TUPLE consumes at least two elements, in source order. GET replaces a tuple with
its zero-based indexed element. DUP duplicates the top operand. CHECK_UNIT
consumes a unit; CHECK_TUPLE checks the exact arity without consuming the tuple.
Tuple values, constructor payloads, and closure environments are immutable.

CONSTRUCTOR pushes a nullary value for an even descriptor or a unary constructor
function for an odd descriptor. IS_CON replaces a datatype value with the
boolean result of descriptor comparison. PAYLOAD replaces a matching unary
value with its payload. FAIL 0 reports `uncaught exception Match`; FAIL 1 reports
`uncaught exception Bind`. Both use the instruction source position and exit 3.

Signed integer arithmetic is checked. `div` rounds down, and `mod` has the
divisor's sign. The minimum integer divided by `~1` raises `Overflow`; its
remainder is zero. Equality is structural for tuples and datatypes of equality values and is
also defined for integers, booleans, strings, and unit. Functions do not admit
equality. Arithmetic exceptions terminate with status 3.

## Limits and errors

Bytecode files are limited to 16 MiB and strings to 1 MiB each. There are at most
65,536 functions, string constants, and instructions (summed across functions).
Each function has at most 65,536 locals and captured values. Tuple arity,
operand stack values, active local slots, and active frames are capped at 65,536.
Frames and locals grow on demand and are reused by tail calls.
Managed allocations for strings (including constants and source metadata), tuples,
closures, and unary constructor values are limited to 64 MiB by default, including object headers. This
ceiling excludes bytecode storage, VM stacks, and the C allocator's internal
overhead. Equality uses an explicit work stack of at most 65,536 pairs and permits
at most 1,000,000 comparison steps per operation.

The VM uses non-moving mark-and-sweep collection. It traces the source
filename, constants, active operand/local slots, active frame closures, and
explicit temporary C roots. Tuple fields, constructor payloads, and closure captures are traced;
an intrusive iterative worklist handles sharing and cycles without C recursion
or extra allocations during collection. Uninitialized slots and unused capacity
are not roots. Initialized locals remain roots until overwritten or until their
frame returns or is replaced; the compiler does not emit last-use information.

Only managed allocation can trigger collection. Tuple fields and closure captures
stay on the operand stack until construction finishes. Concatenation temporarily
pushes its two popped operands back onto that traced stack while allocating and
copying the result. Unary constructor calls similarly push their popped payload
argument while allocating. These temporary roots reuse slots already freed by
the dispatcher: CONCAT, CALL, and TAILCALL each pop two operands first. They do
not increase the instruction's peak operand-stack usage, and the helpers restore
the stack depth before returning. This rooting strategy leaves bytecode v3 and
its instruction semantics unchanged; existing v3 files remain compatible.

Frame growth, user-closure entry, returns, and equality do not perform managed
allocations. The allocating built-in
`Int.toString` consumes only an integer. New objects are initialized and published
to roots before the next allocation. Loading also obeys this rule. Collector tests create
cycles internally: immutable Rune values and SELF currently cannot construct them.

Collection starts with a 64 KiB threshold, capped by the selected heap ceiling.
After collection the threshold is twice the retained allocation size, with the
same floor and ceiling. The VM collects before exceeding the threshold, retries
a failed C heap allocation after collection, and reports `heap limit exceeded`
if retained objects plus the requested allocation exceed the ceiling. All sizes
include object headers, which can vary across C platforms. Remaining memory is
freed at exit.

`--heap-limit BYTES` selects a ceiling from 1 through 67,108,864 bytes using decimal
digits; invalid values are usage errors. `--gc-stress` collects before every
managed allocation, including during loading. Options precede the program path;
`--` ends option parsing. Heap exhaustion while loading has no source position;
exhaustion while executing includes the current instruction's source position.

Allocation failure is reported. Bytecode format errors exit with status 2;
runtime failures exit with status 3; usage and file I/O errors use status 1.
Output is flushed and checked before successful exit.

The compiler's disassembler validates encoding and indexes; the VM additionally
performs control-flow stack verification. This VM is not an execution sandbox
for hostile code. Incompatible encoding or semantic changes require a version
increment and new compatibility/rejection fixtures.
