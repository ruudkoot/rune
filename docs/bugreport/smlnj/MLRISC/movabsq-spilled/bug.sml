(* SML/NJ 110.99.9 (amd64): "MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented"
   when a loop's accumulator holds a constant that needs a 64-bit immediate and
   the register allocator spills it. Each case is compiled on its own, by `use`
   of a file of one declaration, so that one failure does not end the run.
   Run: sml bug.sml *)

val cases =
  [("word 0wx3FFFFFFF (tagged, fits 32 bits)",
    "fun go ([], a) = a | go (v :: r, a : word) = go (r, a + v)\n\
    \val () = print (\"  result \" ^ Word.toString (go ([0w1], 0wx3FFFFFFF)) ^ \"\\n\")\n"),
   ("word 0wx40000000 (tagged, needs 64 bits)",
    "fun go ([], a) = a | go (v :: r, a : word) = go (r, a + v)\n\
    \val () = print (\"  result \" ^ Word.toString (go ([0w1], 0wx40000000)) ^ \"\\n\")\n"),
   ("word 0wx4F1BBCD8C2F5E543",
    "fun go ([], a) = a | go (v :: r, a : word) = go (r, a + v)\n\
    \val () = print (\"  result \" ^ Word.toString (go ([0w1], 0wx4F1BBCD8C2F5E543)) ^ \"\\n\")\n"),
   ("Word64 0wx7FFFFFFF",
    "fun go ([], a) = a | go (v :: r, a : Word64.word) = go (r, a + v)\n\
    \val () = print (\"  result \" ^ Word64.toString (go ([0w1], 0wx7FFFFFFF)) ^ \"\\n\")\n"),
   ("Word64 0wx80000000",
    "fun go ([], a) = a | go (v :: r, a : Word64.word) = go (r, a + v)\n\
    \val () = print (\"  result \" ^ Word64.toString (go ([0w1], 0wx80000000)) ^ \"\\n\")\n"),
   ("the same constant, no loop",
    "fun f (a : word, b : word) = a + b\n\
    \val () = print (\"  result \" ^ Word.toString (f (0w1, 0wx4F1BBCD8C2F5E543)) ^ \"\\n\")\n")]

fun run (name, text) =
  let
    val file = OS.FileSys.tmpName ()
    val out = TextIO.openOut file
    val () = (TextIO.output (out, text); TextIO.closeOut out)
  in
    print (name ^ ":\n");
    (use file handle e => print ("  FAILS: " ^ exnMessage e ^ "\n"));
    OS.FileSys.remove file
  end

val () = List.app run cases
