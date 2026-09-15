PolyML.SaveState.loadState (valOf (OS.Process.getEnv "RUNE_POLY_STATE"));
val runeArgs = case CommandLine.arguments () of
    "--script" :: _ :: rest => rest
  | rest => rest;
val runeArgs = List.map (fn arg =>
    if String.isPrefix "rune:" arg then String.extract (arg, 5, NONE)
    else raise Fail "invalid Rune launcher argument") runeArgs;
val runeStatus = Main.main (CommandLine.name (), runeArgs);
(* Poly/ML 5.7.1's exit cleanup intermittently changes success to failure here.
   Rune closes its files itself; flush the standard streams before terminating. *)
val () = TextIO.flushOut TextIO.stdOut;
val () = TextIO.flushOut TextIO.stdErr;
val () = OS.Process.terminate runeStatus;
