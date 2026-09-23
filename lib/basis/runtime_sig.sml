(* What a program can ask about the machine it is running on: how much work it
   has done, and how much memory that took.

   The VM keeps these counters whether or not a program asks for them --
   `runevm --count` and `runevm --stats` print them when it ends -- so reading
   one costs a call and nothing else. None of them allocates, which is what
   makes the six numbers of a `stats` one consistent set: nothing but an
   allocation moves the numbers of the heap, so they cannot drift apart while
   they are being read.

   This signature is Rune's own. Nothing here is portable, and a program that
   only wants the time a computation took should use `Timer`, which is.

   Area: The runtime

   Status: extension

   Deviation: `RUNTIME/not-in-the-specification`. The specification says
   nothing about the implementation a program is running on: it has no
   structure for allocation, for collection, or for what a call costs, and
   deliberately so, since those are where implementations differ most. This
   signature is therefore Rune's alone and a program that uses it does not
   port. What the specification does give is `Timer`, whose `checkGCTime` is
   the one thing it says about a collector.

   See also: `TIMER`, `OS_PROCESS` *)
signature RUNTIME =
sig
  (* The counters of the VM, all of them since the program started.

     `instructions` is the bytecode instructions executed, `bytes` and
     `objects` what has been allocated in the heap -- including everything
     since collected -- and `collections` the number of collections made.

     `live` is the bytes of the current semispace that are in use: what the
     last collection kept, plus what has been allocated since. It is an upper
     bound on the live data, and is exactly the live data just after a
     collection. `heapSize` is the size of one semispace, which grows as the
     collector needs it to.

     The first four depend on the program and its input alone -- not on the
     machine, the pointer width, the heap size or when the collector ran --
     so two runs of one program report the same. The last two depend on the
     heap size and so on `runevm --heap-size`.

     A value is 16 bytes and an object costs an 8-byte header and a payload
     rounded up to 16, so the smallest object is 24 bytes and a list cell,
     which is two objects, is 64. *)
  type stats = { instructions : int, bytes : int, objects : int,
                 collections : int, live : int, heapSize : int }

  (* `stats ()` is the counters as they stand.

     Reading them is itself work, so two calls with nothing between them do
     not report the same `instructions`. Nothing between them allocates,
     though, so the other five agree. *)
  val stats : unit -> stats

  (* `profile f` is what `f ()` returned, and what it cost: the difference
     between the counters after it and the counters before.

     What measuring costs is part of the answer, so `profile (fn () => ())`
     is not zero -- it is that cost, and subtracting it from another answer
     removes it. It is the same number on every run and on every VM, since
     the counters depend on the program and its input alone.

     If `f` raises, the exception passes through and there are no counters:
     this measures a call that returns.

     Example: `#objects (#2 (profile (fn () => ()))) = 1` *)
  val profile : (unit -> 'a) -> 'a * stats

  (* `collect ()` collects the heap now.

     Every unreachable object is freed and every surviving one moves, which
     costs time proportional to the live data and to nothing else: a copying
     collector never visits what it does not keep. After it, the `live` of a
     `stats` is exactly the live data, where otherwise it is an upper bound.

     Nothing an SML program can see changes. Equality on a `ref` or an
     `array` is the identity the collector maintains, not an address of the
     moment, so this says when the cost of collecting is paid and never what
     the program means. *)
  val collect : unit -> unit

  (* One function on the call stack, and where in the source it has got to.

     `function` is the name the compiler recorded, qualified by the structures
     it is in; a function the source gives no name is `fn`. The position is
     the call the function is waiting on, or, for the innermost frame, the
     expression being evaluated. Where the program carries no position for
     that instruction, `file` is `""` and both numbers are 0. *)
  type frame = { function : string, file : string, line : int, column : int }

  (* `trace ()` is the frames, innermost first, of the call stack as it
     stands, beginning with the function that called `trace`.

     A tail call does not appear. It replaces the frame it is made from --
     that is what makes a tail-recursive loop run in constant space -- so the
     function it was made from is not on the stack to be reported. *)
  val trace : unit -> frame list

  (* `printTrace out` writes the frames of `trace ()` to `out`, one to a
     line, as the VM writes them under an uncaught exception. *)
  val printTrace : TextIO.outstream -> unit

  (* `same (x, y)` is true when `x` and `y` are one object rather than two
     equal ones.

     It is the identity that `=` uses for a `ref` and an `array`, and it is
     available where `=` is not: at a function type, at `real`, and at any
     type that admits no equality. A collection does not change an answer.

     What it says of anything else is not specified, and a program should not
     ask. A value that is not in the heap at all -- an `int`, a `word`, a
     `char`, `unit`, a constructor with no argument -- has no identity, and
     the comparison is of the values themselves, so `same (1, 1)` is true and
     `same (0.0, ~0.0)` is false because the two are different reals. Of the
     rest, whether two equal values are one object is whatever the compiler
     shared: two equal string constants are one, and two lists written
     separately are two.

     Example: `let val r = ref 0 in same (r, r) end = true` *)
  val same : 'a * 'a -> bool

  (* Which of the two worlds a `save` came back in: the one that wrote the
     image, or the one that was started from it. *)
  datatype world = Saved | Restored

  (* `save file` writes the whole running program to `file` and is `Saved`.

     A VM started as `runevm --restore file` carries on from inside that same
     call, where it is `Restored`: one call and two worlds, as
     `Posix.Process.fork` gives a pid to one process and 0 to another. The
     file is not used up by being restored.

     What is written is everything the program is made of -- the heap, the
     stacks, the counters, and the files it has open, which are opened again
     by name and put back where they were left. What belongs to the process
     rather than to the program is not: a socket, a directory stream and a
     pipe are the system's, and a restored world does not have them.

     Raises: `OS.SysErr` if the image cannot be written. *)
  val save : string -> world

  (* The version of Rune that this program is running on, as
     `runevm --version` prints it.

     The compiler and the VM are built from one string, so `rune --version`
     says the same. It is not the version of the bytecode, which the VM
     checks when it loads a program and which changes only when the file
     format does. *)
  val version : string
end
