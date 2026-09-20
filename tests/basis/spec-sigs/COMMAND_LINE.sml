(* signature COMMAND_LINE, transcribed from
   https://smlfamily.github.io/Basis/command-line.html *)
signature SPEC_COMMAND_LINE =
sig
  val name : unit -> string
  val arguments : unit -> string list
end
