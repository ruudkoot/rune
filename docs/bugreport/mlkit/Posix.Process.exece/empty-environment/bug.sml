(* A program run with the environment [] sees no variables. *)
structure P = Posix.Process
fun status () =
  case #2 (P.waitpid (P.W_ANY_CHILD, [])) of
    P.W_EXITED => "exit 0"
  | P.W_EXITSTATUS w => "exit " ^ Word8.toString w
  | _ => "other"
(* sh exits with 4 if HOME is unset, 5 if it is set *)
val () =
  case P.fork () of
    NONE => P.exece ("/bin/sh", ["sh", "-c", "test -z \"${HOME+set}\" && exit 4; exit 5"], [])
  | SOME _ => print ("Posix.Process.exece with []: " ^ status () ^ " (4: HOME unset, 5: HOME set)\n")
(* the number of variables env prints *)
val p : (TextIO.instream, TextIO.outstream) Unix.proc = Unix.executeInEnv ("/usr/bin/env", [], [])
val n = length (String.tokens (fn c => c = #"\n") (TextIO.inputAll (Unix.textInstreamOf p)))
val _ = Unix.reap p
val () = print ("Unix.executeInEnv (\"/usr/bin/env\", [], []): env printed " ^ Int.toString n ^ " variables\n")
