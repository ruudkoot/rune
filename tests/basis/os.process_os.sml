(* requires: OS TextIO *)
(* The members of the structure OS itself (signature OS): SysErr, errorMsg,
   errorName and syserror. Expected values follow the text of
   https://smlfamily.github.io/Basis/os.html. tests/basis/os.process.sml has
   the first checks of them; these look at the errors of OS.FileSys, which
   makes and removes a directory osos0 (or osos1, ...) in the current
   directory for them. *)
structure TestOSMembers =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string

  fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end

  val topName : string option ref = ref NONE
  fun top () =
    case !topName of
      SOME n => n
    | NONE =>
        let
          fun try i = let val n = "osos" ^ Int.toString i in if OS.FileSys.access (n, []) then try (i + 1) else n end
          val n = try 0
        in
          topName := SOME n; n
        end
  fun p name = top () ^ "/" ^ name

  (* sysErrOf f: the SysErr that f () raises, as (s, e option). *)
  fun sysErrOf (f : unit -> unit) : (string * OS.syserror option) option =
    (f (); NONE) handle OS.SysErr (s, e) => SOME (s, e)
  (* Failing calls of OS.FileSys, each for another reason: a missing file, an
     existing one, a file where a directory is needed, a directory that is
     not empty. *)
  fun noEntry () = sysErrOf (fn () => OS.FileSys.remove (p "none"))
  fun noEntryDir () = sysErrOf (fn () => ignore (OS.FileSys.openDir (p "none")))
  fun noEntryChDir () = sysErrOf (fn () => OS.FileSys.chDir (p "none"))
  fun exists () = sysErrOf (fn () => OS.FileSys.mkDir (p "sub"))
  fun notDir () = sysErrOf (fn () => OS.FileSys.chDir (p "f.txt"))
  fun notEmpty () = sysErrOf (fn () => OS.FileSys.rmDir (p "sub"))
  val failures = [("remove-missing", noEntry), ("openDir-missing", noEntryDir), ("chDir-missing", noEntryChDir),
                  ("mkDir-existing", exists), ("chDir-to-a-file", notDir), ("rmDir-not-empty", notEmpty)]
  fun errorOf f = case f () of SOME (_, SOME e) => e | _ => raise Fail "no SysErr (s, SOME e)"

  val () = eqB ("OS.SysErr/setup", true,
                fn () => (OS.FileSys.mkDir (top ()); OS.FileSys.mkDir (p "sub"); write (p "sub/x", "x");
                          write (p "f.txt", "f"); true))

  (* ---- SysErr: "raised when a call to the runtime system or host operating
     system results in an error"; "if a SysErr exception has the form
     SysErr(s,SOME e), then we have errorMsg e = s" ---- *)
  val () = List.app (fn (name, f) =>
                       eqB ("OS.SysErr/" ^ name, true, fn () => case f () of SOME (_, SOME _) => true | _ => false))
                    failures
  val () = List.app (fn (name, f) =>
                       eqB ("OS.errorMsg/" ^ name, true,
                            fn () => case f () of SOME (s, SOME e) => OS.errorMsg e = s | _ => false))
                    failures
  val () = List.app (fn (name, f) =>
                       eqB ("OS.errorMsg/nonempty-" ^ name, true, fn () => String.size (OS.errorMsg (errorOf f)) > 0))
                    failures
  (* "If e is a syserror, then it should be the case that
     SOME e = syserror(errorName e)" *)
  val () = List.app (fn (name, f) =>
                       eqB ("OS.syserror/errorName-" ^ name, true,
                            fn () => let val e = errorOf f in OS.syserror (OS.errorName e) = SOME e end))
                    failures
  (* "returns a unique name used for the syserror value": one condition, one
     error and one name, whichever function met it; different errors,
     different names. *)
  val () = eqB ("OS.errorName/same-condition", true,
                fn () => let val names = List.map (OS.errorName o errorOf) [noEntry, noEntryDir, noEntryChDir]
                         in List.all (fn n => n = hd names) names end)
  val () = eqB ("OS.syserror/same-condition", true,
                fn () => errorOf noEntry = errorOf noEntryDir andalso errorOf noEntry = errorOf noEntryChDir)
  val () = eqB ("OS.errorName/different-errors", true,
                fn () => let
                           val es = List.map errorOf [noEntry, exists, notDir]
                           fun distinct [] = true
                             | distinct (x :: r) = List.all (fn y => x <> y) r andalso distinct r
                         in distinct es andalso distinct (List.map OS.errorName es) end)
  val () = eqB ("OS.errorName/nonempty", true, fn () => List.all (fn (_, f) => OS.errorName (errorOf f) <> "") failures)
  val () = eqB ("OS.errorMsg/same-error-same-message", true,
                fn () => OS.errorMsg (errorOf noEntry) = OS.errorMsg (errorOf noEntryDir))
  (* "returns the syserror whose name is s, if it exists" *)
  val () = T.eq (T.option T.string) ("OS.syserror/not-a-name", NONE,
                                     fn () => Option.map OS.errorName (OS.syserror "surely not the name of an error"))
  (* SysErr of string * syserror option: both forms can be raised and matched *)
  val () = eqS ("OS.SysErr/NONE-form", "message",
                fn () => (raise OS.SysErr ("message", NONE)) handle OS.SysErr (s, NONE) => s | OS.SysErr _ => "SOME")
  val () = eqB ("OS.SysErr/SOME-form", true,
                fn () => let val e = errorOf exists
                         in (raise OS.SysErr (OS.errorMsg e, SOME e)) handle OS.SysErr (s, SOME e') => e' = e andalso s = OS.errorMsg e
                                                                            | _ => false end)
  val () = eqS ("OS.SysErr/exnName", "SysErr", fn () => exnName (OS.SysErr ("m", NONE)))
  val () = eqB ("OS.SysErr/is-not-IO.Io", false,
                fn () => (raise OS.SysErr ("m", NONE)) handle IO.Io _ => true | _ => false)

  (*<< posix *)
  (* Posix.Error.syserror "is identical to the type OS.syserror", and its
     values name the POSIX errors. *)
  val () = eqB ("OS.SysErr/remove-missing-is-noent", true, fn () => errorOf noEntry = Posix.Error.noent)
  val () = eqB ("OS.SysErr/mkDir-existing-is-exist", true, fn () => errorOf exists = Posix.Error.exist)
  val () = eqB ("OS.SysErr/chDir-to-a-file-is-notdir", true, fn () => errorOf notDir = Posix.Error.notdir)
  val () = eqB ("OS.errorName/is-Posix.Error.errorName", true,
                fn () => List.all (fn e => OS.errorName e = Posix.Error.errorName e)
                                  [Posix.Error.noent, Posix.Error.exist, Posix.Error.notdir, Posix.Error.acces])
  val () = eqB ("OS.errorMsg/is-Posix.Error.errorMsg", true,
                fn () => List.all (fn e => OS.errorMsg e = Posix.Error.errorMsg e)
                                  [Posix.Error.noent, Posix.Error.exist, Posix.Error.notdir, Posix.Error.acces])
  val () = eqB ("OS.syserror/Posix-errors", true,
                fn () => List.all (fn e => OS.syserror (OS.errorName e) = SOME e)
                                  [Posix.Error.noent, Posix.Error.exist, Posix.Error.notdir, Posix.Error.acces,
                                   Posix.Error.inval, Posix.Error.badf, Posix.Error.pipe, Posix.Error.intr])
  (*>> posix *)

  val () = eqB ("OS.SysErr/cleanup", false,
                fn () => (OS.FileSys.remove (p "sub/x"); OS.FileSys.rmDir (p "sub"); OS.FileSys.remove (p "f.txt");
                          OS.FileSys.rmDir (top ()); OS.FileSys.access (top (), [])))
end
