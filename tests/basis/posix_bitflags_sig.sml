(* requires: Posix SysWord *)
(* uses: spec-sigs/BIT_FLAGS.sml *)
(* The flag substructures of Posix match BIT_FLAGS, and their types are
   those the pages name (Posix.FileSys.S: `include BIT_FLAGS where type flags
   = mode`; the flags of openf, getfd and getfl are O.flags and FD.flags). One
   section per structure, as in posix_bitflags.sml. *)
structure TestPosixBitFlagsSig =
struct
  (*<< filesys-s *)
  structure CS : SPEC_BIT_FLAGS = Posix.FileSys.S
  val () = T.check ("Posix.FileSys.S:BIT_FLAGS/matches", fn () => true)
  val () = T.check ("Posix.FileSys.S:BIT_FLAGS/flags-is-mode",
                    fn () => ((Posix.FileSys.S.irusr : Posix.FileSys.S.flags) : Posix.FileSys.S.mode) = CS.fromWord (CS.toWord Posix.FileSys.S.irusr))
  (*>> filesys-s *)

  (*<< filesys-o *)
  structure CFO : SPEC_BIT_FLAGS = Posix.FileSys.O
  val () = T.check ("Posix.FileSys.O:BIT_FLAGS/matches", fn () => true)
  val () = T.check ("Posix.FileSys.O:BIT_FLAGS/flags-of-openf",
                    fn () => let val _ : (string * Posix.FileSys.open_mode * CFO.flags -> Posix.FileSys.file_desc) = Posix.FileSys.openf
                             in true end)
  (*>> filesys-o *)

  (*<< io-fd *)
  structure CFD : SPEC_BIT_FLAGS = Posix.IO.FD
  val () = T.check ("Posix.IO.FD:BIT_FLAGS/matches", fn () => true)
  val () = T.check ("Posix.IO.FD:BIT_FLAGS/flags-of-getfd",
                    fn () => let val _ : (Posix.IO.file_desc -> CFD.flags) = Posix.IO.getfd in true end)
  (*>> io-fd *)

  (*<< io-o *)
  structure CIO : SPEC_BIT_FLAGS = Posix.IO.O
  val () = T.check ("Posix.IO.O:BIT_FLAGS/matches", fn () => true)
  val () = T.check ("Posix.IO.O:BIT_FLAGS/flags-of-getfl",
                    fn () => let val _ : (Posix.IO.file_desc -> CIO.flags * Posix.IO.open_mode) = Posix.IO.getfl in true end)
  (*>> io-o *)

  (*<< process-w *)
  structure CW : SPEC_BIT_FLAGS = Posix.Process.W
  val () = T.check ("Posix.Process.W:BIT_FLAGS/matches", fn () => true)
  (*>> process-w *)

  (*<< tty-i *)
  structure CTI : SPEC_BIT_FLAGS = Posix.TTY.I
  val () = T.check ("Posix.TTY.I:BIT_FLAGS/matches", fn () => true)
  (*>> tty-i *)

  (*<< tty-o *)
  structure CTO : SPEC_BIT_FLAGS = Posix.TTY.O
  val () = T.check ("Posix.TTY.O:BIT_FLAGS/matches", fn () => true)
  (*>> tty-o *)

  (*<< tty-c *)
  structure CTC : SPEC_BIT_FLAGS = Posix.TTY.C
  val () = T.check ("Posix.TTY.C:BIT_FLAGS/matches", fn () => true)
  (*>> tty-c *)

  (*<< tty-l *)
  structure CTL : SPEC_BIT_FLAGS = Posix.TTY.L
  val () = T.check ("Posix.TTY.L:BIT_FLAGS/matches", fn () => true)
  (*>> tty-l *)
end
