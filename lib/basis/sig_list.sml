(* Polymorphic, immutable, singly linked lists.

   A list is either `nil` (written `[]`) or an element consed onto a list with
   `::`; the notation `[a, b, c]` abbreviates `a :: b :: c :: nil`. Everything
   that needs the n-th element or the length walks the list from the front, so
   those operations take time proportional to the position they reach.
   Positions are counted from 0.

   Functions that take a function argument apply it to the elements from left
   to right unless the entry says otherwise, which matters when the function
   has an effect. The datatype, the exception `Empty` and the values `null`,
   `length`, `@`, `hd`, `tl`, `rev`, `app`, `map`, `foldl` and `foldr` are
   also in the top-level environment.

   Area: Lists and options

   See also: `LIST_PAIR`, `OPTION`, `VECTOR`, `ARRAY`, `STRING_CVT` *)
signature LIST =
sig
  (* ---- Types and exceptions ---- *)

  (* The type of lists, the one of the top-level environment.

     It admits equality when its element type does. The constructors are
     `nil`, the empty list, and the infix `::` (right associative, precedence
     5), which puts an element in front of a list.

     Erratum: `LIST/list-spec`. The specification writes the datatype out in
     the signature. The Definition (Section 2.9) does not allow `nil` and `::`
     to be specified, so the signature replicates the top-level datatype
     instead; the meaning is the same. *)
  datatype list = datatype list

  (* Raised by `hd`, `tl` and `last` when they are given the empty list. It is
     the same exception as the top-level `Empty`. *)
  exception Empty

  (* ---- Taking lists apart ---- *)

  (* `null l` is `true` exactly when `l` is empty.

     Unlike `l = []` it does not need an equality type. *)
  val null : 'a list -> bool

  (* `length l` is the number of elements of `l`.

     Law: `length (l @ m) = length l + length m`

     Complexity: linear in the length; constant stack. *)
  val length : 'a list -> int

  (* `l @ m` is the list of the elements of `l` followed by those of `m`.

     It is infix and right associative with precedence 5, the same as `::`, so
     `1 :: [2] @ [3]` needs no parentheses.

     Complexity: linear in `length l`; `m` is shared, not copied. Appending to
     the right in a loop is therefore quadratic: cons onto the front and
     reverse at the end, or use `revAppend`. *)
  val @ : 'a list * 'a list -> 'a list

  (* `hd l` is the first element of `l`.

     Raises: `Empty` if `l` is empty. *)
  val hd : 'a list -> 'a

  (* `tl l` is `l` without its first element.

     Raises: `Empty` if `l` is empty. *)
  val tl : 'a list -> 'a list

  (* `last l` is the final element of `l`.

     Raises: `Empty` if `l` is empty.

     Complexity: linear in the length; constant stack. *)
  val last : 'a list -> 'a

  (* `getItem l` is `NONE` for the empty list and `SOME (hd l, tl l)`
     otherwise.

     It has the shape of a `StringCvt.reader`, so a list can be the stream
     that a `scan` function reads from.

     Example: `Int.scan StringCvt.DEC List.getItem (explode "42 rest")` is
     `SOME (42, [#" ", #"r", #"e", #"s", #"t"])`. *)
  val getItem : 'a list -> ('a * 'a list) option

  (* `nth (l, i)` is the element of `l` at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length l`.

     Complexity: linear in `i`. *)
  val nth : 'a list * int -> 'a

  (* `take (l, i)` is the list of the first `i` elements of `l`; `take (l,
     length l)` is `l`.

     Raises: `Subscript` if `i < 0` or `i > length l`.

     Law: `take (l, i) @ drop (l, i) = l` for `0 <= i <= length l` *)
  val take : 'a list * int -> 'a list

  (* `drop (l, i)` is what is left of `l` after its first `i` elements.

     The result shares its cells with `l`: nothing is copied.

     Raises: `Subscript` if `i < 0` or `i > length l`. *)
  val drop : 'a list * int -> 'a list

  (* ---- Building lists ---- *)

  (* `rev l` is the list of the elements of `l` in the opposite order.

     Law: `rev (rev l) = l` *)
  val rev : 'a list -> 'a list

  (* `concat ls` appends all the lists of `ls`, in order.

     Law: `concat [l, m, n] = l @ m @ n` *)
  val concat : 'a list list -> 'a list

  (* `revAppend (l, m)` is `rev l @ m`, built in one pass over `l` and without
     the intermediate list.

     It is the usual way to finish a loop that accumulated its results back to
     front.

     Law: `revAppend (l, m) = rev l @ m` *)
  val revAppend : 'a list * 'a list -> 'a list

  (* ---- Transforming ---- *)

  (* `app f l` applies `f` to every element of `l`, from left to right, for its
     effect. *)
  val app : ('a -> unit) -> 'a list -> unit

  (* `map f l` is the list of the results of applying `f` to each element of
     `l`, from left to right.

     Law: `map f (map g l) = map (f o g) l` when `f` and `g` have no effects *)
  val map : ('a -> 'b) -> 'a list -> 'b list

  (* `mapPartial f l` applies `f` to each element of `l` and keeps the `v` of
     every result `SOME v`, in order.

     Elements for which `f` answers `NONE` leave nothing behind: it is a `map`
     and a `filter` in one pass.

     Law: `mapPartial f l = map valOf (filter isSome (map f l))` *)
  val mapPartial : ('a -> 'b option) -> 'a list -> 'b list

  (* ---- Searching ---- *)

  (* `find p l` is `SOME x` for the first element `x` of `l` that satisfies
     `p`, and `NONE` if there is none.

     `p` is not applied to the elements after `x`. *)
  val find : ('a -> bool) -> 'a list -> 'a option

  (* `filter p l` is the list of the elements of `l` that satisfy `p`, in their
     original order.

     `p` is applied to every element, from left to right. *)
  val filter : ('a -> bool) -> 'a list -> 'a list

  (* `partition p l` is the pair of the elements of `l` that satisfy `p` and of
     those that do not.

     Both lists keep the original order, and `p` is applied once to every
     element, from left to right.

     Law: `partition p l = (filter p l, filter (not o p) l)` when `p` has no
     effects *)
  val partition : ('a -> bool) -> 'a list -> 'a list * 'a list

  (* ---- Folding and testing the elements ---- *)

  (* `foldl f init l` combines the elements of `l` from the left: `f (xn, ... f
     (x2, f (x1, init)) ...)`.

     The accumulator is the second component of the argument of `f`, and
     `foldl f init [] = init`.

     Law: `foldl (op ::) [] l = rev l`

     Example: `foldl (op -) 0 [1, 2, 3] = 2`, which is `3 - (2 - (1 - 0))`.

     Complexity: one application of `f` per element; constant stack. *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b

  (* `foldr f init l` combines the elements of `l` from the right: `f (x1, f
     (x2, ... f (xn, init) ...))`.

     `foldr f init [] = init`.

     Law: `foldr (op ::) [] l = l`

     Example: `foldr (op -) 0 [1, 2, 3] = 2`, which is `1 - (2 - (3 - 0))`. *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a list -> 'b

  (* `exists p l` is `true` when some element of `l` satisfies `p`; it stops at
     the first one that does.

     `exists p []` is `false`.

     Law: `exists p l = not (all (not o p) l)` *)
  val exists : ('a -> bool) -> 'a list -> bool

  (* `all p l` is `true` when every element of `l` satisfies `p`; it stops at
     the first one that does not.

     `all p []` is `true`. *)
  val all : ('a -> bool) -> 'a list -> bool

  (* ---- Making and comparing ---- *)

  (* `tabulate (n, f)` is `[f 0, f 1, ..., f (n - 1)]`; `f` is applied in order
     of increasing argument.

     Raises: `Size` if `n < 0`, before `f` is applied at all.

     Law: `tabulate (length l, fn i => nth (l, i)) = l` *)
  val tabulate : int * (int -> 'a) -> 'a list

  (* `collate cmp (l, m)` compares `l` and `m` lexicographically, with `cmp`
     for the elements.

     The answer is that of `cmp` on the first pair of elements at the same
     position that are not `EQUAL`; if there is no such pair the shorter list
     is `LESS`, and lists of the same length are `EQUAL`. `cmp` is not applied
     beyond the deciding pair.

     Example: `collate Int.compare ([1, 2], [1, 2, 0]) = LESS` *)
  val collate : ('a * 'a -> order) -> 'a list * 'a list -> order
end
