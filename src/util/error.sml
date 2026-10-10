(* Compile-time diagnostics. *)
structure Error =
struct
  exception CompileError of Source.span * string

  fun error (sp, msg) = raise CompileError (sp, msg)

  fun format (sp, msg) = Source.describe sp ^ ": error: " ^ msg

  (* The errors a compile that goes on after an error has reported so far
     (Elaborate.recover): each is printed when it is found. *)
  (* each error and warning as data too, when wanted: severity, span,
     message (the compiler as a service, Serve) *)
  val keep = ref false
  val kept : (string * Source.span * string) list ref = ref []
  fun note (severity, sp, msg) = if !keep then kept := (severity, sp, msg) :: !kept else ()

  val errors = ref 0
  fun report (sp, msg) =
    (TextIO.output (TextIO.stdErr, format (sp, msg) ^ "\n"); errors := !errors + 1; note ("error", sp, msg))

  val warnings : string list ref = ref []

  fun warn (sp, msg) =
    (warnings := (Source.describe sp ^ ": warning: " ^ msg) :: !warnings; note ("warning", sp, msg))

  fun flushWarnings () =
    (List.app (fn w => TextIO.output (TextIO.stdErr, w ^ "\n")) (List.rev (!warnings));
     warnings := [])

  (* Internal invariant violations: not user errors. *)
  exception Bug of string
  fun bug msg = raise Bug ("internal compiler error: " ^ msg)
end
