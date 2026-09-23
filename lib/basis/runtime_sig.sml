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
end
