(* requires: OS TextIO BinIO Time *)
(* OS.IO (signature OS_IO). Expected values follow the text of
   https://smlfamily.github.io/Basis/os-io.html.

   The descriptors come from the readers and writers of TextIO and BinIO
   streams on files of the current directory (which have the kind file), and,
   in the sections at the end, from Posix (pipes, a directory, /dev/null) and
   from a socket; tests/basis/os.io_std.sml has those of the standard
   streams. A regular file is always ready for reading and writing (POSIX
   poll), a pipe is ready for reading only when it holds data. Input and
   output together are asked of a descriptor open for both, which only Posix
   can make ("It raises Poll if input (respectively, output ...) is not
   appropriate for the underlying I/O device"). *)
structure TestOSIO =
struct
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val isSysErr = fn OS.SysErr _ => true | _ => false
  val isPoll = fn OS.IO.Poll => true | _ => false
  val kinds = [("file", OS.IO.Kind.file), ("dir", OS.IO.Kind.dir), ("symlink", OS.IO.Kind.symlink),
               ("tty", OS.IO.Kind.tty), ("pipe", OS.IO.Kind.pipe), ("socket", OS.IO.Kind.socket),
               ("device", OS.IO.Kind.device)]
  fun showKind k = case List.find (fn (_, k') => k' = k) kinds of SOME (n, _) => n | NONE => "another kind"
  val eqKind = T.eq showKind

  fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end

  (* withIn (name, f): f d, d the descriptor of a TextIO input stream on the
     file name, which is closed after. *)
  fun withIn (name, f) =
    case TextIO.StreamIO.getReader (TextIO.getInstream (TextIO.openIn name)) of
      (TextPrimIO.RD {ioDesc = SOME d, close, ...}, _) =>
        (let val r = f d in close (); r end handle e => (close (); raise e))
    | (TextPrimIO.RD {close, ...}, _) => (close (); raise Fail "the reader has no descriptor")
  (* withOut (name, f): the same for a BinIO output stream. *)
  fun withOut (name, f) =
    case BinIO.StreamIO.getWriter (BinIO.getOutstream (BinIO.openOut name)) of
      (BinPrimIO.WR {ioDesc = SOME d, close, ...}, _) =>
        (let val r = f d in close (); r end handle e => (close (); raise e))
    | (BinPrimIO.WR {close, ...}, _) => (close (); raise Fail "the writer has no descriptor")
  (* closedDesc (): the descriptor of a stream that has been closed. *)
  fun closedDesc () =
    case TextIO.StreamIO.getReader (TextIO.getInstream (TextIO.openIn "io-a.txt")) of
      (TextPrimIO.RD {ioDesc = SOME d, close, ...}, _) => (close (); d)
    | (TextPrimIO.RD {close, ...}, _) => (close (); raise Fail "the reader has no descriptor")

  fun pd d = valOf (OS.IO.pollDesc d)
  val zero = SOME Time.zeroTime

  val () = eqB ("OS.IO.kind/setup", true,
                fn () => (write ("io-a.txt", "a"); write ("io-b.txt", "b"); write ("io-c.txt", "c"); write ("io-d.txt", "d");
                          true))

  (* ---- Kind: "the various kinds of system objects that an I/O descriptor
     might represent", each a different value ---- *)
  fun distinct name =
    eqB ("OS.IO.Kind." ^ name ^ "/distinct", true,
         fn () => let val k = #2 (valOf (List.find (fn (n, _) => n = name) kinds))
                  in List.all (fn (n, k') => (k = k') = (n = name)) kinds end)
  val () = List.app distinct ["file", "dir", "symlink", "tty", "pipe", "socket", "device"]

  (* ---- kind: "The I/O descriptor associated with a stream produced by one
     of the BinIO or TextIO file opening operations will always have this
     kind [file]." ---- *)
  val () = eqKind ("OS.IO.kind/TextIO.openIn", OS.IO.Kind.file, fn () => withIn ("io-a.txt", OS.IO.kind))
  val () = eqKind ("OS.IO.kind/BinIO.openOut", OS.IO.Kind.file, fn () => withOut ("io-out.bin", OS.IO.kind))
  val () = eqKind ("OS.IO.Kind.file/TextIO.openOut", OS.IO.Kind.file,
                   fn () => case TextIO.StreamIO.getWriter (TextIO.getOutstream (TextIO.openOut "io-out.txt")) of
                              (TextPrimIO.WR {ioDesc = SOME d, close, ...}, _) => let val k = OS.IO.kind d in close (); k end
                            | (TextPrimIO.WR {close, ...}, _) => (close (); raise Fail "the writer has no descriptor"))
  val () = eqKind ("OS.IO.Kind.file/BinIO.openAppend", OS.IO.Kind.file,
                   fn () => case BinIO.StreamIO.getWriter (BinIO.getOutstream (BinIO.openAppend "io-out.bin")) of
                              (BinPrimIO.WR {ioDesc = SOME d, close, ...}, _) => let val k = OS.IO.kind d in close (); k end
                            | (BinPrimIO.WR {close, ...}, _) => (close (); raise Fail "the writer has no descriptor"))
  (* "This will raise OS.SysErr if, for example, iod refers to a closed
     file." *)
  val () = T.raises ("OS.IO.kind/closed-SysErr", isSysErr, fn () => OS.IO.kind (closedDesc ()))

  (* ---- compare: "in some underlying linear ordering on iodesc values";
     hash ---- *)
  (* withThree f: f [a, b, c], the descriptors of three files open at once;
     withFour likewise. *)
  fun withThree f = withIn ("io-a.txt", fn a => withIn ("io-b.txt", fn b => withIn ("io-c.txt", fn c => f [a, b, c])))
  fun withFour f = withThree (fn l => withIn ("io-d.txt", fn d => f (d :: l)))
  val () = T.eq T.order ("OS.IO.compare/same", EQUAL, fn () => withIn ("io-a.txt", fn d => OS.IO.compare (d, d)))
  val () = eqB ("OS.IO.compare/EQUAL-iff-equal", true,
                fn () => withFour (fn l => List.all (fn a => List.all (fn b => (OS.IO.compare (a, b) = EQUAL) = (a = b)) l) l))
  val () = eqB ("OS.IO.compare/different-files", true,
                fn () => withThree (fn [a, b, c] => a <> b andalso b <> c andalso a <> c andalso OS.IO.compare (a, b) <> EQUAL
                                     | _ => false))
  fun flip LESS = GREATER
    | flip GREATER = LESS
    | flip EQUAL = EQUAL
  val () = eqB ("OS.IO.compare/antisymmetric", true,
                fn () => withFour (fn l => List.all (fn a => List.all (fn b => OS.IO.compare (b, a) = flip (OS.IO.compare (a, b))) l) l))
  fun lt (a, b) = OS.IO.compare (a, b) = LESS
  val () = eqB ("OS.IO.compare/transitive", true,
                fn () => withFour (fn l => List.all (fn a => List.all (fn b => List.all (fn c =>
                                                 not (lt (a, b) andalso lt (b, c)) orelse lt (a, c)) l) l) l))
  val () = eqB ("OS.IO.hash/same-descriptor", true, fn () => withIn ("io-a.txt", fn d => OS.IO.hash d = OS.IO.hash d))
  val () = eqB ("OS.IO.hash/equal-descriptors", true,
                fn () => withIn ("io-a.txt", fn d => OS.IO.hash d = OS.IO.hash (OS.IO.pollToIODesc (pd d))))
  (* "hash must have the property that values produced are well distributed
     when taken modulo 2(n)": four descriptors do not all have one hash. *)
  val () = eqB ("OS.IO.hash/not-constant", true,
                fn () => withFour (fn l => let val hs = List.map OS.IO.hash l in List.exists (fn h => h <> hd hs) hs end))

  (* ---- pollDesc, pollToIODesc, pollIn, pollOut, pollPri ---- *)
  (* The file systems of the matrix can poll a file: POSIX poll reports a
     regular file ready. *)
  val () = eqB ("OS.IO.pollDesc/file", true, fn () => withIn ("io-a.txt", fn d => isSome (OS.IO.pollDesc d)))
  (* "return the I/O descriptor that is being polled using pd" *)
  val () = eqB ("OS.IO.pollToIODesc/of-pollDesc", true, fn () => withIn ("io-a.txt", fn d => OS.IO.pollToIODesc (pd d) = d))
  val () = eqB ("OS.IO.pollToIODesc/of-pollIn", true,
                fn () => withIn ("io-a.txt", fn d => OS.IO.pollToIODesc (OS.IO.pollIn (pd d)) = d))
  val () = eqB ("OS.IO.pollToIODesc/of-pollOut", true,
                fn () => withOut ("io-out.bin", fn d => OS.IO.pollToIODesc (OS.IO.pollOut (pd d)) = d))
  val () = eqB ("OS.IO.pollToIODesc/of-pollPri", true,
                fn () => withIn ("io-a.txt", fn d => (OS.IO.pollToIODesc (OS.IO.pollPri (pd d)) = d)
                                                     handle OS.IO.Poll => true))
  (* pollIn adds input polling: a different poll_desc, and adding it twice
     is adding it once. *)
  val () = eqB ("OS.IO.pollIn/adds-a-condition", true, fn () => withIn ("io-a.txt", fn d => OS.IO.pollIn (pd d) <> pd d))
  val () = eqB ("OS.IO.pollIn/twice", true,
                fn () => withIn ("io-a.txt", fn d => OS.IO.pollIn (OS.IO.pollIn (pd d)) = OS.IO.pollIn (pd d)))
  val () = eqB ("OS.IO.pollOut/adds-a-condition", true, fn () => withOut ("io-out.bin", fn d => OS.IO.pollOut (pd d) <> pd d))
  (* "It raises Poll if input (respectively, output, high-priority events) is
     not appropriate for the underlying I/O device": input from a file is. *)
  val () = eqB ("OS.IO.pollIn/file-no-Poll", true,
                fn () => withIn ("io-a.txt", fn d => (ignore (OS.IO.pollIn (pd d)); true) handle OS.IO.Poll => false))
  val () = eqB ("OS.IO.pollOut/file-no-Poll", true,
                fn () => withOut ("io-out.bin", fn d => (ignore (OS.IO.pollOut (pd d)); true) handle OS.IO.Poll => false))

  (* ---- poll, isIn, isOut, isPri, infoToPollDesc: "a list of poll_info values
     corresponding to those descriptors in l whose conditions are enabled.
     The returned list respects the order of the argument list, and a value in
     the returned list will reflect a (nonempty) subset of the conditions
     specified in the corresponding argument descriptor." ---- *)
  fun pollOne (d, add) = OS.IO.poll ([add (pd d)], zero)
  val () = eqI ("OS.IO.poll/file-ready-for-input", 1, fn () => withIn ("io-a.txt", fn d => length (pollOne (d, OS.IO.pollIn))))
  val () = eqB ("OS.IO.isIn/file", true,
                fn () => withIn ("io-a.txt", fn d => List.all OS.IO.isIn (pollOne (d, OS.IO.pollIn))))
  val () = eqB ("OS.IO.isOut/not-asked", false,
                fn () => withIn ("io-a.txt", fn d => List.exists OS.IO.isOut (pollOne (d, OS.IO.pollIn))))
  val () = eqB ("OS.IO.isPri/not-asked", false,
                fn () => withIn ("io-a.txt", fn d => List.exists OS.IO.isPri (pollOne (d, OS.IO.pollIn))))
  val () = eqI ("OS.IO.poll/file-ready-for-output", 1,
                fn () => withOut ("io-out.bin", fn d => length (pollOne (d, OS.IO.pollOut))))
  val () = eqB ("OS.IO.isOut/file", true,
                fn () => withOut ("io-out.bin", fn d => List.all OS.IO.isOut (pollOne (d, OS.IO.pollOut))))
  val () = eqB ("OS.IO.isIn/not-asked", false,
                fn () => withOut ("io-out.bin", fn d => List.exists OS.IO.isIn (pollOne (d, OS.IO.pollOut))))
  (* "returns the underlying poll descriptor from poll information pi" *)
  val () = eqB ("OS.IO.infoToPollDesc/file", true,
                fn () => withIn ("io-a.txt", fn d => List.map OS.IO.infoToPollDesc (pollOne (d, OS.IO.pollIn)) = [OS.IO.pollIn (pd d)]))
  val () = eqB ("OS.IO.poll/order-of-the-arguments", true,
                fn () => withThree (fn l => let val ps = List.map (fn d => OS.IO.pollIn (pd d)) (List.rev l)
                                            in List.map OS.IO.infoToPollDesc (OS.IO.poll (ps, zero)) = ps end))
  val () = eqI ("OS.IO.poll/nothing", 0, fn () => length (OS.IO.poll ([], zero)))
  (* "NONE means wait indefinitely": a file is ready at once. *)
  val () = eqI ("OS.IO.poll/NONE", 1, fn () => withIn ("io-a.txt", fn d => length (OS.IO.poll ([OS.IO.pollIn (pd d)], NONE))))
  val () = eqI ("OS.IO.poll/timeout", 1,
                fn () => withIn ("io-a.txt", fn d => length (OS.IO.poll ([OS.IO.pollIn (pd d)], SOME (Time.fromReal 5.0)))))
  (* A regular file has no high-priority data, if pollPri accepts it. *)
  val () = eqB ("OS.IO.pollPri/file", true,
                fn () => withIn ("io-a.txt", fn d => (List.null (OS.IO.poll ([OS.IO.pollPri (pd d)], zero)))
                                                     handle OS.IO.Poll => true))
  (* "The poll function will raise OS.SysErr if, for example, one of the file
     descriptors refers to a closed file." *)
  val () = T.raises ("OS.IO.poll/closed-SysErr", isSysErr,
                     fn () => OS.IO.poll ([OS.IO.pollIn (pd (closedDesc ()))], zero))

  (* ---- Poll ---- *)
  val () = T.raises ("OS.IO.Poll/raise-handle", isPoll, fn () => raise OS.IO.Poll)
  val () = eqB ("OS.IO.Poll/is-not-SysErr", false, fn () => (raise OS.IO.Poll) handle OS.SysErr _ => true | _ => false)

  (*<< posix *)
  (* Descriptors of Posix: a pipe, a directory, /dev/null, a file open for
     reading and writing. *)
  fun iod fd = Posix.FileSys.fdToIOD fd
  fun withPipe f =
    let
      val {infd, outfd} = Posix.IO.pipe ()
      fun closeBoth () = (Posix.IO.close infd; Posix.IO.close outfd)
      val r = f (iod infd, iod outfd, outfd) handle e => (closeBoth (); raise e)
    in
      closeBoth (); r
    end
  fun put fd = ignore (Posix.IO.writeVec (fd, Word8VectorSlice.full (Word8Vector.fromList [Word8.fromInt 120])))
  fun withOpenMode (mode, name, f) =
    let
      val fd = Posix.FileSys.openf (name, mode, Posix.FileSys.O.flags [])
      val r = f (iod fd) handle e => (Posix.IO.close fd; raise e)
    in
      Posix.IO.close fd; r
    end
  fun withOpen (name, f) = withOpenMode (Posix.FileSys.O_RDONLY, name, f)
  (* The order in which conditions are added does not matter, and output is
     not input. *)
  val () = eqB ("OS.IO.pollOut/commutes-with-pollIn", true,
                fn () => withOpenMode (Posix.FileSys.O_RDWR, "io-a.txt",
                                       fn d => OS.IO.pollOut (OS.IO.pollIn (pd d)) = OS.IO.pollIn (OS.IO.pollOut (pd d))))
  val () = eqB ("OS.IO.pollOut/differs-from-pollIn", true,
                fn () => withOpenMode (Posix.FileSys.O_RDWR, "io-a.txt", fn d => OS.IO.pollOut (pd d) <> OS.IO.pollIn (pd d)))
  (* "pipe: A pipe to another system process." *)
  val () = eqKind ("OS.IO.Kind.pipe/read-end", OS.IO.Kind.pipe, fn () => withPipe (fn (r, _, _) => OS.IO.kind r))
  val () = eqKind ("OS.IO.Kind.pipe/write-end", OS.IO.Kind.pipe, fn () => withPipe (fn (_, w, _) => OS.IO.kind w))
  (* "dir: I/O descriptors associated with file system objects for which
     OS.FileSys.isDir returns true will have this kind." *)
  val () = eqKind ("OS.IO.Kind.dir/directory", OS.IO.Kind.dir, fn () => withOpen (".", OS.IO.kind))
  (* "device: A logical or physical hardware device"; /dev/null is not a
     terminal. *)
  val () = eqKind ("OS.IO.Kind.device/dev-null", OS.IO.Kind.device, fn () => withOpen ("/dev/null", OS.IO.kind))
  val () = eqB ("OS.IO.Kind.tty/dev-null", false, fn () => withOpen ("/dev/null", fn d => OS.IO.kind d = OS.IO.Kind.tty))
  (* "symlink: I/O descriptors associated with file system objects for which
     OS.FileSys.isLink returns true": opening a link opens the file it names,
     whose descriptor has the kind file. *)
  val () = eqKind ("OS.IO.Kind.symlink/opening-follows-the-link", OS.IO.Kind.file,
                   fn () => ((Posix.FileSys.symlink {old = "io-a.txt", new = "io-link"} handle OS.SysErr _ => ());
                             withIn ("io-link", OS.IO.kind)))
  val () = eqB ("OS.IO.pollDesc/pipe", true, fn () => withPipe (fn (r, w, _) => isSome (OS.IO.pollDesc r) andalso isSome (OS.IO.pollDesc w)))
  (* An empty pipe is not ready for input; its write end is ready for
     output; once written, the read end is ready. *)
  val () = eqI ("OS.IO.poll/empty-pipe", 0, fn () => withPipe (fn (r, _, _) => length (pollOne (r, OS.IO.pollIn))))
  val () = eqB ("OS.IO.isOut/pipe-write-end", true,
                fn () => withPipe (fn (_, w, _) => case pollOne (w, OS.IO.pollOut) of [i] => OS.IO.isOut i | _ => false))
  val () = eqB ("OS.IO.isIn/pipe-with-data", true,
                fn () => withPipe (fn (r, _, fd) => (put fd; case pollOne (r, OS.IO.pollIn) of [i] => OS.IO.isIn i | _ => false)))
  val () = eqB ("OS.IO.isPri/pipe-with-data", false,
                fn () => withPipe (fn (r, _, fd) => (put fd; List.exists OS.IO.isPri (pollOne (r, OS.IO.pollIn)))))
  (* Only the descriptors whose conditions are enabled, in the order given. *)
  val () = eqB ("OS.IO.poll/only-the-ready-ones-in-order", true,
                fn () => withPipe (fn (r, w, _) => withIn ("io-a.txt", fn f =>
                           let
                             val ps = [OS.IO.pollIn (pd r), OS.IO.pollOut (pd w), OS.IO.pollIn (pd r), OS.IO.pollIn (pd f)]
                             val infos = OS.IO.poll (ps, zero)
                           in
                             List.map OS.IO.infoToPollDesc infos = [OS.IO.pollOut (pd w), OS.IO.pollIn (pd f)]
                             andalso List.map OS.IO.isOut infos = [true, false]
                             andalso List.map OS.IO.isIn infos = [false, true]
                           end)))
  (* "SOME(t) means timeout after time t": nothing ready, so poll returns []
     after about t. *)
  val () = eqB ("OS.IO.poll/times-out", true,
                fn () => withPipe (fn (r, _, _) =>
                           let
                             val start = Time.now ()
                             val infos = OS.IO.poll ([OS.IO.pollIn (pd r)], SOME (Time.fromReal 0.2))
                             val took = Time.- (Time.now (), start)
                           in
                             List.null infos andalso Time.>= (took, Time.fromReal 0.15) andalso Time.< (took, Time.fromReal 5.0)
                           end))
  (* "SOME(Time.zeroTime) means do not block" *)
  val () = eqB ("OS.IO.poll/zero-does-not-block", true,
                fn () => withPipe (fn (r, _, _) =>
                           let val start = Time.now ()
                           in List.null (pollOne (r, OS.IO.pollIn)) andalso Time.< (Time.- (Time.now (), start), Time.fromReal 1.0) end))
  val () = eqB ("OS.IO.pollToIODesc/pipe", true, fn () => withPipe (fn (r, _, _) => OS.IO.pollToIODesc (OS.IO.pollIn (pd r)) = r))
  (*>> posix *)

  (*<< socket *)
  (* "socket: A network socket." A TCP socket that is not bound or
     connected. *)
  val () = eqKind ("OS.IO.Kind.socket/tcp", OS.IO.Kind.socket,
                   fn () => let val s = INetSock.TCP.socket () : Socket.passive INetSock.stream_sock
                                val k = OS.IO.kind (Socket.ioDesc s) handle e => (Socket.close s; raise e)
                            in Socket.close s; k end)
  (*>> socket *)

  (* The files of the test are removed (the link only if the posix section
     made it). *)
  val () = eqB ("OS.IO.kind/cleanup", true,
                fn () => (List.app OS.FileSys.remove ["io-b.txt", "io-c.txt", "io-d.txt", "io-out.txt", "io-out.bin"];
                          (OS.FileSys.remove "io-link" handle OS.SysErr _ => ());
                          true))

  (*<< input-and-output *)
  (* Polling a file open for reading and writing for input and output at
     once, in a section of its own: SML/NJ does not come back from it (its
     runtime stops with a segmentation fault). *)
  val () = eqB ("OS.IO.poll/nonempty-subset", true,
                fn () => let
                           val fd = Posix.FileSys.openf ("io-a.txt", Posix.FileSys.O_RDWR, Posix.FileSys.O.flags [])
                           val d = Posix.FileSys.fdToIOD fd
                           val infos = OS.IO.poll ([OS.IO.pollIn (OS.IO.pollOut (valOf (OS.IO.pollDesc d)))], zero)
                                       handle e => (Posix.IO.close fd; raise e)
                         in
                           Posix.IO.close fd;
                           case infos of
                             [i] => (OS.IO.isIn i orelse OS.IO.isOut i) andalso not (OS.IO.isPri i)
                           | _ => false
                         end)
  (*>> input-and-output *)

  val () = eqB ("OS.IO.poll/cleanup", false, fn () => (OS.FileSys.remove "io-a.txt"; OS.FileSys.access ("io-a.txt", [])))
end
