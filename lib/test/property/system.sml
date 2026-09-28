(* The arbitraries of the values of the operating system (docs/plans/quickcheck.md,
   M6): made by each case, and undone when it is over. *)

(* Files in a scratch directory, for the arbitraries that are files. *)
structure PropertyScratch =
struct
  (* a new file holding s, and its name *)
  fun scratch (s : string) : string =
    let val name = OS.FileSys.tmpName () val out = TextIO.openOut name
    in TextIO.output (out, s); TextIO.closeOut out; name end
  fun remove (name : string) : unit = OS.FileSys.remove name handle OS.SysErr _ => ()
end

(* Implements: SYSTEM_ARB *)
structure SystemArb :> SYSTEM_ARB =
struct
  fun comment (what : string) : 'a -> string = fn _ => "(* " ^ what ^ " *)"
  fun byShow (show : 'a -> string) : 'a -> Word64.word = fn x => Random.hashString (show x)

  (* ---- binary streams over drawn bytes ---- *)

  val bytes : Word8Vector.vector Gen.gen =
    Gen.map (fn ws => Word8Vector.fromList (List.map (fn w => Word8.fromLarge (Word64.toLarge w)) ws))
            (Gen.list (Gen.wordBits 8))
  fun showBytes (v : Word8Vector.vector) : string =
    "Word8Vector.fromList " ^ Show.list (fn b => "0wx" ^ Word8.fmt StringCvt.HEX b) (Word8Vector.foldr (op ::) [] v)

  fun streamOf (v : Word8Vector.vector) : BinIO.StreamIO.instream =
    BinIO.StreamIO.mkInstream (BinPrimIO.openVector v, Word8Vector.fromList [])
  (* what a functional stream has left, read without changing it *)
  fun rest (f : BinIO.StreamIO.instream) : Word8Vector.vector = #1 (BinIO.StreamIO.inputAll f)
  fun showStream (v : Word8Vector.vector) : string =
    "BinIO.StreamIO.mkInstream (BinPrimIO.openVector (" ^ showBytes v ^ "), Word8Vector.fromList [])"

  val binStreamInstream : BinIO.StreamIO.instream Arb.arb =
    {gen = Gen.map streamOf bytes, show = fn f => showStream (rest f), co = fn f => byShow showBytes (rest f), eq = NONE}

  val binInstream : BinIO.instream Arb.arb =
    {gen = Gen.map (BinIO.mkInstream o streamOf) bytes,
     show = fn s => "BinIO.mkInstream (" ^ showStream (rest (BinIO.getInstream s)) ^ ")",
     co = fn s => byShow showBytes (rest (BinIO.getInstream s)), eq = NONE}

  fun collecting () : BinIO.StreamIO.writer =
    let
      val kept = ref ([] : Word8Vector.vector list)
      fun writeVec sl = (kept := Word8VectorSlice.vector sl :: !kept; Word8VectorSlice.length sl)
      fun writeArr sl = (kept := Word8ArraySlice.vector sl :: !kept; Word8ArraySlice.length sl)
    in
      BinPrimIO.WR {name = "<kept>", chunkSize = 4096, writeVec = SOME writeVec, writeArr = SOME writeArr,
                    writeVecNB = SOME (SOME o writeVec), writeArrNB = SOME (SOME o writeArr), block = SOME (fn () => ()),
                    canOutput = SOME (fn () => true), getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                    close = fn () => (), ioDesc = NONE}
    end

  val binWriter : BinIO.StreamIO.writer Arb.arb =
    {gen = Gen.primitive (fn _ => collecting ()), show = comment "a writer that keeps what it is given",
     co = fn _ => 0w0, eq = NONE}

  val modes = Vector.fromList [IO.NO_BUF, IO.LINE_BUF, IO.BLOCK_BUF]
  val binOutstream : BinIO.StreamIO.outstream Arb.arb =
    {gen = Gen.map (fn m => BinIO.StreamIO.mkOutstream (collecting (), m)) (Gen.elements modes),
     show = fn s => "(* an output stream to a writer that keeps what it is given, "
                    ^ (case BinIO.StreamIO.getBufferMode s of IO.NO_BUF => "IO.NO_BUF" | IO.LINE_BUF => "IO.LINE_BUF"
                                                            | IO.BLOCK_BUF => "IO.BLOCK_BUF") ^ " *)",
     co = fn s => case BinIO.StreamIO.getBufferMode s of IO.NO_BUF => 0w0 | IO.LINE_BUF => 0w1 | IO.BLOCK_BUF => 0w2,
     eq = NONE}

  (* ---- files in a scratch directory ---- *)

  open PropertyScratch


  val fileId : OS.FileSys.file_id Arb.arb =
    {gen = Gen.map #1 (Gen.resource (Gen.primitive (fn _ => let val name = scratch "" in (OS.FileSys.fileId name, name) end),
                                     fn (_, name) => remove name)),
     show = comment "the id of a file", co = fn _ => 0w0, eq = SOME (fn (a, b) => OS.FileSys.compare (a, b) = EQUAL)}

  (* ---- pipes ---- *)

  val pipe : Posix.FileSys.file_desc Gen.gen =
    Gen.map #infd (Gen.resource (Gen.primitive (fn _ => Posix.IO.pipe ()),
                                 fn {infd, outfd} => (Posix.IO.close infd handle _ => (); Posix.IO.close outfd handle _ => ())))

  val fileDesc : Posix.FileSys.file_desc Arb.arb =
    {gen = pipe, show = comment "the read end of a pipe", co = fn _ => 0w0, eq = SOME (op =)}

  val iodesc : OS.IO.iodesc Arb.arb =
    {gen = Gen.map Posix.FileSys.fdToIOD pipe, show = comment "the read end of a pipe", co = fn _ => 0w0,
     eq = SOME (fn (a, b) => OS.IO.compare (a, b) = EQUAL)}

  val pollDesc : OS.IO.poll_desc Arb.arb =
    {gen = Gen.map (fn fd => valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD fd))) pipe,
     show = comment "a poll descriptor of the read end of a pipe", co = fn _ => 0w0, eq = NONE}

  (* ---- names the system gives ---- *)

  val syserror : OS.syserror Arb.arb =
    let
      open Posix.Error
      val all = [acces, again, badf, badmsg, busy, canceled, child, deadlk, dom, exist, fault, fbig, inprogress, intr,
                 inval, io, isdir, loop, mfile, mlink, msgsize, nametoolong, nfile, nodev, noent, noexec, nolck, nomem,
                 nospc, nosys, notdir, notempty, notsup, notty, nxio, perm, pipe, range, rofs, spipe, srch, toobig, xdev]
    in
      Arb.enum (List.map (fn e => (e, "Posix.Error." ^ errorName e)) all)
    end

  val signal : Posix.Signal.signal Arb.arb =
    let
      open Posix.Signal
    in
      Arb.enum [(abrt, "Posix.Signal.abrt"), (alrm, "Posix.Signal.alrm"), (bus, "Posix.Signal.bus"),
                (fpe, "Posix.Signal.fpe"), (hup, "Posix.Signal.hup"), (ill, "Posix.Signal.ill"),
                (int, "Posix.Signal.int"), (kill, "Posix.Signal.kill"), (pipe, "Posix.Signal.pipe"),
                (quit, "Posix.Signal.quit"), (segv, "Posix.Signal.segv"), (term, "Posix.Signal.term"),
                (usr1, "Posix.Signal.usr1"), (usr2, "Posix.Signal.usr2"), (chld, "Posix.Signal.chld"),
                (cont, "Posix.Signal.cont"), (stop, "Posix.Signal.stop"), (tstp, "Posix.Signal.tstp"),
                (ttin, "Posix.Signal.ttin"), (ttou, "Posix.Signal.ttou")]
    end

  (* the values are the process's own, so they are made when a case asks *)
  val pid : Posix.Process.pid Arb.arb =
    let
      fun word p = Posix.Process.pidToWord p
    in
      {gen = Gen.bind (Gen.primitive (fn _ => Vector.fromList [Posix.ProcEnv.getpid (), Posix.ProcEnv.getppid ()])) Gen.elements,
       show = fn p => "Posix.Process.wordToPid 0wx" ^ SysWord.fmt StringCvt.HEX (word p),
       co = fn p => Word64.fromLarge (SysWord.toLarge (word p)), eq = SOME (op =)}
    end

  val uid : Posix.ProcEnv.uid Arb.arb =
    {gen = Gen.bind (Gen.primitive (fn _ => Vector.fromList [Posix.ProcEnv.getuid (), Posix.ProcEnv.wordToUid 0w0]))
                    Gen.elements,
     show = fn u => "Posix.ProcEnv.wordToUid 0wx" ^ SysWord.fmt StringCvt.HEX (Posix.ProcEnv.uidToWord u),
     co = fn u => Word64.fromLarge (SysWord.toLarge (Posix.ProcEnv.uidToWord u)), eq = SOME (op =)}

  val gid : Posix.ProcEnv.gid Arb.arb =
    {gen = Gen.bind (Gen.primitive (fn _ => Vector.fromList [Posix.ProcEnv.getgid (), Posix.ProcEnv.wordToGid 0w0]))
                    Gen.elements,
     show = fn g => "Posix.ProcEnv.wordToGid 0wx" ^ SysWord.fmt StringCvt.HEX (Posix.ProcEnv.gidToWord g),
     co = fn g => Word64.fromLarge (SysWord.toLarge (Posix.ProcEnv.gidToWord g)), eq = SOME (op =)}

  (* ---- terminals ---- *)

  val speed : Posix.TTY.speed Arb.arb =
    let
      open Posix.TTY
    in
      Arb.enum [(b0, "Posix.TTY.b0"), (b50, "Posix.TTY.b50"), (b75, "Posix.TTY.b75"), (b110, "Posix.TTY.b110"),
                (b134, "Posix.TTY.b134"), (b150, "Posix.TTY.b150"), (b200, "Posix.TTY.b200"), (b300, "Posix.TTY.b300"),
                (b600, "Posix.TTY.b600"), (b1200, "Posix.TTY.b1200"), (b1800, "Posix.TTY.b1800"),
                (b2400, "Posix.TTY.b2400"), (b4800, "Posix.TTY.b4800"), (b9600, "Posix.TTY.b9600"),
                (b19200, "Posix.TTY.b19200"), (b38400, "Posix.TTY.b38400")]
    end

  fun sysWord (w : Word64.word) : SysWord.word = SysWord.fromLarge (Word64.toLarge w)
  fun hex (w : SysWord.word) : string = "0wx" ^ SysWord.fmt StringCvt.HEX w

  local
    structure T = Posix.TTY
  in
  val termios : Posix.TTY.termios Arb.arb =
    let
      val flags = Gen.map sysWord (Gen.wordBits 32)
      val ccs = Gen.map (fn cs => T.V.cc (ListPair.zip (List.tabulate (T.V.nccs, fn i => i), cs)))
                        (Gen.listOf (Gen.return T.V.nccs) Gen.char)
      fun make ((i, oflag, c), (l, cc, (is, os))) =
        T.termios {iflag = T.I.fromWord i, oflag = T.O.fromWord oflag, cflag = T.C.fromWord c, lflag = T.L.fromWord l,
                   cc = cc, ispeed = is, ospeed = os}
      fun show t =
        let val {iflag, oflag, cflag, lflag, cc, ispeed, ospeed} = T.fieldsOf t
        in
          "Posix.TTY.termios {iflag = Posix.TTY.I.fromWord " ^ hex (T.I.toWord iflag)
          ^ ", oflag = Posix.TTY.O.fromWord " ^ hex (T.O.toWord oflag) ^ ", cflag = Posix.TTY.C.fromWord "
          ^ hex (T.C.toWord cflag) ^ ", lflag = Posix.TTY.L.fromWord " ^ hex (T.L.toWord lflag)
          ^ ", cc = Posix.TTY.V.cc " ^ Show.list (Show.pair (Show.int, Show.char))
                                                  (List.tabulate (T.V.nccs, fn i => (i, T.V.sub (cc, i))))
          ^ ", ispeed = " ^ #show speed ispeed ^ ", ospeed = " ^ #show speed ospeed ^ "}"
        end
    in
      {gen = Gen.map2 make (Gen.triple (flags, flags, flags), Gen.triple (flags, ccs, Gen.pair (#gen speed, #gen speed))),
       show = show, co = byShow show, eq = SOME (fn (a, b) => show a = show b)}
    end

  val termiosFields =
    {gen = Gen.map T.fieldsOf (#gen termios), show = fn r => "Posix.TTY.fieldsOf (" ^ #show termios (T.termios r) ^ ")",
     co = fn r => #co termios (T.termios r), eq = SOME (fn (a, b) => #show termios (T.termios a) = #show termios (T.termios b))}
  end

  val whence = Arb.enum [(Posix.IO.SEEK_SET, "Posix.IO.SEEK_SET"), (Posix.IO.SEEK_CUR, "Posix.IO.SEEK_CUR"),
                         (Posix.IO.SEEK_END, "Posix.IO.SEEK_END")]
  val lockType = Arb.enum [(Posix.IO.F_RDLCK, "Posix.IO.F_RDLCK"), (Posix.IO.F_WRLCK, "Posix.IO.F_WRLCK"),
                           (Posix.IO.F_UNLCK, "Posix.IO.F_UNLCK")]

  (* ---- sockets ---- *)

  val addrFamily : Socket.AF.addr_family Arb.arb =
    {gen = Gen.bind (Gen.primitive (fn _ => Vector.fromList (List.map #2 (Socket.AF.list ())))) Gen.elements,
     show = fn af => "valOf (Socket.AF.fromString " ^ Show.string (Socket.AF.toString af) ^ ")",
     co = fn af => Random.hashString (Socket.AF.toString af), eq = SOME (op =)}

  val sockType : Socket.SOCK.sock_type Arb.arb =
    {gen = Gen.bind (Gen.primitive (fn _ => Vector.fromList (List.map #2 (Socket.SOCK.list ())))) Gen.elements,
     show = fn t => "valOf (Socket.SOCK.fromString " ^ Show.string (Socket.SOCK.toString t) ^ ")",
     co = fn t => Random.hashString (Socket.SOCK.toString t), eq = SOME (op =)}

  fun inetStreamSock () : 'mode INetSock.stream_sock Arb.arb =
    {gen = Gen.resource (Gen.primitive (fn _ => INetSock.TCP.socket ()), fn s => Socket.close s handle _ => ()),
     show = comment "a new TCP socket", co = fn _ => 0w0, eq = NONE}

  val inAddr : NetHostDB.in_addr Arb.arb =
    {gen = Gen.map (fn ws => valOf (NetHostDB.fromString (String.concatWith "." (List.map (fn w => Word64.fmt StringCvt.DEC w) ws))))
                   (Gen.listOf (Gen.return 4) (Gen.wordBits 8)),
     show = fn a => "valOf (NetHostDB.fromString " ^ Show.string (NetHostDB.toString a) ^ ")",
     co = fn a => Random.hashString (NetHostDB.toString a), eq = SOME (op =)}

  val hostEntry : NetHostDB.entry Arb.arb =
    {gen = Gen.primitive (fn _ => valOf (NetHostDB.getByName "localhost")),
     show = fn _ => "valOf (NetHostDB.getByName \"localhost\")", co = fn _ => 0w0, eq = NONE}
end
