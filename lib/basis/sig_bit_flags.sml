(* A set of flags held as the bits of a word: what every collection of system
   flags in `POSIX` has in common.

   A `flags` value is a set. `flags` unites sets, `intersect` cuts them down,
   `clear` takes one away from another, and `allSet` and `anySet` ask whether
   a set contains another. The named flags of a structure are the one-element
   sets, and `all` is every bit the system uses there -- which may be more
   than the named flags, since a system knows bits that the specification
   does not name.

   `toWord` and `fromWord` reach the word underneath, for a program that has
   to speak to something that is not SML.

   Area: The operating system

   Status: optional

   See also: `POSIX_FILE_SYS`, `POSIX_IO`, `POSIX_PROCESS`, `POSIX_TTY`,
   `WORD` *)
signature BIT_FLAGS =
sig
  (* The type of a set of flags.

     Two are equal when they hold the same flags. *)
  eqtype flags

  (* `toWord fl` is the word whose bits are the flags of `fl`. *)
  val toWord : flags -> SysWord.word

  (* `fromWord w` is the set of the flags that the bits of `w` name.

     Reading: `BIT_FLAGS.fromWord/masks-the-rest`. The law `toWord o fromWord
     = (fn w => andb (w, toWord all))` is required for every word, those with
     bits that no flag of this structure has included: such bits are dropped
     rather than kept or refused.

     Pinned by: `*.fromWord/bits-beyond-all` *)
  val fromWord : SysWord.word -> flags

  (* Every flag the system uses here.

     Implementation: `BIT_FLAGS.all/every-bit-the-system-has`. It is every
     bit of the underlying C value, so it may include flags the
     specification does not name (`O_CLOEXEC`, `O_LARGEFILE`); that is what
     lets those survive a trip through `fromWord` or a call that reads the
     flags back from the system. *)
  val all : flags

  (* `flags l` is the union of the sets of `l`: a flag is in it when it is in one of them. *)
  val flags : flags list -> flags

  (* `intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them.

     The intersection of no sets at all is `all`. *)
  val intersect : flags list -> flags

  (* `clear (fl, gl)` is `gl` without the flags of `fl`. *)
  val clear : flags * flags -> flags

  (* `allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`. *)
  val allSet : flags * flags -> bool

  (* `anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`. *)
  val anySet : flags * flags -> bool
end
