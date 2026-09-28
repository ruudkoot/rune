(* Generators: values drawn from the source of a case of a property.

   A generator reads the nodes of its own part of an implicit tree of random
   words, so that the parts of a value never draw from each other: that is
   what lets the shrinker change one part and leave the others be
   (docs/plans/quickcheck.md, D3). How a word becomes a value follows the
   generator principles of that roadmap: integers are small, on an edge, or
   anywhere in their range, a third each; a list's length is up to the size,
   often 0 or 1. The size grows from 0 over the cases of a run.

   Area: Property testing *)
signature GEN =
sig
  (* A generator of values of type `'a`. *)
  type 'a gen

  (* `sample g seed size` is the value `g` draws from the source of `seed`
     at `size`: the same value every time.

     Example: `sample (list int) 0w1 0 = []` *)
  val sample : 'a gen -> Word64.word -> int -> 'a

  (* `draw g (source, address)` is the value of `g` read at `address` of
     `source`: what the other structures of the library run a generator
     with. *)
  val draw : 'a gen -> PropertySource.source * PropertySource.position -> 'a

  (* `return x` always draws `x`.

     Example: `sample (return 3) 0w0 10 = 3` *)
  val return : 'a -> 'a gen

  (* `map f g` draws `f x` for the `x` that `g` draws. *)
  val map : ('a -> 'b) -> 'a gen -> 'b gen

  (* `map2 f (g, h)` draws `f (x, y)` for the `x` and `y` that `g` and `h`
     draw from their own parts. *)
  val map2 : ('a * 'b -> 'c) -> 'a gen * 'b gen -> 'c gen

  (* `bind g f` draws `x` from `g`, and then from `f x` in a part of its own. *)
  val bind : 'a gen -> ('a -> 'b gen) -> 'b gen

  (* `pair (g, h)` draws a pair, each component from its own part. *)
  val pair : 'a gen * 'b gen -> ('a * 'b) gen

  (* `triple (g, h, k)` draws a triple, each component from its own part. *)
  val triple : 'a gen * 'b gen * 'c gen -> ('a * 'b * 'c) gen

  (* `sized f` is the generator `f n` for the size `n` of the case. *)
  val sized : (int -> 'a gen) -> 'a gen

  (* `resize n g` is `g` at the size `n`. *)
  val resize : int -> 'a gen -> 'a gen

  (* `oneOf gs` draws from one of `gs`, each as likely; the first is the
     simplest.

     Raises: `Empty` if `gs` is empty. *)
  val oneOf : 'a gen list -> 'a gen

  (* `frequency ws` draws from one of the generators of `ws`, each as likely as
     its weight says; the first is the simplest.

     Raises: `Empty` if no weight is positive. *)
  val frequency : (int * 'a gen) list -> 'a gen

  (* `elements v` draws an element of `v`, each as likely; the first is the
     simplest.

     Raises: `Empty` if `v` is empty.

     Example: `sample (elements (Vector.fromList [7])) 0w5 3 = 7` *)
  val elements : 'a vector -> 'a gen

  (* `filter p g` draws from `g` until `p` holds, a hundred times at most,
     and then gives the case up: it is discarded, as a condition that does
     not hold discards it. *)
  val filter : ('a -> bool) -> 'a gen -> 'a gen

  (* `Discarded` is raised by a generator that gives its case up.

     The runner counts the case as discarded. It is the library's own, raised
     only while a case is drawn, never through the code under test. *)
  exception Discarded

  (* `fix f` is the generator `g` for which `g = f g`: a recursive generator.
     `f` must make its recursive draws smaller, by `resize`, so that they
     end. *)
  val fix : ('a gen -> 'a gen) -> 'a gen

  (* `intRange (lo, hi)` draws an integer of `[lo, hi]`.

     It is a third of the time small (within the size of 0), a third on an
     edge (0, 1, ~1, the bounds and their neighbours, powers of two and their
     neighbours), and a third anywhere.

     Raises: `Domain` if `hi < lo`.

     Example: `sample (intRange (5, 5)) 0w9 50 = 5` *)
  val intRange : int * int -> int gen

  (* `int` draws an integer of the whole range of `Int.int`, as `intRange`
     does; where `Int.int` has no bounds, of the range of 64 bits. *)
  val int : int gen

  (* `word` draws a word: a third of the time small, a third on an edge (0,
     1, the largest, powers of two and their neighbours, the top bit), a
     third anywhere. *)
  val word : word gen

  (* `word64` draws a 64-bit word as `word` draws a word. *)
  val word64 : Word64.word gen

  (* `char` draws a character: half the time any of the 256.

     The other half it is a letter or digit, a space or control, or a
     character that the syntax of numbers, characters and strings gives a
     meaning to. *)
  val char : char gen

  (* `real` draws a real: a special one, a small one, or any, a third of the time each.

     The special ones are the zeros, the infinities, a NaN, the smallest and
     largest subnormals and normals, 1, ~1, 0.5, 2^53 and the real after it.
     The small ones are integers and halves within the size. Any is any bit
     pattern. *)
  val real : real gen

  (* `bool` draws `true` and `false`, each half the time; `false` is the
     simpler. *)
  val bool : bool gen

  (* `unit` draws `()`. *)
  val unit : unit gen

  (* `order` draws `LESS`, `EQUAL` or `GREATER`, each a third of the time. *)
  val order : order gen

  (* `option g` draws `NONE` a quarter of the time, and `SOME` of what `g`
     draws otherwise. *)
  val option : 'a gen -> 'a option gen

  (* `list g` draws a list of elements of `g`, of a length up to the size.

     Its length is 0 or 1 an eighth of the time each. Each element has a part
     of its own and a mark the shrinker may clear, which removes it. *)
  val list : 'a gen -> 'a list gen

  (* `listOf n g` draws a list of the length `n` draws, of elements of `g`
     (with no marks: the shrinker shortens it from its end). *)
  val listOf : int gen -> 'a gen -> 'a list gen

  (* `string` draws a string of characters of `char`, of a length as `list`
     draws one. *)
  val string : string gen

  (* `vector g` draws a vector as `list g` draws a list. *)
  val vector : 'a gen -> 'a vector gen

  (* `array g` draws an array as `list g` draws a list: a fresh one at every
     draw, so that two draws of the same case do not share it. *)
  val array : 'a gen -> 'a array gen

  (* `function (co, g)` draws a function, whose result at `x` is drawn at `co x`.

     The result comes from the part of the tree that the observation `co x`
     names, so that the function gives the same result for arguments that
     `co` does not tell apart. *)
  val function : ('a -> Word64.word) * 'b gen -> ('a -> 'b) gen

  (* `functionOf (co, showArg, showRes, g)` draws a function of any of the three kinds of D5.

     A node chooses the kind: pure, as `function` draws (the simplest);
     raising `Generated` at a quarter of the arguments; or observing its
     effects, whose calls a law compares on its two sides. Every call is
     logged, and the report shows the calls of a counterexample's function
     as a table. The shrinker makes a function a constant of its kind where
     it can: a pure one gives the simplest value everywhere, and a raising
     one raises everywhere. *)
  val functionOf : ('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen

  (* `pureOf (co, showArg, showRes, g)` draws a pure function, as `function`
     does, whose calls the report shows. *)
  val pureOf : ('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen

  (* `Generated` is what a raising function of `functionOf` raises. *)
  exception Generated
end
