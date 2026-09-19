(* requires: Posix OS *)
(* uses: spec-sigs/POSIX_ERROR.sml *)
(* Posix.Error matches POSIX_ERROR, whose syserror is OS.syserror. *)
structure TestPosixErrorSig =
struct
  structure C : SPEC_POSIX_ERROR = Posix.Error
  val () = T.check ("Posix.Error:POSIX_ERROR/matches", fn () => true)
  val () = T.check ("Posix.Error:POSIX_ERROR/syserror-is-OS.syserror",
                    fn () => (C.noent : OS.syserror) = Posix.Error.noent
                             andalso OS.errorMsg C.noent = C.errorMsg Posix.Error.noent)
end
