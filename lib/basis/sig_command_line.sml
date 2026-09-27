(* The name of the program and the arguments it was given.

   Area: The operating system

   See also: `OS`, `UNIX` *)
signature COMMAND_LINE =
sig
  (* `name ()` is the name under which the program was called.

     Implementation: `CommandLine.name/system`. What the operating system
     passed to the program, which need not be a path that leads to it.

     Pinned by: `CommandLine.name/nonempty`, `CommandLine.name/stable`

     Example: `size (name ()) > 0 = true` *)
  val name : unit -> string

  (* `arguments ()` is the list of the arguments that follow the name, in order.

     The name is not among them: a command of `n` words, the name included,
     gives `n - 1` arguments.

     Reading: `CommandLine.arguments/none-under-the-runner`. Which arguments
     a program sees is "operating system and implementation-specific": what
     the system passes after the name, with nothing taken away, and the empty
     list when it passes none. *)
  val arguments : unit -> string list
end
