(* Compile-time diagnostics. An error or a warning is a span and a message;
   how it is shown is `show`, which by default writes the line the compiler
   has always written (`format`, `formatWarning`) and which a driver points
   at Diagnostic's rendering (docs/diagnostics.md). *)
structure Error =
struct
  exception CompileError of Source.span * string

  fun error (sp, msg) = raise CompileError (sp, msg)

  fun format (sp, msg) = Source.describe sp ^ ": error: " ^ msg
  fun formatWarning (sp, msg) = Source.describe sp ^ ": warning: " ^ msg

  (* the text of a diagnostic of a level ("error" or "warning") *)
  val show : (string * Source.span * string -> string) ref =
    ref (fn ("warning", sp, msg) => formatWarning (sp, msg) | (_, sp, msg) => format (sp, msg))
    val () = CompilerState.cellRoot ("Error.show", show)

  (* each error and warning as data too, when wanted: severity, span,
     message (the compiler as a service, Serve) *)
  val keep = ref false
  val () = CompilerState.cellRoot ("Error.keep", keep)
  val kept : (string * Source.span * string) list ref = ref []
  val () = CompilerState.cellRoot ("Error.kept", kept)
  fun note (severity, sp, msg) = if !keep then kept := (severity, sp, msg) :: !kept else ()

  (* nothing printed: what is reported is only kept (the REPL's engine,
     which answers with it as data) *)
  val silent = ref false
  val () = CompilerState.cellRoot ("Error.silent", silent)

  (* What a compile made again does not print twice (the driver's
     compiledAgain): the text of the diagnostics printed so far, newest
     first, where the compile keeps it (SOME); and of that, the text an
     attempt made again has not yet given, which it gives without printing.
     A diagnostic is printed once, however many attempts give it *)
  val printed : string list option ref = ref NONE
  val () = CompilerState.cellRoot ("Error.printed", printed)
  val owed : string list ref = ref []
  val () = CompilerState.cellRoot ("Error.owed", owed)
  fun output (text : string) : unit =
    let
      fun take (_, []) = NONE
        | take (seen, t :: rest) = if t = text then SOME (List.revAppend (seen, rest)) else take (t :: seen, rest)
    in
      case take ([], !owed) of
        SOME rest => owed := rest
      | NONE => (TextIO.output (TextIO.stdErr, text);
                 case !printed of SOME ts => printed := SOME (text :: ts) | NONE => ())
    end

  (* The errors a compile that goes on after an error has reported so far
     (Elaborate.recover): each is printed when it is found. *)
  val errors = ref 0
  val () = CompilerState.cellRoot ("Error.errors", errors)
  fun report (sp, msg) =
    ((if !silent then () else output (!show ("error", sp, msg) ^ "\n"));
     errors := !errors + 1; note ("error", sp, msg))

  val warnings : (Source.span * string) list ref = ref []
  val () = CompilerState.cellRoot ("Error.warnings", warnings)

  fun warn (sp, msg) = (warnings := (sp, msg) :: !warnings; note ("warning", sp, msg))

  (* the warnings shown, newest first, where they are kept (SOME): what a
     compile that is up to date gives again (UnitMemo; the driver keeps them
     from where it starts to keep what it reads) *)
  val given : (Source.span * string) list option ref = ref NONE
  val () = CompilerState.cellRoot ("Error.given", given)

  fun flushWarnings () =
    (if !silent then ()
     else (List.app (fn w => output (!show ("warning", #1 w, #2 w) ^ "\n")) (List.rev (!warnings));
           case !given of SOME ws => given := SOME (!warnings @ ws) | NONE => ());
     warnings := [])

  (* Internal invariant violations: not user errors. *)
  exception Bug of string
  fun bug msg = raise Bug ("internal compiler error: " ^ msg)
end
