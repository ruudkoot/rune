(* Documents laid out at a width: Wadler's prettier printer, strictly, as
   Lindig wrote it, with annotations that a renderer turns into styles, and
   budgets that cut a document of a deep or long value short.

   A document is text, line breaks that become a blank (or nothing) when
   the group around them fits the rest of the line, nesting, groups and
   annotations. `sequence` is the document of a list, a tuple or a record:
   its items aligned after the opening bracket and separated, all on one
   line when they fit and one to a line when not; `bound` cuts sequences
   deeper, longer or more numerous than its budgets with `...`, as a
   REPL does with `printDepth` and `printLength`. Text is measured in
   display columns (`DisplayWidth`), so a CJK character takes two.

   Area: Text *)
signature PRETTY =
sig
  (* A document whose annotations are of type `'a`. *)
  type 'a doc

  (* Nothing. *)
  val empty : 'a doc

  (* `text s` is `s`, which should have no newline.

     Example: `render 80 (text "abc") = "abc"` *)
  val text : string -> 'a doc

  (* A newline and the indentation, or one blank when its group fits on
     the line. *)
  val line : 'a doc

  (* A newline and the indentation, or nothing when its group fits. *)
  val cut : 'a doc

  (* A newline always, which keeps the groups around it from fitting. *)
  val hardline : 'a doc

  (* `concat ds` is the documents one after the other.

     Example: `render 80 (concat [text "a", line, text "b"]) = "a\nb"` *)
  val concat : 'a doc list -> 'a doc

  (* `nest n d` is `d` with every newline in it indented by `n` more. *)
  val nest : int -> 'a doc -> 'a doc

  (* `group d` is `d` on one line, its breaks blanks or nothing, when that
     fits the width, and `d` with its breaks as newlines otherwise.

     Example: `render 80 (group (concat [text "a", line, text "b"])) = "a b"` *)
  val group : 'a doc -> 'a doc

  (* `annotate (a, d)` is `d` marked with `a`, which a renderer may show
     (a colour, a link) and layout passes on. *)
  val annotate : 'a * 'a doc -> 'a doc

  (* `sequence {opening, closing, separator} ds` is the items `ds` between
     the brackets, separated.

     It is `[1, 2, 3]` when that fits, and one item to a line, each aligned
     after the opening bracket, when it does not.

     Example: `render 6 (sequence {opening = "[", closing = "]", separator = ","}
     [text "1", text "22", text "333"]) = "[1,\n 22,\n 333]"` *)
  val sequence : {opening : string, closing : string, separator : string} -> 'a doc list -> 'a doc

  (* The text `...`, which stands for what a budget left out. *)
  val ellipsis : 'a doc

  (* `bound {depth, length, nodes} d` is `d` with what is past the budgets
     made `...`.

     A sequence nested more than `depth` deep is `...`; the items of a
     sequence after the first `length` are one `...`; the items after the
     first `nodes` of the whole document, counted depth first, are `...`.
     `NONE` is no limit.

     Example: `render 80 (bound {depth = NONE, length = SOME 2, nodes = NONE}
     (sequence {opening = "[", closing = "]", separator = ","} [text "1", text "2", text "3"])) = "[1, 2, ...]"` *)
  val bound : {depth : int option, length : int option, nodes : int option} -> 'a doc -> 'a doc

  (* What a layout is made of: text, a newline and its indentation, and
     the beginning and end of an annotation. *)
  datatype 'a piece = Text of string | Newline of int | Begin of 'a | End

  (* `layout w d` is `d` laid out at width `w`: as many groups on one line
     as fit, the outermost first. A line is wider than `w` only where a
     piece of text alone is. *)
  val layout : int -> 'a doc -> 'a piece list

  (* `render w d` is the layout of `d` as text, its annotations left out. *)
  val render : int -> 'a doc -> string

  (* `renderWith {width, start, finish} d` is the layout as text, with
     `start a` before what `a` annotates and `finish a` after it. *)
  val renderWith : {width : int, start : 'a -> string, finish : 'a -> string} -> 'a doc -> string

  (* `flat d` is `d` with every group on one line.

     Example: `flat (concat [text "a", line, text "b"]) = "a b"` *)
  val flat : 'a doc -> string
end
