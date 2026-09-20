(* signature COMMAND_LINE, transcribed from
   https://smlfamily.github.io/Basis/command-line.html *)
signature COMMAND_LINE =
sig
  val name : unit -> string
  val arguments : unit -> string list
end
