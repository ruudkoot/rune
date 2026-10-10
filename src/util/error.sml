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

  (* each error and warning as data too, when wanted: severity, span,
     message (the compiler as a service, Serve) *)
  val keep = ref false
  val kept : (string * Source.span * string) list ref = ref []
  fun note (severity, sp, msg) = if !keep then kept := (severity, sp, msg) :: !kept else ()

  (* The errors a compile that goes on after an error has reported so far
     (Elaborate.recover): each is printed when it is found. *)
  val errors = ref 0
  fun report (sp, msg) =
    (TextIO.output (TextIO.stdErr, !show ("error", sp, msg) ^ "\n"); errors := !errors + 1; note ("error", sp, msg))

  val warnings : (Source.span * string) list ref = ref []

  fun warn (sp, msg) = (warnings := (sp, msg) :: !warnings; note ("warning", sp, msg))

  fun flushWarnings () =
    (List.app (fn w => TextIO.output (TextIO.stdErr, !show ("warning", #1 w, #2 w) ^ "\n")) (List.rev (!warnings));
     warnings := [])

  (* Internal invariant violations: not user errors. *)
  exception Bug of string
  fun bug msg = raise Bug ("internal compiler error: " ^ msg)
end
