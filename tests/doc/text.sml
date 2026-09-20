(* The language of doc comments. Plain prose is a paragraph, and so is this
   second sentence; `code` stands between backquotes and may
   `wrap over the end of a line`. A bare URL such as
   https://smlfamily.github.io/Basis/list.html is a link (the full stop after
   it is not part of it). Characters that Markdown takes for markup are text:
   *stars*, _underscores_, <angles>, [brackets], a | bar, 'a and "quotes".

   Subject: an explanation. A word and a colon at the start of a paragraph is
   the house style and means nothing, unless the word is reserved.

   A list follows a blank line:

   - the first item, which goes on
     over a second line;
   - the second item, with `code`.

   Code is indented by four, after a blank line:

       val xs = List.tabulate (3, fn i => i)

       val ys = List.rev xs

   Area: Lists

   Status: optional

   See also: `OTHER`, `List.map` *)
signature TEXT =
sig
  (* A reading of the specification, pinned by checks.

     Reading: `Text.t/abstract`. The page says nothing about equality; the type
     is taken to be abstract.

     Pinned by: `Text.t/*`, `Text:TEXT/matches`

     Reading (the suite differs): `Text.size/empty`. Rune answers 0.

     Erratum: `TEXT/typo`. The page says "Ow".

     Deviation: `Text.t/transparent`. The type is a string here.

     Implementation: `Text.maxSize/value`. 1073741823.

     Limitation: `Text.locale/none`. There are no locales. *)
  type t

  (* ---- Usage heads ---- *)

  (* `take (l, i)` is the first `i` elements of `l`; `take (l, length l)` is `l`.

     Raises: `Subscript` if `i < 0` or `i > length l`.

     Law: `take (l, i) @ drop (l, i) = l`

     Complexity: linear in `i`.

     Example: `take ([1, 2, 3], 2) = [1, 2]` *)
  val take : 'a list * int -> 'a list

  (* `l @ m` is `l` followed by `m`: an infix identifier is applied infix. *)
  val @ : 'a list * 'a list -> 'a list

  (* `<< (w, n)` shifts left: a symbolic identifier that is not infix. *)
  val << : word * word -> word

  (* `foldl f init l` has three arguments. *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b

  (* `scan getc strm` has an argument more than the type shows arrows: the
     result may abbreviate a function type. *)
  val scan : (char, 'a) reader -> (int, 'a) reader

  (* `make {size, fill}` takes a record. *)
  val make : {size : int, fill : char} -> t

  (* The largest size; a constant has no head. *)
  val maxSize : int

  (* `toLarge i` and `fromLarge i` convert to and from the largest integers;
     the two that follow are documented by this comment. *)
  val toLarge : int -> IntInf.int
  val fromLarge : IntInf.int -> int
  val unrelated : int

  (* `first x` is documented; the next value is not adjacent. *)
  val first : int -> int

  val second : int -> int
end

(* A structure says what it implements.

   Implements: TEXT where type t = string

   Status: optional *)
structure Text = struct end
