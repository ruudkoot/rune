(* The Core interpreter (the haskell98 roadmap, M8): Launchbury's natural
   semantics of laziness as the specification, and Sestoft's machine as
   the program, slow by design. A `let` puts a suspension in the heap; a
   variable forced is evaluated once, under a marker that blackholes it,
   and updated with its value; a `case` waits on the stack for its
   scrutinee. Types are erased.

   It is rhc's nearest reference: what the VM prints of a Core program, the
   interpreter must print too. An exception that passes a suspension under
   evaluation puts the suspension back, so that it raises again when it is
   forced again; a suspension forced under its own evaluation raises
   `NonTermination`. The stack lives in the heap, so a deep recursion is a
   bound of the interpreter's and not the host's.

   Area: Languages *)
signature CORE_INTERP =
sig
  (* How a run ended. Every outcome but `Exit 0` is a failure, and a
     raise, a stack too deep and steps run out are one bottom. *)
  datatype outcome =
      Exit of int                   (* `main` returned, 0, or `exit` was called with the status *)
    | Raised of string * string     (* an exception that no `catch` took: its kind and its message *)
    | TooDeep                       (* the stack went deeper than the bound *)
    | OutOfSteps                    (* the steps ran out *)

  (* The interpreter met Core no rule of CoreLint allows: a variable not
     bound, a suspension given to a strict parameter, a value no
     alternative matches. *)
  exception Stuck of string

  (* `run {program, steps, depth, out, err}` runs `main` of `program`, a
     program CoreLint passed, and says how the run ended and the steps it
     took.

     What it prints to standard output goes to `out`, and to standard error
     to `err`. At most `steps` steps are taken where it is `SOME`, and the
     stack is at most `depth` deep.

     Raises: `Stuck` where `program` breaks a rule of Core, and where it has
     no `main`. *)
  val run : {program : Core.program, steps : int option, depth : int, out : string -> unit, err : string -> unit}
            -> {outcome : outcome, steps : int}
end
