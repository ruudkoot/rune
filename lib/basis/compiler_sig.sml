(* What a program can ask of the compiler it runs beside: in the REPL
   (`rune-repl`, docs/repl.md) the compiler is in the same program as the
   code it compiled, and a program compiles more of itself with `use`.

   A program compiled by `rune` and run by `runevm` has no compiler beside
   it: there `use` raises `Fail`, and the rest is there to be set and read
   with nothing reading it.

   This signature is Rune's own. Poly/ML keeps the same things in its
   structure PolyML.Compiler, and SML/NJ in Compiler.Control.

   Area: The runtime

   Status: extension

   Deviation: `COMPILER/not-in-the-specification`. The specification
   regards a program as interactive (Chapter 8 of the Definition) and says
   nothing of how one is fed to the compiler, so the REPL's controls are
   every implementation's own.

   See also: `RUNTIME` *)
signature COMPILER =
sig
  (* `use file` compiles the top-level declarations of `file` and runs
     them, one after another, as if they had been typed at the REPL.

     Each extends the declarations before it, and those after it see them.
     A declaration that does not compile stops the file there: its error is
     reported, and the declarations before it are kept. One whose running
     raises an exception stops the file too, and the exception goes on to
     the caller of `use`, its effects and the declarations before it kept.
     `use` may be called by a declaration that `use` is running.

     Raises: `Fail` in a program that has no compiler beside it, or when a
     declaration of the file does not compile; `IO.Io` if the file cannot
     be read. *)
  val use : string -> unit

  (* How deep the REPL prints a value, from the outside in.

     The levels it counts are those of a list, a tuple, a record, a
     constructor's argument and a `ref`'s content; past them it writes
     `...` for the rest. *)
  val printDepth : int ref

  (* What the REPL writes before it reads a declaration. *)
  val prompt1 : string ref

  (* What the REPL writes before each line that continues a declaration. *)
  val prompt2 : string ref
end
