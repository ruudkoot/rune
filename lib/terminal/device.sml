(* Device: the terminal of the line editor over the Basis's Terminal.

   Implements: DEVICE *)
structure Device :> DEVICE =
struct
  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun available () =
    Posix.ProcEnv.isatty Posix.FileSys.stdin andalso Posix.ProcEnv.isatty Posix.FileSys.stdout
    andalso env "TERM" <> "dumb"

  fun size () =
    case Terminal.size () of
      SOME {columns, rows} =>
        if columns > 0 andalso rows > 0 then {columns = columns, rows = rows} else {columns = 80, rows = 24}
    | NONE => {columns = 80, rows = 24}

  fun resizes () = Int.max (0, Terminal.resizes ())

  val enter = Terminal.enter
  val quiet = Terminal.quiet
  val leave = Terminal.leave
  val read = Terminal.read

  fun write s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)

  fun onWindows () =
    List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
    handle _ => false

  fun policy () =
    if env "TERM_PROGRAM" = "vscode" andalso onWindows () then Grapheme.ByCodePoint else Grapheme.ByCluster
end
