(* Compile-time diagnostics. *)
structure Error =
struct
  exception CompileError of Source.span * string

  fun error (sp, msg) = raise CompileError (sp, msg)

  fun format (sp, msg) = Source.describe sp ^ ": error: " ^ msg

  val warnings : string list ref = ref []

  fun warn (sp, msg) =
    warnings := (Source.describe sp ^ ": warning: " ^ msg) :: !warnings

  fun flushWarnings () =
    (List.app (fn w => TextIO.output (TextIO.stdErr, w ^ "\n")) (List.rev (!warnings));
     warnings := [])

  (* Internal invariant violations: not user errors. *)
  exception Bug of string
  fun bug msg = raise Bug ("internal compiler error: " ^ msg)
end
