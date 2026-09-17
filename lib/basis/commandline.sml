(* CommandLine *)
structure CommandLine =
struct
  val name = _prim "command_name" : unit -> string
  val arguments = _prim "command_args" : unit -> string list
end
