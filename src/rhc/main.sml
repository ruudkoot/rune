(* rhc's driver (the haskell98 roadmap, M8): it reads its command line and
   runs what it asks for. An error of the user's is a line on standard
   error and status 1; a bug of rhc's, Error.Bug, says so. *)
structure RhcMain =
struct
  fun eprint s = TextIO.output (TextIO.stdErr, s)

  fun version () = print ("rhc " ^ Config.version ^ " (identity " ^ Config.identity ^ ")\n")

  (* --share DIR, where rhc's library is, which the wrapper bin/rhc gives *)
  fun share args =
    case args of
      "--share" :: d :: rest => (RhcLibrary.share := SOME d; share rest)
    | ["--share"] => raise RhcOptions.Usage "--share takes a directory"
    | a :: rest => a :: share rest
    | [] => []

  fun run (args : string list) : OS.Process.status =
    let val args = share args in
    case RhcSyntax.command args of
      SOME syntax => syntax ()
    | NONE =>
    let val opts = RhcOptions.parse args
    in
      if #help opts then (print RhcOptions.usage; OS.Process.success)
      else if #version opts then (version (); OS.Process.success)
      else if null (#readCore opts) then raise RhcOptions.Usage "nothing to do: give --read-core FILE"
      else raise RhcOptions.Usage "--read-core: Core's reader is not built yet"
    end
    end

  fun main (_ : string, args : string list) : OS.Process.status =
    run args
    handle RhcOptions.Usage msg => (eprint ("rhc: " ^ msg ^ "\n" ^ "rhc --help says what rhc takes\n"); OS.Process.failure)
         | Error.Bug msg => (eprint ("rhc: " ^ msg ^ "\n"); OS.Process.failure)
         | IO.Io {name, function, cause} =>
             (eprint ("rhc: " ^ name ^ ": " ^ function ^ ": " ^ exnMessage cause ^ "\n"); OS.Process.failure)
end
