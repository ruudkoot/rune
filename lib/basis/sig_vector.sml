(* Vectors: immutable sequences of a fixed length, of any element type.

   A vector is indexed from 0 and is made once: there is no `update` that
   changes one, only one that gives a new vector. `ARRAY` is the mutable
   counterpart, `VECTOR_SLICE` describes a stretch of a vector without
   copying it, and the `MONO_VECTOR` structures are the same thing for one
   element type, which lets an implementation pack the elements.

   The traversals come in pairs: `app`, `map`, `foldl`, `foldr`, `find` take
   a function of an element, and `appi`, `mapi`, `foldli`, `foldri`, `findi`
   one of the index and the element. `foldli` and `foldri` differ only in the
   order they visit: both pass the index.

   Area: Sequences

   See also: `ARRAY`, `VECTOR_SLICE`, `MONO_VECTOR`, `LIST`

   Erratum: `VECTOR/vector-spec`. The specification writes `eqtype 'a vector
   = 'a vector`, which the Definition does not allow as a specification; it is
   written here as an abbreviation of the top-level `vector`, which admits
   equality when its element type does. *)
signature VECTOR =
sig
  (* The type of vectors, the one of the top-level environment. *)
  type 'a vector = 'a vector

  (* The greatest length a vector may have.

     Implementation: `Vector.maxLen/value`. 100000000; an array has the same
     bound. *)
  val maxLen : int

  (* ---- Making a vector ---- *)

  (* `fromList l` is the vector of the elements of `l`, in order.

     Raises: `Size` if `l` is longer than `maxLen`. *)
  val fromList : 'a list -> 'a vector

  (* `tabulate (n, f)` is the vector of `f 0`, `f 1`, ..., `f (n - 1)`.

     `f` is applied in order of increasing index.

     Raises: `Size` if `n < 0` or `n > maxLen`, before `f` is applied at all. *)
  val tabulate : int * (int -> 'a) -> 'a vector

  (* ---- Elements ---- *)

  (* `length v` is the number of elements of `v`. *)
  val length : 'a vector -> int

  (* `sub (v, i)` is the element of `v` at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= length v`. *)
  val sub : 'a vector * int -> 'a

  (* `update (v, i, x)` is a new vector, like `v` but with `x` at position `i`.

     `v` itself does not change: a vector is immutable, so this copies.

     Raises: `Subscript` if `i < 0` or `i >= length v`.

     Complexity: linear in `length v`. *)
  val update : 'a vector * int * 'a -> 'a vector

  (* `concat l` is the vectors of `l` one after another.

     Raises: `Size` if the result would be longer than `maxLen`. *)
  val concat : 'a vector list -> 'a vector

  (* ---- Traversing ---- *)

  (* `appi f v` applies `f` to the index and the element of each position of `v`, from 0 up, for its effect. *)
  val appi : (int * 'a -> unit) -> 'a vector -> unit

  (* `app f v` applies `f` to every element of `v`, from 0 up, for its effect. *)
  val app : ('a -> unit) -> 'a vector -> unit

  (* `mapi f v` is the vector of the results of `f` on the index and the element of each position. *)
  val mapi : (int * 'a -> 'b) -> 'a vector -> 'b vector

  (* `map f v` is the vector of the results of `f` on each element, in order. *)
  val map : ('a -> 'b) -> 'a vector -> 'b vector

  (* `foldli f init v` combines the elements from the left, giving `f` the index as well. *)
  val foldli : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b

  (* `foldri f init v` combines the elements from the right, giving `f` the index as well. *)
  val foldri : (int * 'a * 'b -> 'b) -> 'b -> 'a vector -> 'b

  (* `foldl f init v` combines the elements from the left, as `List.foldl` does. *)
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b

  (* `foldr f init v` combines the elements from the right, as `List.foldr` does. *)
  val foldr : ('a * 'b -> 'b) -> 'b -> 'a vector -> 'b

  (* ---- Searching ---- *)

  (* `findi p v` is `SOME (i, x)` for the first position whose index and element satisfy `p`, or `NONE`.

     It stops at that position: `p` is not applied to what follows. *)
  val findi : (int * 'a -> bool) -> 'a vector -> (int * 'a) option

  (* `find p v` is `SOME x` for the first element that satisfies `p`, or `NONE`. *)
  val find : ('a -> bool) -> 'a vector -> 'a option

  (* `exists p v` is `true` when some element satisfies `p`; it stops at the first that does. *)
  val exists : ('a -> bool) -> 'a vector -> bool

  (* `all p v` is `true` when every element satisfies `p`; it stops at the first that does not. *)
  val all : ('a -> bool) -> 'a vector -> bool

  (* `collate cmp (v, w)` compares two vectors lexicographically with `cmp` for the elements.

     The answer is that of `cmp` on the first pair of elements at the same
     position that are not `EQUAL`; if there is none, the shorter vector is
     `LESS`. *)
  val collate : ('a * 'a -> order) -> 'a vector * 'a vector -> order
end
