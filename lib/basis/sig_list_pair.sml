(* Two lists walked side by side: pairing, and the traversals that take a
   function of an element of each.

   Every function comes in two forms. The plain one stops at the end of the
   shorter list and ignores the rest of the longer, so `zip ([1, 2, 3],
   [#"a"])` is `[(1, #"a")]`. The one whose name ends in `Eq` insists that
   the lists have the same length and raises `UnequalLengths` when they do
   not, so that a program can say which it means.

   Area: Lists and options

   See also: `LIST`, `OPTION` *)
signature LIST_PAIR =
sig
  (* Raised by the `Eq` functions when the two lists have different lengths. *)
  exception UnequalLengths

  (* ---- Pairing ---- *)

  (* `zip (l, m)` is the list of the pairs of the elements of `l` and `m` at the same position.

     It stops at the end of the shorter list.

     Law: `List.length (zip (l, m)) = Int.min (List.length l, List.length m)` *)
  val zip : 'a list * 'b list -> ('a * 'b) list

  (* `zipEq (l, m)` is `zip (l, m)`, and insists that the lists are as long as each other.

     Raises: `UnequalLengths` if `l` and `m` have different lengths. *)
  val zipEq : 'a list * 'b list -> ('a * 'b) list

  (* `unzip l` is the pair of the lists of the first and of the second components of the pairs of `l`.

     Law: `unzip (zip (l, m)) = (l, m)` when `l` and `m` are as long as each other *)
  val unzip : ('a * 'b) list -> 'a list * 'b list

  (* ---- Traversing ---- *)

  (* `app f (l, m)` applies `f` to the pairs of elements at the same position, from left to right, for its effect.

     Law: `app f (l, m) = List.app f (zip (l, m))` *)
  val app : ('a * 'b -> unit) -> 'a list * 'b list -> unit

  (* `appEq f (l, m)` is `app f (l, m)`, and insists that the lists are as long as each other.

     `f` is applied to the pairs up to the end of the shorter list before the
     exception is raised.

     Raises: `UnequalLengths` if `l` and `m` have different lengths. *)
  val appEq : ('a * 'b -> unit) -> 'a list * 'b list -> unit

  (* `map f (l, m)` is the list of the results of `f` on the pairs of elements at the same position.

     Law: `map f (l, m) = List.map f (zip (l, m))` *)
  val map : ('a * 'b -> 'c) -> 'a list * 'b list -> 'c list

  (* `mapEq f (l, m)` is `map f (l, m)`, and insists that the lists are as long as each other.

     Raises: `UnequalLengths` if `l` and `m` have different lengths. *)
  val mapEq : ('a * 'b -> 'c) -> 'a list * 'b list -> 'c list

  (* ---- Folding ---- *)

  (* `foldl f init (l, m)` combines the pairs of elements from the left, as `List.foldl` does.

     `f` takes the two elements and the accumulator, and the traversal stops
     at the end of the shorter list.

     Law: `foldl f init (l, m) = List.foldl (fn ((x, y), acc) => f (x, y, acc)) init (zip (l, m))` *)
  val foldl : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c

  (* `foldr f init (l, m)` combines the pairs of elements from the right, as `List.foldr` does. *)
  val foldr : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c

  (* `foldlEq f init (l, m)` is `foldl f init (l, m)`, and insists that the lists are as long as each other.

     `f` is applied to the pairs up to the end of the shorter list before the
     exception is raised.

     Raises: `UnequalLengths` if `l` and `m` have different lengths. *)
  val foldlEq : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c

  (* `foldrEq f init (l, m)` is `foldr f init (l, m)`, and insists that the lists are as long as each other.

     Raises: `UnequalLengths` if `l` and `m` have different lengths.

     Reading: `ListPair.foldrEq/raises-before-applying`. Folding from the
     right needs the last pair first, so the ends of both lists are reached
     before anything is combined: `f` is not applied at all when the lengths
     differ. *)
  val foldrEq : ('a * 'b * 'c -> 'c) -> 'c -> 'a list * 'b list -> 'c

  (* ---- Testing the pairs ---- *)

  (* `all p (l, m)` is `true` when every pair of elements at the same position satisfies `p`.

     It stops at the first pair that does not, and at the end of the shorter
     list, so `all p (l, [])` is `true`. *)
  val all : ('a * 'b -> bool) -> 'a list * 'b list -> bool

  (* `exists p (l, m)` is `true` when some pair of elements at the same position satisfies `p`.

     It stops at the first pair that does, and at the end of the shorter list. *)
  val exists : ('a * 'b -> bool) -> 'a list * 'b list -> bool

  (* `allEq p (l, m)` is `true` when the lists are as long as each other and every pair satisfies `p`.

     Reading: `ListPair.allEq/left-longer`. It answers `false` for lists of
     different lengths rather than raising `UnequalLengths`: it is the one
     `Eq` function that does not raise.

     Reading: `ListPair.allEq/applies-before-lengths-are-known`. The
     specification gives both an equivalent expression, which would apply `p`
     to nothing when the lengths differ, and an implementation note, which
     walks the lists together and stops at the first pair that fails. The
     note is what is implemented, and all three other systems do the same: `p`
     is applied to the pairs of the common prefix before the lengths are
     known. *)
  val allEq : ('a * 'b -> bool) -> 'a list * 'b list -> bool
end
