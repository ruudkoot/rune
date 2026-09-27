(* CommandLine: the name the program was run under and the arguments it was
   given, as the operating system passed them to the VM.

   Implements: COMMAND_LINE *)
structure CommandLine =
struct
  val name = _prim "command_name" : unit -> string
  val arguments = _prim "command_args" : unit -> string list
end
