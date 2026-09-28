(* Laws, as the grammar of `Law:` paragraphs reads them
   (docs/plans/quickcheck.md, D7): the first piece of code is a law, and so
   is one after "and" that follows a law; one after "for" or "when" is a
   condition; "for `x` from `G`" is a domain; "when `f` has no effects" makes
   `f` pure; the rest is prose. *)
signature LAWS =
sig
  (* `twice f x` is `f (f x)`.

     Law: `twice f x = f (f x)` when `f` has no effects

     Law: `twice f (twice g x) = twice g (twice f x)` when `f` and `g` have no
     effects *)
  val twice : ('a -> 'a) -> 'a -> 'a

  (* `nth (l, i)` is the element of `l` at `i`.

     Law: `nth (l, 0) = hd l`, and `nth (l, i) = List.nth (l, i)`, for `not (null l)`
     and `0 <= i`, where `l` is any list: two laws, two conditions, and prose

     Law: `isSome (List.find (fn x => x = nth (l, i)) l)` for `l` from
     `nonEmpty` and `0 <= i andalso i < length l` *)
  val nth : 'a list * int -> 'a
end
