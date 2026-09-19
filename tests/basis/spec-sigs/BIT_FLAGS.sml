(* signature BIT_FLAGS, transcribed from
   https://smlfamily.github.io/Basis/bit-flags.html

   The flag substructures of the Posix signatures include it:
   Posix.FileSys.S (where type flags = mode) and Posix.FileSys.O
   (spec-sigs/POSIX_FILE_SYS.sml), Posix.IO.FD and Posix.IO.O
   (spec-sigs/POSIX_IO.sml), and Posix.Process.W and the flags of Posix.TTY
   on their pages. *)
signature SPEC_BIT_FLAGS =
sig
  eqtype flags
  val toWord : flags -> SysWord.word
  val fromWord : SysWord.word -> flags
  val all : flags
  val flags : flags list -> flags
  val intersect : flags list -> flags
  val clear : flags * flags -> flags
  val allSet : flags * flags -> bool
  val anySet : flags * flags -> bool
end
