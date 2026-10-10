(* Terminal: the terminal of a program over the Basis's RuneTerminal.

   Implements: TERMINAL *)
structure Terminal :> TERMINAL =
struct
  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun available () =
    Posix.ProcEnv.isatty Posix.FileSys.stdin andalso Posix.ProcEnv.isatty Posix.FileSys.stdout
    andalso env "TERM" <> "dumb"

  fun size () =
    case RuneTerminal.size () of
      SOME {columns, rows} =>
        if columns > 0 andalso rows > 0 then {columns = columns, rows = rows} else {columns = 80, rows = 24}
    | NONE => {columns = 80, rows = 24}

  fun resizes () = Int.max (0, RuneTerminal.resizes ())

  val enter = RuneTerminal.enter
  val leave = RuneTerminal.leave
  val read = RuneTerminal.read

  fun write s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)

  fun onWindows () =
    List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ())
    handle _ => false

  fun policy () =
    if env "TERM_PROGRAM" = "vscode" andalso onWindows () then Grapheme.ByCodePoint else Grapheme.ByCluster
end
