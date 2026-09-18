# Rune bytecode (`.rbc`) and VM

`rune` emits a single `.rbc` file per program (basis library included);
`runevm` loads, validates and interprets it. The instruction set and primitive
table are generated from `vm/opcodes.def` and `vm/prims.def`; those files are
the source of truth and `make check-docs` verifies every opcode and primitive
they define is mentioned here.

## File format

All integers are little-endian. `u8`/`u32`/`i32`/`i64` are unsigned 8-bit,
unsigned 32-bit, signed 32-bit and signed 64-bit two's complement.

```
magic       4 bytes   "RUNE"
version     u32       1
nconsts     u32
consts      nconsts × constant
nglobals    u32       number of global slots
nfuncs      u32
funcs       nfuncs × { code_offset u32, nlocals u32, name_len u32, name bytes }
code_len    u32
code        code_len bytes
```

A constant is a `u8` kind followed by its payload:

| kind | payload | value |
|---|---|---|
| 0 | `i64` | int |
| 1 | `i64` | word (reinterpreted as unsigned) |
| 2 | `u32 len`, ASCII | real, in C `strtod` syntax |
| 3 | `u32 len`, bytes | string |
| 4 | `u8` | char |

Functions are listed in increasing `code_offset`; a function's code extends to
the next function's offset (or the end of the code). Function 0 is the program
entry point: the VM calls it with argument `()` and halts when it returns.
`nlocals ≥ 1` is the frame size; local 0 is the argument.

The loader rejects files with unknown opcodes, truncated instructions, jump
targets that are not instruction boundaries, and out-of-range constant, global,
function, local, primitive or builtin-exception operands.

## Values

Every value is a 16-byte tagged cell: `unit`, `int` (64-bit), `word` (64-bit),
`real` (double), `char`, a nullary constructor (`CON0` with its tag) or a
pointer to a heap object. Heap objects:

| kind | contents | used for |
|---|---|---|
| TUPLE | n fields | tuples, records (fields in canonical label order), vectors |
| CON | tag, 1 field | datatype constructors with an argument (lists: `::` is tag 1, `nil` is `CON0 0`) |
| CLOSURE | function index, environment fields | functions |
| STRING | bytes | strings |
| REF | 1 field | `ref` cells (identity equality) |
| ARRAY | n fields | arrays (identity equality) |
| EXN | constructor, payload | exception values |
| EXNCON | name string | exception constructors; identity is the address |

Booleans are `CON0 0` (`false`) and `CON0 1` (`true`). Records store their
fields sorted by label (numeric labels first, in numeric order, then
alphabetic), so a tuple `(a, b)` and the record `{1 = a, 2 = b}` are the same
object. Options are `CON0 0` (`NONE`) and `CON 1 x` (`SOME x`).

The heap is managed by a Cheney semispace copying collector; the semispace
doubles whenever it is more than half full after a collection.

## Machine state

* value stack (operands and frame locals; grows on demand),
* frame stack: `{function, return pc, base, closure}`; local `l` is `stack[base + l]`,
* handler stack: `{handler pc, saved sp, saved frame}`,
* globals, constants, and eight builtin exception constructors:
  `0 Match, 1 Bind, 2 Overflow, 3 Div, 4 Subscript, 5 Size, 6 Chr, 7 Domain`.

Calling convention: push the closure, push the argument, `CALL`. The callee's
frame has the argument in local 0 and the remaining locals initialised to
`unit`; `RET` pops the frame and pushes the result. `TAILCALL` reuses the
current frame. Every function takes exactly one argument (curried functions
are nested closures; tuples are passed as one value).

Exceptions: `PUSHHANDLER o` records the current stack and frame depth; `RAISE`
pops the innermost handler, restores its depths, pushes the exception value and
jumps to `o`. If no handler exists the VM prints
`runevm: uncaught exception NAME [payload]` and exits with status 1.

## Instructions

Each instruction is one opcode byte followed by zero or more `i32` operands.
Opcode numbers are assigned in the order of `vm/opcodes.def`.

| Opcode | Operands | Effect |
|---|---|---|
| `HALT` | | Stop execution. |
| `CONST k` | constant index | Push constant `k`. |
| `INT i` | immediate | Push the int `i` (immediates are kept within ±2^30). |
| `UNIT` | | Push `()`. |
| `CON0 t` | tag | Push nullary constructor `t`. |
| `LOCAL l` / `SETLOCAL l` | slot | Push / pop frame local `l`. |
| `ENV e` | slot | Push slot `e` of the current closure's environment. |
| `SELF` | | Push the current closure (used for self-recursion). |
| `GLOBAL g` / `SETGLOBAL g` | global | Push / pop global `g`. Reading an unset global is a fatal error. |
| `POP` | | Discard the top of stack. |
| `TUPLE n` | count | Pop `n` values (first pushed is field 0) and push a tuple; `n = 0` pushes `()`. |
| `SELECT i` | index | Pop a tuple, push field `i`. |
| `CON t` | tag | Pop a value, push `t` applied to it. |
| `DECON` | | Pop a constructor value, push its argument. |
| `CONTAG` | | Pop a constructor value (nullary or not), push its tag as an int. |
| `CLOSURE f, n` | function, count | Pop `n` values into the environment of a new closure of function `f`. |
| `SETENV e` | slot | Pop value `v`, pop closure `c`, set `c.env[e] := v` (patches mutually recursive closures). |
| `CALL` / `TAILCALL` | | Pop argument, pop closure, call (replacing the frame for `TAILCALL`). |
| `RET` | | Return the top of stack to the caller. |
| `JUMP o` | offset | Jump to absolute code offset `o`. |
| `JUMPIFNOT o` / `JUMPIF o` | offset | Pop a bool, jump if false / true. |
| `PUSHHANDLER o` / `POPHANDLER` | offset | Install / remove an exception handler. |
| `RAISE` | | Pop an exception value and raise it. |
| `NEWEXN k` | string constant | Create a fresh exception constructor named `k`. |
| `BUILTINEXN i` | 0–7 | Push builtin exception constructor `i`. |
| `MKEXN` | | Pop payload, pop constructor, push an exception value. |
| `EXNCON` / `EXNARG` | | Pop an exception value, push its constructor / payload. |
| `PRIM p` | primitive | Invoke primitive `p`: pops its arguments (first pushed is the first argument) and pushes the result, or raises. |

## Primitives

Primitive numbers follow the order of `vm/prims.def`. The basis library binds
them with `_prim "name" : ty`. Type errors in primitive arguments are fatal VM
errors (they cannot happen for programs produced by `rune`); SML exceptions are
raised as noted.

| Group | Primitives |
|---|---|
| Polymorphic | `poly_eq` (structural equality; refs/arrays/closures by identity), `ptr_eq` (identity), `exn_name` (the constructor name of an exception value) |
| Int (64-bit, `Overflow` checked) | `int_add int_sub int_mul int_div int_mod int_quot int_rem int_neg int_abs int_lt int_le int_gt int_ge int_to_string int_from_string int_to_char int_to_real` — `int_div/int_mod` floor, `int_quot/int_rem` truncate, both raise `Div` on zero; `int_to_char` raises `Chr` |
| Word (64-bit, wrapping) | `word_add word_sub word_mul word_div word_mod word_lt word_le word_gt word_ge word_neg word_andb word_orb word_xorb word_notb word_lsl word_lsr word_to_int word_to_int_x word_from_int word_to_string` — `word_div/word_mod` raise `Div`; `word_to_int` raises `Overflow`; `word_to_string` is uppercase hex |
| Real (IEEE double) | `real_add real_sub real_mul real_div real_neg real_abs real_lt real_le real_gt real_ge real_eq real_floor real_ceil real_round real_trunc real_to_string real_from_string real_sqrt real_exp real_ln real_sin real_cos real_tan real_atan real_atan2 real_pow real_is_nan` — conversions to int raise `Overflow`/`Domain`; `real_to_string` prints SML syntax (`~`, `E`) with 12 significant digits |
| Char | `char_ord char_lt char_le char_gt char_ge` |
| String (8-bit) | `string_size string_sub string_concat string_extract string_lt string_le string_gt string_ge string_compare string_from_char string_implode string_explode string_concat_list` — `string_sub`/`string_extract` raise `Subscript`; `string_compare` returns −1/0/1 |
| Ref / array / vector | `ref_new ref_get ref_set array_new array_length array_sub array_update array_from_list vector_from_list vector_length vector_sub` — `array_new`, `array_from_list` and `vector_from_list` raise `Size` for a length that is negative or above 100000000 (`Array.maxLen`, `Vector.maxLen`); indexing raises `Subscript` |
| I/O and system | `print print_err flush_out input_line input_all exit command_args command_name` — `input_line` returns `string option`; `exit` terminates the process |
| Files | `file_open file_close file_write file_flush file_read_line file_read_all file_error` — handles are ints: 0 stdin, 1 stdout, 2 stderr, others from `file_open (path, mode)` (mode 0 read, 1 write/truncate, 2 append; returns `int option`). `file_write` returns `false` when the handle is invalid or the write fails, and flushes stdout before writing to handle 2; `file_read_line`/`file_read_all` behave like `input_line`/`input_all` (`NONE`/`""` for an invalid handle); `file_error` is the C `strerror` text of the last failure |

## Tools

* `runevm --disasm file.rbc` prints constants, globals and code;
* `runevm --trace file.rbc` traces every instruction to stderr;
* `runevm --stats file.rbc` prints heap statistics at exit;
* `runevm --count file.rbc` prints the instructions executed and the bytes and
  objects allocated at exit (also after the `exit` primitive and an uncaught
  exception). The numbers depend on the program and its input only, not on
  the machine or the heap size, so they serve as performance budgets;
* `runevm --gc-stress N file.rbc` collects before every Nth allocation. With
  N = 1 every allocation moves every live object, which exposes a primitive
  that keeps a heap pointer in a C variable across an allocation
  (`make test-stress`);
* `runevm --heap-size N file.rbc` sets the initial semispace size in bytes;
* `rune --dump-code file.sml` prints the generated code with symbolic labels
  before serialization; `--dump-lambda` prints the intermediate representation.
