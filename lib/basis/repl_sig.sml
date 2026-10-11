(* What a program can ask of the REPL it runs in: its commands, as
   functions, for init files, scripts and HOL4 (docs/repl.md, Commands).

   In `rune-repl` the REPL puts its commands into the hooks of this
   structure when it starts, as it puts its `use` into `Compiler`'s; in a
   program compiled by `rune`, which has no REPL around it, every function
   raises `Fail`.

   Area: The runtime

   Status: extension

   Deviation: `REPL/not-in-the-specification`. The specification says
   nothing of a REPL's commands; this signature is Rune's own.

   See also: `COMPILER` *)
signature REPL =
sig
  (* `command line` runs a command of the REPL as if it had been typed:
     `command ":set depth 5"`, with or without the `:`.

     What the command writes goes where it would have gone.

     Raises: `Fail` where there is no REPL, or the command failed. *)
  val command : string -> unit

  (* `typeOf exp` is the type of the expression `exp`, which is not
     evaluated, as `:type` shows it.

     Raises: `Fail` where there is no REPL or `exp` does not elaborate. *)
  val typeOf : string -> string

  (* `info name` is what `:info` says of a name: what it is, and where it
     was defined.

     Raises: `Fail` where there is no REPL or nothing has the name. *)
  val info : string -> string

  (* `doc name` is the documentation `:doc` shows of a name of the Basis
     Library, with its Markdown laid out for a terminal.

     Raises: `Fail` where there is no REPL or the name has none. *)
  val doc : string -> string

  (* `search text` is what `:search` finds: values whose name holds the
     text, or, where the text is a type, whose type is like it. *)
  val search : string -> string

  (* `set (setting, value)` changes a setting of the REPL, as `:set` does:
     depth, length, string, width, feedback, prompt, prompt2, time.

     Raises: `Fail` where there is no REPL, or no such setting or value. *)
  val set : string * string -> unit

  (* `settings ()` is each setting and its value, as `:show` lists them. *)
  val settings : unit -> (string * string) list
end
