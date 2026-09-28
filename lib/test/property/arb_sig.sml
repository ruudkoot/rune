(* Arbitraries: the generator, the printer, the observer and the equality of
   a type, as one record -- what QuickCheck finds by a type class and a
   program here passes by name (docs/plans/quickcheck.md, D4).

   Area: Property testing *)
signature ARB =
sig
  (* The record of a type: `eq` is `NONE` where the type has no equality of
     its own and none is given, and is then the equality of what `show`
     shows. *)
  type 'a arb = {gen : 'a Gen.gen, show : 'a -> string, co : 'a -> Word64.word,
                 eq : ('a * 'a -> bool) option}

  (* `equal a (x, y)` is the equality of `a`: its `eq`, or the equality of
     what its `show` shows. *)
  val equal : 'a arb -> 'a * 'a -> bool

  (* `int` is the arbitrary of `Int.int`. *)
  val int : int arb

  (* `word` is the arbitrary of `Word.word`. *)
  val word : word arb

  (* `word64` is the arbitrary of `Word64.word`. *)
  val word64 : Word64.word arb

  (* `char` is the arbitrary of `Char.char`. *)
  val char : char arb

  (* `string` is the arbitrary of `String.string`. *)
  val string : string arb

  (* `real` is the arbitrary of `Real.real`, whose equality is identity.

     Identity is the same number, with the zeros told apart and every NaN
     equal to every other (docs/plans/quickcheck.md, D6). *)
  val real : real arb

  (* `bool` is the arbitrary of `bool`. *)
  val bool : bool arb

  (* `unit` is the arbitrary of `unit`. *)
  val unit : unit arb

  (* `order` is the arbitrary of `order`. *)
  val order : order arb

  (* `option a` is the arbitrary of options of `a`. *)
  val option : 'a arb -> 'a option arb

  (* `list a` is the arbitrary of lists of `a`. *)
  val list : 'a arb -> 'a list arb

  (* `vector a` is the arbitrary of vectors of `a`. *)
  val vector : 'a arb -> 'a vector arb

  (* `array a` is the arbitrary of arrays of `a`, compared by their elements:
     a fresh array at every draw. *)
  val array : 'a arb -> 'a array arb

  (* `intInf` is the arbitrary of `IntInf.int`, drawn by `Gen.intInf`. *)
  val intInf : IntInf.int arb

  (* `reference a` is the arbitrary of references to `a`: a new one at every
     draw, and equal only to itself, as `=` on references is. *)
  val reference : 'a arb -> 'a ref arb

  (* `enum xs` is the arbitrary of the values of `xs`, each shown as its name:
     the arbitrary of a datatype with no values in its constructors. The first
     is the simplest.

     Raises: `Empty` if `xs` is empty.

     Example: `#show (enum [(LESS, "LESS"), (GREATER, "GREATER")]) GREATER = "GREATER"` *)
  val enum : (''a * string) list -> ''a arb

  (* `vectorSlice a` is the arbitrary of slices of vectors of `a`: a vector,
     and a start and a length within it.

     Two slices are equal when their vectors have equal elements and their
     starts and lengths are the same. *)
  val vectorSlice : 'a arb -> 'a VectorSlice.slice arb

  (* `arraySlice a` is the arbitrary of slices of arrays of `a`, as
     `vectorSlice` draws them, over a fresh array at every draw. *)
  val arraySlice : 'a arb -> 'a ArraySlice.slice arb

  (* `array2 a` is the arbitrary of two-dimensional arrays of `a`.

     The numbers of rows and of columns are each drawn as a length is, at the
     square root of the size; an array with no rows has no columns. Two
     arrays are equal when they have the same dimensions and equal elements. *)
  val array2 : 'a arb -> 'a Array2.array arb

  (* `exn` is the arbitrary of exceptions: those of the Basis Library that
     carry no value, `Gen.Generated`, and `Fail` with any message.

     Two exceptions are equal when they have the same name, and, for `Fail`,
     the same message. *)
  val exn : exn arb

  (* `pair (a, b)` is the arbitrary of pairs. *)
  val pair : 'a arb * 'b arb -> ('a * 'b) arb

  (* `triple (a, b, c)` is the arbitrary of triples. *)
  val triple : 'a arb * 'b arb * 'c arb -> ('a * 'b * 'c) arb

  (* `function (a, b)` is the arbitrary of functions from `a` to `b`, of every kind of D5.

     A function is pure, raises `Gen.Generated` at some arguments, or
     observes its effects, which a law compares (docs/plans/quickcheck.md,
     D5 C). A function has no equality and is shown as `fn`; the report
     lists the calls of a counterexample's functions. *)
  val function : 'a arb * 'b arb -> ('a -> 'b) arb

  (* `pureFunction (a, b)` is the arbitrary of pure, total functions from `a` to `b`.

     It is for a law that says its function has no effects (D5, class A). *)
  val pureFunction : 'a arb * 'b arb -> ('a -> 'b) arb
end
