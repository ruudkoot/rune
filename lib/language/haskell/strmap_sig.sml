(* Maps keyed by strings, as the front end's scopes, exports and tables
   need them: persistent, ordered by the keys, and balanced (red-black
   trees, inserting only), so that a fold visits the keys in order and a
   result does not depend on the order things were added.

   Area: Languages *)
signature HS_STRING_MAP =
sig
  (* A map from strings to values of type `'a`. *)
  type 'a map

  (* The map with no key. *)
  val empty : 'a map

  (* `insert (m, k, v)` is `m` with `k` mapped to `v`, in place of what `m`
     mapped it to. *)
  val insert : 'a map * string * 'a -> 'a map

  (* `find (m, k)` is what `m` maps `k` to, if anything. *)
  val find : 'a map * string -> 'a option

  (* `member (m, k)` is whether `m` maps `k`. *)
  val member : 'a map * string -> bool

  (* `foldl f init m` folds `f` over the keys and values of `m` in the
     order of the keys. *)
  val foldl : (string * 'a * 'b -> 'b) -> 'b -> 'a map -> 'b

  (* `listItems m` is the pairs of `m` in the order of the keys. *)
  val listItems : 'a map -> (string * 'a) list

  (* `size m` is the number of keys of `m`. *)
  val size : 'a map -> int
end
