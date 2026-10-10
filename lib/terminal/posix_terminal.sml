(* PosixTerminal: the terminal of a program over Posix.TTY and OS.IO.poll,
   for the compilers that have no RuneTerminal.

   Implements: TERMINAL *)
structure PosixTerminal :> TERMINAL =
struct
  structure T = Posix.TTY

  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun available () =
    Posix.ProcEnv.isatty Posix.FileSys.stdin andalso Posix.ProcEnv.isatty Posix.FileSys.stdout
    andalso env "TERM" <> "dumb"

  fun number name = case Int.fromString (env name) of SOME n => if n > 0 then SOME n else NONE | NONE => NONE

  fun size () =
    {columns = getOpt (number "COLUMNS", 80), rows = getOpt (number "LINES", 24)}

  fun resizes () = 0

  val saved : T.termios option ref = ref NONE
  val undoText = ref ""

  fun write s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)

  fun enter {undo} =
    let
      val fd = Posix.FileSys.stdin
      val t = T.TC.getattr fd
      val () = if isSome (!saved) then () else saved := SOME t
      val {iflag, oflag, cflag, lflag, cc, ispeed, ospeed} = T.fieldsOf (valOf (!saved))
      val iflag = T.I.clear (T.I.flags [T.I.brkint, T.I.icrnl, T.I.inpck, T.I.istrip, T.I.ixon], iflag)
      val lflag = T.L.clear (T.L.flags [T.L.echo, T.L.icanon, T.L.iexten, T.L.isig], lflag)
      val cflag = T.C.flags [T.C.clear (T.C.flags [T.C.csize, T.C.parenb], cflag), T.C.cs8]
      val cc = T.V.update (cc, [(T.V.min, #"\001"), (T.V.time, #"\000")])
    in
      undoText := undo;
      T.TC.setattr (fd, T.TC.sadrain,
                    T.termios {iflag = iflag, oflag = oflag, cflag = cflag, lflag = lflag, cc = cc,
                               ispeed = ispeed, ospeed = ospeed})
    end

  fun leave () =
    case !saved of
      NONE => ()
    | SOME t => (write (!undoText); undoText := ""; T.TC.setattr (Posix.FileSys.stdin, T.TC.sadrain, t))

  fun read wait =
    let
      val desc = valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD Posix.FileSys.stdin))
      val ready = OS.IO.poll ([OS.IO.pollIn desc], wait)
    in
      if null ready then SOME ""
      else
        case Byte.bytesToString (Posix.IO.readVec (Posix.FileSys.stdin, 4096)) of
          "" => NONE
        | s => SOME s
    end
    handle OS.SysErr (_, SOME e) => if e = Posix.Error.intr then SOME "" else raise OS.SysErr ("read", SOME e)

  fun policy () = Grapheme.ByCluster
end
