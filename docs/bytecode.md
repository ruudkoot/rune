# Rune bytecode (`.rbc`) and VM

`rune` emits a single `.rbc` file per program (basis library included);
`runevm` loads, validates and interprets it. The instruction set and the
primitives are described in `src/isa/stack.sml` and `src/isa/prims.sml`,
from which `runeisa` writes `vm/opcodes.def`, `vm/prims.def` and the tables
of the VM and the compiler; `make check-docs` verifies every opcode and
primitive they define is mentioned here.

## File format

All integers are little-endian. `u8`/`u32`/`i32`/`i64` are unsigned 8-bit,
unsigned 32-bit, signed 32-bit and signed 64-bit two's complement.

```
magic       4 bytes   "RUNE"
version     u32       3
fingerprint u32       of the instruction set the file is of (below)
nconsts     u32
consts      nconsts × constant
nglobals    u32       number of global slots
nfuncs      u32
funcs       nfuncs × { code_offset u32, nlocals u32, name_len u32, name bytes }
            # name is what the source called the function, qualified by the
            # structures it is in (`StringCvt.padLeft`); `fn` where nothing
            # names it, `while` for the loop of a while, `<toplevel>` for the
            # program itself. `--disasm` and a fatal error print it.
code_len    u32
code        code_len bytes
nfiles      u32
files       nfiles × { len u32, bytes }      # the sources, as given on the command line
nlines      u32
table_len   u32
lines       table_len bytes                  # nlines entries; see below
nnames      u32
names       nnames × { len u32, bytes }      # of the functions inlined, each once
ninlined    u32
frames_len  u32
frames      frames_len bytes                 # ninlined frames; see below
```

The version is `4`, and it changes when the layout does (`rbcVersion` in
`src/isa/stack.sml`). A file of version `1`, which has no debug section,
`2`, which has no fingerprint, or `3`, whose line table knows nothing of
inlined functions, is refused like any other version the VM does not
know.

**The fingerprint** says which instruction set a file is of. `runeisa`
works it out from the descriptions of `src/isa` -- the instructions' names,
operands, stack effects and flow, and the primitives' names and arities, in
order -- and writes it into the generated tables; a VM refuses a file of
another instruction set with "bytecode of another instruction set", and an
image of one (whose magic carries the fingerprint) as not an image of this
`runevm`. So an opcode or a primitive may be added, removed or moved: a file
made before is refused rather than read with another meaning.

**The line table** says where each instruction came from, which is what
`--disasm` prints beside it and what a stack trace reads. Its entries are in
order of `pc`, and each holds the position of the instructions from its `pc`
up to the next entry's; the entry covering a `pc` is the last one that begins
at or before it. Every function's code begins with an entry of its own, so an
instruction is never attributed to whatever was compiled before it.

An entry is five numbers -- the difference in `pc`, in file, in line, in
column and in inlined frame from the entry before it, counting from
`0, 0, 0, 0, 0`. Each is written
seven bits at a time, least significant first, with the top bit of a byte
saying that another follows; the three that may be negative are folded to a
natural number first (`n` becomes `2n`, and `-n` becomes `2n - 1`) so that a
small difference stays one byte either way. The table is about four bytes an
entry, and costs 14% of a file: `examples/nqueens.rbc` is 46,672 bytes where
without it it would be 41,077. A variable, a constant, a selector and a
`_prim` carry no position of their own -- none of them can fail or call, so
the position of whatever contains them is the one worth having -- which is
what keeps the table to that, and the compiler within its budgets.

The loader refuses a table that does not decode, that has bytes left over, or
whose `pc` is past the code, whose file is not one the table names, or whose
line or column is below 1 (`tests/vm`). The positions themselves are the
compiler's business: `make check-positions` verifies that every one of them
names a line its file really has.

**Inlined functions.** Where the compiler put a function's code into
another's (middle-end M10), the entries of that code name the function it
came from: their fifth number is a frame of the `frames` table, numbered
from 1 (0: none). A frame is the inlined function's name, where it was
called from, and the frame that call is itself in (0: none; always an
earlier frame): five natural numbers, written seven bits at a time as the
line table's are -- the name's place in `names`, the file, the line, the
column, and the frame. A trace (`vm_print_trace`, `Runtime.trace`) shows each as a
frame of its own: the inlined function at the entry's position, then the
function it was called from at the frame's place, and so on out to the
function whose code it is -- the frames the program would show had nothing
been inlined. A frame inlined in tail position has no place (file, line
and column 0): it took the place of the function it was called from, as a
tail call's frame does, and that function is not shown. The loader
refuses a frame that does not decode, whose name or file is not one the
tables have, or whose parent is not earlier, and a table with bytes left
over.

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
| CON | tag, 1 field or n | datatype constructors with an argument: its argument, or, where the constructor's declared argument is a tuple of n, those n fields (`CONN`; lists: `::` is tag 1 of head and tail, `nil` is `CON0 0`) |
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
doubles whenever it is more than half full after a collection, or the share
`runevm --heap-fill P` gives, P percent.

## Machine state

* value stack (operands and frame locals; grows on demand),
* frame stack: `{function, return pc, base, closure}`; local `l` is `stack[base + l]`,
* handler stack: `{handler pc, saved sp, saved frame}`,
* globals, constants, and eight builtin exception constructors:
  `0 Match, 1 Bind, 2 Overflow, 3 Div, 4 Subscript, 5 Size, 6 Chr, 7 Domain`.

Calling convention: push the closure, push the argument, `CALL`. The callee's
frame has the argument in local 0 and the remaining locals initialised to
`unit`; `RET` pops the frame and pushes the result. `TAILCALL` reuses the
current frame. A function called through a closure takes exactly one
argument (curried functions are nested closures; tuples are passed as one
value). A function the compiler knows -- one of the top level -- is called
without a closure: push its `n` arguments and `CALLK f, n`, and they are its
locals 0 to `n-1`; the frame has no closure, so such a function reads no
`ENV` or `SELF`. Every known call of a function passes it the same number of
arguments.

Exceptions: `PUSHHANDLER o` records the current stack and frame depth; `RAISE`
pops the innermost handler, restores its depths, pushes the exception value and
jumps to `o`. If no handler exists the VM prints
`runevm: uncaught exception NAME [payload]` and exits with status 1.

## Instructions

Each instruction is one opcode byte followed by zero or more `i32` operands.
Opcode numbers are assigned in the order of `src/isa/stack.sml`.

| Opcode | Operands | Effect |
|---|---|---|
| `HALT` | | Stop execution. |
| `CONST k` | constant index | Push constant `k`. |
| `INT i` | immediate | Push the int `i` (immediates are kept within ±2^30). |
| `UNIT` | | Push `()`. |
| `CON0 t` | tag | Push nullary constructor `t`. |
| `LOCAL l` / `SETLOCAL l` | slot | Push / pop frame local `l`. |
| `TEELOCAL l` | slot | Store the top of stack into local `l` and leave it there: `SETLOCAL l; LOCAL l` in one. |
| `ENV e` | slot | Push slot `e` of the current closure's environment. |
| `SELF` | | Push the current closure (used for self-recursion). |
| `GLOBAL g` / `SETGLOBAL g` | global | Push / pop global `g`. Reading an unset global is a fatal error. |
| `POP` | | Discard the top of stack. |
| `TUPLE n` | count | Pop `n` values (first pushed is field 0) and push a tuple; `n = 0` pushes `()`. |
| `SELECT i` | index | Pop a tuple, push field `i`. |
| `CON t` | tag | Pop a value, push `t` applied to it. |
| `DECON t` | tag | Pop a constructor value, of tag `t`, push its argument. The tag is tested only under `runevm --checked`. |
| `CONN t, n` | tag, count | Pop `n` values (first pushed is field 0) and push `t` made of them: one object of `n` fields, the tag in its header -- how a constructor whose argument is a tuple of `n` is made (`src/backend/rep.sml`). |
| `FIELD t, i` | tag, index | Pop a constructor value that `CONN` made, of tag `t`, push its field `i`. The tag is tested only under `runevm --checked`. |
| `CONTAG` | | Pop a constructor value (nullary or not), push its tag as an int. |
| `CLOSURE f, n` | function, count | Pop `n` values into the environment of a new closure of function `f`. |
| `SETENV e` | slot | Pop value `v`, pop closure `c`, set `c.env[e] := v` (patches mutually recursive closures). |
| `CALL` / `TAILCALL` | | Pop argument, pop closure, call (replacing the frame for `TAILCALL`). |
| `CALLK f, n` / `TAILCALLK f, n` | function, count | Call function `f` with the `n` values on top of the stack as its locals 0 to `n-1`, and no closure (replacing the frame for `TAILCALLK`); `n` is at most `f`'s locals. |
| `RET` | | Return the top of stack to the caller. |
| `JUMP o` | offset | Jump to absolute code offset `o`. |
| `JUMPIFNOT o` / `JUMPIF o` | offset | Pop a bool, jump if false / true. |
| `JUMPIFNOTTAG o, t` | offset, tag | Pop a constructor value (nullary or not), jump unless its tag is `t`: what `CONTAG; INT t; PRIM poly_eq; JUMPIFNOT o` does, in one instruction, which is how the compiler tests a constructor in a match. |
| `SWITCH n` | count | Pop a constructor value; where its tag `t` is below `n`, jump to the target of the `t`-th of the `n` `JUMP`s that follow it (a table, never run itself), else go on after them. The loader checks that they are `JUMP`s of the same function. |
| `PUSHHANDLER o` / `POPHANDLER` | offset | Install / remove an exception handler. |
| `RAISE` | | Pop an exception value and raise it. |
| `NEWEXN k` | string constant | Create a fresh exception constructor named `k`. |
| `BUILTINEXN i` | 0–7 | Push builtin exception constructor `i`. |
| `MKEXN` | | Pop payload, pop constructor, push an exception value. |
| `EXNCON` / `EXNARG` | | Pop an exception value, push its constructor / payload. |
| `PRIM p` | primitive | Invoke primitive `p`: pops its arguments (first pushed is the first argument) and pushes the result, or raises. |

## The register bytecode (vm/new)

`vm/new`'s loop (`bin/runevm-new`, `vm/new/interp.c`; `vm/new/ARCHITECTURE.md`
is the VM as built) runs a second instruction set, of 41 registers
instructions (`src/isa/regs.sml`; decision D4 of
[plans/middle-end.md](plans/middle-end.md)). `rune --target=registers` makes
it, from `-O1`. Its `.rbc` is laid out as the stack bytecode's, with the
register instruction set's fingerprint (`vm/new/regs.def`), so that each VM
refuses the other's file and image.

* **Registers** are the slots of the frame, from its base: register 0 is the
  argument (registers 0 to `n-1` the arguments of a known call), the others
  start as `unit`, and `nlocals` of the function table
  is their number. The collector sees every one, as it sees the locals of the
  stack bytecode, since the stack pointer stays above them. Above them a
  frame pushes only the arguments of a primitive, a call's result and the
  exception a raise leaves: the loader works out how deep that goes
  (`maxstack`: the widest primitive, or 1), a call makes room for it, and
  the loop's pushes do not check.
* **Operands** are `i32`, as in the stack bytecode; an instruction that takes
  a list of registers (`TUPLE`, `CLOSURE`, `PRIM`) has them last, as many as
  its count says or as its primitive's arity.
* **Calls** leave their result on the stack, as the stack bytecode's do, and
  the instruction after the call takes it into a register (`RESULT`); a
  handler's code begins with `CATCH`, which takes the exception a raise left
  there. `vm/new` shares `runevm`'s runtime this way (`build/librune.a`).
  The loop's `RET` writes the value into the register of the `RESULT` the
  caller goes on at and passes over that `RESULT`, so `--count` counts one
  instruction fewer for each call than the code has; a program resumed from
  an image at a `RESULT` takes its value from the stack as before.
* **Primitives** done in the loop: the common case of the primitives
  `runeopt` does in line (`runeopt --inlined`; [native.md](native.md)) is
  done from the registers, with nothing pushed (`vm/new/fastprim.h`), and
  the primitive itself is called for the rest -- an overflow, a divisor of
  zero, an index out of bounds. The result is the primitive's either way,
  which `scripts/check-new.sh` holds `tests/opt/prims.sml` to on both VMs.
* **A primitive that saves or restores an image** (`rt_save`, `rt_restore`,
  `posix_fork`) is `PRIMPUSH` and `RESULT`, so that a program resumed from
  an image finds its result where `RESULT` takes it.
* **The JIT** (`docs/plans/jit.md`; `vm/new/ARCHITECTURE.md`, The driver):
  `--jit=off|baseline|opt|all` says which functions get native code,
  `--jit-stats` prints at exit what the JIT did, and `--jit-check` runs a
  few bytes of code from executable memory and exits. `runevm` refuses all
  three: the JIT is `vm/new`'s.

| Opcode | Operands | Effect |
|---|---|---|
| `HALT` | | Stop execution. |
| `MOVE d s` | registers | `d := s`. |
| `INT d i` | register, immediate | `d :=` the int `i`. |
| `CONST d k` | register, constant | `d :=` constant `k`. |
| `UNIT d` / `CON0 d t` | register, tag | `d := ()` / the nullary constructor `t`. |
| `GLOBAL d g` / `SETGLOBAL g s` | register, global | `d :=` global `g` / global `g := s`. |
| `ENV d e` / `SELF d` | register, slot | `d :=` slot `e` of the running closure / the running closure. |
| `CALL f x` / `TAILCALL f x` | registers | Call the closure in `f` with `x` (replacing the frame for `TAILCALL`). |
| `CALLK f n a...` / `TAILCALLK f n a...` | function, count, registers | Call function `f` with the registers `a...` as its registers 0 to `n-1`, and no closure (replacing the frame for `TAILCALLK`). |
| `RESULT d` | register | `d :=` what the call or `PRIMPUSH` before it left. |
| `RET s` | register | Return `s` to the caller. |
| `PRIM p d a...` | primitive, register, registers | `d :=` primitive `p` of the registers `a...`, or raise; the common case of some in the loop. |
| `PRIMPUSH p a...` | primitive, registers | Primitive `p` of `a...`, its result left for `RESULT`. |
| `TUPLE d n a...` | register, count, registers | `d :=` a tuple of `a...`; `n = 0` gives `()`. |
| `CLOSURE d f n a...` | register, function, count, registers | `d :=` a closure of function `f` capturing `a...`. |
| `SELECT d i s` | register, index, register | `d :=` field `i` of the tuple in `s`. |
| `CON d t s` / `DECON d s t` / `CONTAG d s` | registers, tag | Build a constructor value / take the argument of one of tag `t` (tested only under `--checked`) / its tag as an int. |
| `CONN d t n a...` / `FIELD d s t i` | registers, tag, count or index | As the stack bytecode's: `d :=` constructor `t` made of the fields `a...` / field `i` of the constructor value in `s`, of tag `t` (tested only under `--checked`). |
| `NEWEXN d k` / `BUILTINEXN d i` | register, string constant or 0–7 | A fresh exception constructor named `k` / builtin constructor `i`. |
| `MKEXN d c x` / `EXNCON d s` / `EXNARG d s` | registers | An exception value / its constructor / its payload. |
| `SETENV c e v` | register, slot, register | `c.env[e] := v` (patches mutually recursive closures). |
| `JUMP o` | offset | Jump to `o`. |
| `JUMPIF s o` / `JUMPIFNOT s o` | register, offset | Jump if `s` is true / false. |
| `JUMPIFNOTTAG s o t` | register, offset, tag | Jump unless the constructor value in `s` has tag `t`. |
| `SWITCH s n` | register, count | As the stack bytecode's `SWITCH`, on the constructor value in `s`. |
| `PUSHHANDLER o` / `POPHANDLER` | offset | Install / remove an exception handler. |
| `CATCH d` | register | `d :=` the exception a raise left for the handler this begins. |
| `RAISE s` | register | Raise the exception in `s`. |

## Primitives

Primitive numbers follow the order of `src/isa/prims.sml`. The basis library binds
them with `_prim "name" : ty`. Type errors in primitive arguments are fatal VM
errors (they cannot happen for programs produced by `rune`); SML exceptions are
raised as noted.

| Group | Primitives |
|---|---|
| Polymorphic | `poly_eq` (structural equality; refs/arrays/closures by identity), `ptr_eq` (identity), `exn_name` (the constructor name of an exception value), `imm_eq` (the equality of two values never in the heap -- ints, words, chars, nullary constructors of a type that has no other -- by tag and bits, which the compiler makes of `poly_eq` where it knows the type is one of those) |
| System (`vm/sys.h`, ISO C99 core plus `vm/sys_posix.c`, `vm/sys_win.c` or `vm/sys_none.c`) | `sys_errno sys_error_msg sys_error_name sys_error_of_name` (the last failure, its text and its POSIX name), `time_now time_user time_sys time_sleep` (microseconds), `time_gc_user time_gc_sys` (the processor time the collector has taken, which the VM adds up around every collection, for `Timer.checkCPUTimes` and `checkGCTime`), `date_parts date_seconds date_offset date_format` (broken-down time as a nine-element `int list`: second, minute, hour, day, month 0–11, year − 1900, weekday, day of the year, daylight saving; `date_format` is `strftime` in the C locale, written in the core so that it is the same everywhere, which asks the system only for the name of the local zone), `os_system os_getenv`, the file system (`os_mkdir os_rmdir os_chdir os_getcwd os_remove os_rename os_access os_file_kind os_link_kind os_file_size os_mod_time os_set_time os_read_link os_real_path os_tmp_name os_file_id`), directories (`os_open_dir os_read_dir os_rewind_dir os_close_dir`) and descriptors (`os_desc_kind os_poll`). POSIX itself: `posix_const` gives the value of a named constant (an errno, a signal, a flag of `open`, a bit of a file mode), and the rest are the calls behind `Posix` (`posix_fork posix_exec posix_exece posix_waitpid posix_kill posix_alarm posix_pause posix_exit`, the last ending the process with nothing flushed; where the system has no fork, `posix_fork` starts a second VM and hands it this one's state (`vm/image.c`); `posix_spawn` starts a program with three descriptors as its standard streams, as fork, dup2 and exec would, without the fork (`Unix.execute`); `posix_lock` is `fcntl` with a `struct flock` (the locks of `Posix.IO`), `posix_pathconf` is `pathconf`/`fpathconf` with the limit named without its `_PC_` prefix, and `posix_utime` sets both times of a file; `posix_tcgetattr`, `posix_tcsetattr` and `posix_tcop` are the calls on a terminal (`Posix.TTY`), the process and user numbers (`posix_getpid posix_getppid posix_getuid posix_geteuid posix_getgid posix_getegid posix_setuid posix_setgid posix_getgroups posix_getlogin posix_getpgrp posix_setsid posix_setpgid`), `posix_uname posix_times posix_environ posix_ctermid posix_ttyname posix_isatty posix_sysconf`, `posix_openf posix_close posix_dup posix_dup2 posix_pipe posix_read posix_write posix_lseek posix_fsync posix_fcntl posix_ftruncate posix_stat posix_chmod posix_chown posix_link posix_symlink posix_mkfifo posix_umask posix_getpw posix_getgr`). Sockets: `socket_create socket_pair socket_bind socket_connect socket_listen socket_accept socket_send socket_sendto socket_recv socket_recvfrom socket_shutdown socket_name socket_peer socket_getopt socket_setopt`, the addresses (`socket_inet_addr socket_unix_addr socket_addr_family socket_inet_parts socket_unix_path`, which keep an address as the bytes of a `sockaddr`, with `socket_inet6_addr` and `socket_inet6_parts` for the `sockaddr_in6` of IPv6 (`INet6Sock`)), the options that are no `int` (`socket_linger`, a `struct linger`; `socket_query`, `FIONREAD` and `sockatmark`) and the databases (`netdb_host_byname netdb_host_byaddr netdb_hostname netdb_proto_byname netdb_proto_bynumber netdb_serv_byname netdb_serv_byport`). A call that fails gives `~1`, or `""` or `[]`, and leaves the reason in `sys_errno` |
| Windows (`lib/basis/windows.sml`; `vm/sys_win.c`, `ENOSYS` on every other system) | The registry (`win_reg_open win_reg_close win_reg_delete win_reg_enum win_reg_query win_reg_set`, a key being a number of the system layer, the seven at the roots 0 to 6), the machine (`win_config win_version win_volume`), the shell (`win_find_executable win_shell_execute`), programs started with one command line (`win_spawn`) and waited for with the whole code they end with (`win_wait`), and dynamic data exchange (`win_dde_start win_dde_execute win_dde_stop`) |
| Runtime (`lib/basis/runtime.sml`) | The counters the VM keeps for the program it runs, each reading one field and allocating nothing: `rt_instructions` (what `--count` prints), `rt_bytes` and `rt_objects` (allocated since the start, collected or not), `rt_collections`, `rt_live` (the bytes of the current semispace in use) and `rt_heap_size` (one semispace); `rt_collect`, which collects the heap on demand; and `rt_version`, the version the VM was built as, which `--version` prints and `scripts/gen-build-files.sh` writes into `vm/version.h` and `build/config.sml` alike; `rt_trace` gives the frames of the call stack, innermost first, leaving out the innermost n of them, each as its function's name and the position it is stopped at (the line table above); `rt_save` writes the whole VM to a file for `runevm --restore`, and `rt_restore` makes this VM become the world in such a file, bytecode and all, so that it does not come back (`vm/image.c`) |
| Real, from the C library (ISO C99) | `real_floor_r real_ceil_r real_trunc_r real_round_r` (integral reals; `real_round_r` rounds ties to even in every rounding mode), `real_sign_bit`, `real_copy_sign`, `real_to_bits real_from_bits` (the 64 bits of IEEE 754 binary64, for `PackReal`), `real_to_single real_single_from_string` (rounding to IEEE 754 binary32 and C `strtof`, for `Real32`), `real_frexp_man real_frexp_exp real_ldexp` (`frexp`, `ldexp`), `real_next_after`, `real_rem` (`fmod`), `real_fmt_e real_fmt_f` (`printf` `%.*e` and `%.*f` of a finite real; `Size` for a precision that is negative or above 100000), `real_shortest` (the `%.*e` text with the fewest digits that reads back as the same real), `real_set_round real_get_round` (0 nearest, 1 downward, 2 upward, 3 toward zero), `real_sinh real_cosh real_tanh` |
| Int (64-bit, `Overflow` checked) | `int_add int_sub int_mul int_div int_mod int_quot int_rem int_neg int_abs int_lt int_le int_gt int_ge int_order int_to_string int_from_string int_to_char int_to_real` — `int_div/int_mod` floor, `int_quot/int_rem` truncate, both raise `Div` on zero; `int_to_char` raises `Chr`; `int_order` gives `LESS`, `EQUAL` or `GREATER`, and so do `word_order`, `char_order` and `string_order`, which `compare` of each structure is bound to |
| Word (64-bit, wrapping) | `word_add word_sub word_mul word_div word_mod word_lt word_le word_gt word_ge word_order word_neg word_andb word_orb word_xorb word_notb word_lsl word_lsr word_to_int word_to_int_x word_from_int word_to_string` — `word_div/word_mod` raise `Div`; `word_to_int` raises `Overflow`; `word_to_string` is uppercase hex |
| Real (IEEE double) | `real_add real_sub real_mul real_div real_neg real_abs real_lt real_le real_gt real_ge real_eq real_floor real_ceil real_round real_trunc real_to_string real_from_string real_sqrt real_exp real_ln real_sin real_cos real_tan real_atan real_atan2 real_pow real_is_nan` — conversions to int raise `Overflow`/`Domain`; `real_to_string` prints SML syntax (`~`, `E`) with 12 significant digits |
| Char | `char_ord char_lt char_le char_gt char_ge char_order` |
| String (8-bit) | `string_size string_sub string_concat string_extract string_lt string_le string_gt string_ge string_compare string_order string_from_char string_implode string_explode string_concat_list` — `string_sub`/`string_extract` raise `Subscript`; `string_compare` returns −1/0/1 |
| Ref / array / vector | `ref_new ref_get ref_set array_new array_length array_sub array_update array_from_list vector_from_list vector_length vector_sub` — `array_new`, `array_from_list` and `vector_from_list` raise `Size` for a length that is negative or above 100000000 (`Array.maxLen`, `Vector.maxLen`); indexing raises `Subscript` |
| I/O and system | `print print_err flush_out input_line input_all exit command_args command_name` — `input_line` returns `string option`; `exit` terminates the process |
| Files | `file_open file_close file_write file_flush file_read_line file_read_all file_error` — handles are ints: 0 stdin, 1 stdout, 2 stderr, others from `file_open (path, mode)` (mode 0 read, 1 write/truncate, 2 append; returns `int option`). `file_write` returns `false` when the handle is invalid or the write fails, and flushes stdout before writing to handle 2; `file_read_line`/`file_read_all` behave like `input_line`/`input_all` (`NONE`/`""` for an invalid handle); `file_read_vec (h, n)` reads at most `n` bytes (`""` at end of file, `Size` for a negative `n`); `file_avail` is what a seekable file has left, `~1` for anything else; `file_error` and `file_errno` are the text and the number of the last failure; `file_tell` and `file_seek` are `ftell` and `fseek` from the start (`~1` for a file without positions, a pipe or a terminal); `file_descriptor` is the descriptor of the system under a handle, which is what an `OS.IO.iodesc` holds and what `os_poll`, `os_desc_kind`, `posix_isatty` and `posix_ttyname` take |

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
* `runevm --checked file.rbc` makes `DECON` test the tag it is given and
  stop the program where the value has another. A match that names every
  constructor of a datatype leaves the last untested (decision D14 of
  plans/middle-end.md), so a wrong tag would otherwise go unseen; the test
  suites run so (`tests/run-tests.sh`, `make check-levels`);
* `runevm --heap-size N file.rbc` sets the initial semispace size in bytes;
* `runevm --heap-fill P file.rbc` grows the heap after a collection until at
  most P percent of it is in use (1 to 100, 50 by default);
* `runevm --emulate-fork file.rbc` makes `posix_fork` what it is on Windows,
  which has no fork: a second `runevm` is started as `runevm --resume` and
  handed the whole state of this one (`vm/image.c`), and it carries on with
  `fork` returning 0. `tests/lang/rt.fork_image` runs so, under ASan and
  `make test-stress` too;
* `Runtime.restore` does the same from inside a program that is already
  running, so that it becomes another world; an image is therefore checked as
  a `.rbc` is -- its opcodes, its operands, its jump targets, and the places
  the world it holds is stopped at -- before anything of it runs;
* `runevm --restore FILE` carries on the world that `Runtime.save` wrote to
  FILE, which comes back from that call as `Restored` where the world that
  wrote it had `Saved`. It is the same format a fork is handed, which nothing
  in it ties to a machine: an image written by `bin/runevm` is restored by
  `bin/runevm32.exe`. What the system layer holds -- a socket, a directory
  stream, a pipe -- goes to a fork's child and not into a file, so a restored
  world does not have them; the files the program opened come back by name,
  put where they were left (`tests/lang/rt.save_restore`);
* `rune --dump-code file.sml` prints the generated code with symbolic labels
  before serialization; `--dump-lambda` prints the intermediate representation.
