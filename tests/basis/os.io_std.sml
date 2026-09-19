(* requires: OS TextIO *)
(* OS.IO (signature OS_IO) on the descriptors of the standard streams:
   TextIO.stdIn, and in the section the standard input, output and error of
   Posix. Expected values follow the text of
   https://smlfamily.github.io/Basis/os-io.html.

   What these descriptors are depends on how the test runs (a terminal, a
   file, a pipe, /dev/null), so that only what holds for any kind is
   checked, and that a descriptor has the kind tty exactly when it is a
   terminal. hash and compare are in a section of their own: Poly/ML 5.7.1
   does not come back from them on these descriptors (a segmentation
   fault). *)
structure TestOSIOStd =
struct
  val eqB = T.eq T.bool

  (* stdInDesc (): the descriptor of TextIO.stdIn, from its reader. The
     stream is rebuilt on that reader, so that it stays usable. *)
  fun stdInDesc () =
    let
      val (rd, buffered) = TextIO.StreamIO.getReader (TextIO.getInstream TextIO.stdIn)
      val () = TextIO.setInstream (TextIO.stdIn, TextIO.StreamIO.mkInstream (rd, buffered))
    in
      case rd of
        TextPrimIO.RD {ioDesc = SOME d, ...} => d
      | _ => raise Fail "TextIO.stdIn has no descriptor"
    end

  (* Whatever TextIO.stdIn is here, its descriptor has a kind, perhaps one
     that is not in Kind ("a given implementation may define other iodesc
     values"), and always the same one. *)
  val () = eqB ("OS.IO.kind/TextIO.stdIn", true, fn () => OS.IO.kind (stdInDesc ()) = OS.IO.kind (stdInDesc ()))
  (* "NONE is returned when no polling is supported by the I/O device" *)
  val () = eqB ("OS.IO.pollDesc/TextIO.stdIn", true,
                fn () => let val d = stdInDesc ()
                         in case OS.IO.pollDesc d of SOME p => OS.IO.pollToIODesc (OS.IO.pollIn p) = d | NONE => true end)

  (*<< posix *)
  fun iod fd = Posix.FileSys.fdToIOD fd
  fun std () = [Posix.FileSys.stdin, Posix.FileSys.stdout, Posix.FileSys.stderr]
  val () = eqB ("OS.IO.kind/standard-descriptors", true,
                fn () => List.all (fn fd => OS.IO.kind (iod fd) = OS.IO.kind (iod fd)) (std ()))
  (* "tty: A terminal console": a standard descriptor has that kind exactly
     when it is a terminal. *)
  val () = eqB ("OS.IO.Kind.tty/standard-descriptors", true,
                fn () => List.all (fn fd => (OS.IO.kind (iod fd) = OS.IO.Kind.tty) = Posix.ProcEnv.isatty fd) (std ()))
  (*>> posix *)

  (*<< hash-compare *)
  fun stdDescs () = List.map Posix.FileSys.fdToIOD [Posix.FileSys.stdin, Posix.FileSys.stdout, Posix.FileSys.stderr]
  val () = eqB ("OS.IO.hash/TextIO.stdIn", true, fn () => OS.IO.hash (stdInDesc ()) = OS.IO.hash (stdInDesc ()))
  val () = eqB ("OS.IO.hash/standard-descriptors", true,
                fn () => ListPair.all (fn (a, b) => OS.IO.hash a = OS.IO.hash b) (stdDescs (), stdDescs ()))
  (* fdToIOD "returns the I/O descriptor corresponding to file descriptor
     fd": for stdin, that of TextIO.stdIn. *)
  val () = eqB ("OS.IO.hash/TextIO.stdIn-is-Posix-stdin", true,
                fn () => OS.IO.hash (stdInDesc ()) = OS.IO.hash (Posix.FileSys.fdToIOD Posix.FileSys.stdin))
  val () = T.eq T.order ("OS.IO.compare/TextIO.stdIn", EQUAL, fn () => let val d = stdInDesc () in OS.IO.compare (d, d) end)
  val () = T.eq T.order ("OS.IO.compare/TextIO.stdIn-twice", EQUAL, fn () => OS.IO.compare (stdInDesc (), stdInDesc ()))
  val () = eqB ("OS.IO.compare/TextIO.stdIn-is-Posix-stdin", true,
                fn () => OS.IO.compare (stdInDesc (), Posix.FileSys.fdToIOD Posix.FileSys.stdin) = EQUAL)
  val () = eqB ("OS.IO.compare/TextIO.stdIn-equals-Posix-stdin", true,
                fn () => stdInDesc () = Posix.FileSys.fdToIOD Posix.FileSys.stdin)
  val () = eqB ("OS.IO.compare/standard-descriptors", true,
                fn () => let val l = stdDescs ()
                         in List.all (fn a => List.all (fn b => (OS.IO.compare (a, b) = EQUAL) = (a = b)) l) l
                            andalso OS.IO.compare (List.nth (l, 0), List.nth (l, 1)) <> EQUAL
                            andalso OS.IO.compare (List.nth (l, 1), List.nth (l, 2)) <> EQUAL end)
  (*>> hash-compare *)
end
