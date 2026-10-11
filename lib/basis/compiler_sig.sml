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

  (* `compile {read, file, line}` reads top-level declarations from `read`
     and is the function that runs them, as if they had been typed at the
     REPL.

     It reads up to a `;` that ends a declaration at the top level, or to
     the end of what `read` gives (`NONE`); a caller that wants all of a
     reader compiles from it until it is at its end. `file` and `line` say
     where the characters are from, for the positions of errors and
     traces. The declarations are compiled and run one after another when
     the function is called, each extending those before it, as with
     `use`: a declaration that does not compile stops them, its error
     reported, and one that raises stops them, the exception going on to
     the caller. Poly/ML's PolyML.compiler is the same, a reader and its
     parameters in, a function that runs what it read out.

     Raises: `Fail` in a program that has no compiler beside it; the
     function raises `Fail` where a declaration does not compile. *)
  val compile : {read : unit -> char option, file : string, line : int} -> unit -> unit

  (* How deep the REPL prints a value, from the outside in.

     The levels it counts are those of a list, a tuple, a record, a
     constructor's argument and a `ref`'s content; past them it writes
     `...` for the rest. At 0 or below the REPL says nothing of what a
     declaration declared. *)
  val printDepth : int ref

  (* How many items of a list, an array or a vector the REPL prints (100);
     the rest print as one `...`. *)
  val printLength : int ref

  (* How many characters of a string the REPL prints (1,000); the rest
     print as `...` after the closing quote. *)
  val stringLength : int ref

  (* What the REPL writes before it reads a declaration. *)
  val prompt1 : string ref

  (* What the REPL writes before each line that continues a declaration. *)
  val prompt2 : string ref

  (* ---- Printers of one's own ---- *)

  (* Where in a source what a printer shows came from: the file, and the
     line and position it begins and ends at. *)
  type location = {file : string, startLine : int, startPosition : int, endLine : int, endPosition : int}

  (* What a block of a printer's output says beside its text: where it came
     from, or a property by name. Rune's REPL lays out the text alone. *)
  datatype context = ContextLocation of location | ContextProperty of string * string

  (* A document for `prettyPrint` to lay out, in Poly/ML's shape: text,
     places where a line may break, and blocks of them.

     `PrettyBlock (indent, consistent, context, items)` lays its items
     on one line where they fit; where they do not, a break of the block
     starts a new line `indent` further in than the block began, every
     break of the block where `consistent` and only those it needs where
     not. `PrettyBreak (blanks, offset)` is `blanks` spaces where the line
     does not break there, and where it does, the new line is `offset`
     further in. `PrettyLineBreak` always breaks the line,
     `PrettyString s` is `s`, and `PrettyStringWithWidth (s, w)` is `s`
     laid out as if it were `w` characters wide. *)
  datatype pretty =
      PrettyBlock of int * bool * context list * pretty list
    | PrettyBreak of int * int
    | PrettyLineBreak
    | PrettyString of string
    | PrettyStringWithWidth of string * int

  (* `prettyPrint (out, width) p` lays `p` out in lines of `width`
     characters where it can, and gives `out` the text, piece by piece.

     Example: `let val b = ref "" in prettyPrint (fn s => b := !b ^ s, 3) (PrettyBlock (2, false, [], [PrettyString "ab", PrettyBreak (1, 0), PrettyString "cd"])); !b end = "ab\n  cd"` *)
  val prettyPrint : (string -> unit) * int -> pretty -> unit

  (* How wide the REPL lays out a value where its output is not a terminal.

     It is the width of what the REPL's own printers make and what those of
     `addPrettyPrinter` make; on a terminal, the terminal's width is. *)
  val lineLength : int ref

  (* `addPrettyPrinter f` makes `f` the REPL's printer of the values of a
     type, as Poly/ML's PolyML.addPrettyPrinter does.

     The type is the one `f`'s third argument has where `addPrettyPrinter`
     is applied, which the compiler sees there: a datatype or an abstract
     type, at any arguments. `f depth args v` is what `v` shows as,
     `depth` the levels the REPL still shows, and `args` how to show the
     type's arguments: `()` for a type of none, for one a function of a
     value and a depth, and for more a tuple of them. A later printer of
     the same type takes the place of an earlier one.

     Where the type is not known where it is applied -- a type variable,
     in a function that installs printers -- or is declared by the same
     top-level declaration, nothing is installed; nor is anything in a
     program that has no compiler beside it, where nothing prints. *)
  val addPrettyPrinter : (int -> 'a -> 'b -> pretty) -> unit
end
