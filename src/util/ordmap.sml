(* Persistent ordered maps (AVL trees). Deterministic iteration order is
   required so that all three compiler builds emit identical bytecode. *)

signature ORD_KEY =
sig
  type ord_key
  val compare : ord_key * ord_key -> order
end

signature ORD_MAP =
sig
  type key
  type 'a map
  val empty : 'a map
  val isEmpty : 'a map -> bool
  val singleton : key * 'a -> 'a map
  val insert : 'a map * key * 'a -> 'a map
  val find : 'a map * key -> 'a option
  val lookup : 'a map * key -> 'a           (* raises NotFound *)
  val member : 'a map * key -> bool
  val remove : 'a map * key -> 'a map
  val numItems : 'a map -> int
  val listItems : 'a map -> 'a list
  val listItemsi : 'a map -> (key * 'a) list
  val listKeys : 'a map -> key list
  val foldl : ('a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val foldli : (key * 'a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val foldri : (key * 'a * 'b -> 'b) -> 'b -> 'a map -> 'b
  val app : ('a -> unit) -> 'a map -> unit
  val appi : (key * 'a -> unit) -> 'a map -> unit
  val map : ('a -> 'b) -> 'a map -> 'b map
  val mapi : (key * 'a -> 'b) -> 'a map -> 'b map
  val filteri : (key * 'a -> bool) -> 'a map -> 'a map
  (* unionWith f (m1, m2): keys of m2 override m1 unless f is used to combine. *)
  val unionWith : ('a * 'a -> 'a) -> 'a map * 'a map -> 'a map
  val fromList : (key * 'a) list -> 'a map
  exception NotFound
end

functor OrdMapFn (Key : ORD_KEY) : ORD_MAP =
struct
  type key = Key.ord_key
  exception NotFound

  datatype 'a map = E | T of int * 'a map * key * 'a * 'a map

  val empty = E
  fun isEmpty E = true | isEmpty _ = false

  fun height E = 0
    | height (T (h, _, _, _, _)) = h

  fun mk (l, k, v, r) =
    let val hl = height l and hr = height r
    in T ((if hl > hr then hl else hr) + 1, l, k, v, r) end

  fun rotL (T (_, l, k, v, T (_, rl, rk, rv, rr))) = mk (mk (l, k, v, rl), rk, rv, rr)
    | rotL t = t
  fun rotR (T (_, T (_, ll, lk, lv, lr), k, v, r)) = mk (ll, lk, lv, mk (lr, k, v, r))
    | rotR t = t

  fun bal (l, k, v, r) =
    let val hl = height l and hr = height r
    in
      if hl > hr + 1 then
        (case l of
           T (_, ll, _, _, lr) =>
             if height ll >= height lr then rotR (mk (l, k, v, r))
             else rotR (mk (rotL l, k, v, r))
         | E => mk (l, k, v, r))
      else if hr > hl + 1 then
        (case r of
           T (_, rl, _, _, rr) =>
             if height rr >= height rl then rotL (mk (l, k, v, r))
             else rotL (mk (l, k, v, rotR r))
         | E => mk (l, k, v, r))
      else T ((if hl > hr then hl else hr) + 1, l, k, v, r)
    end

  fun singleton (k, v) = T (1, E, k, v, E)

  (* insert and find, the hottest code of the compiler, recurse through a
     local function of one argument that closes over the key: going through
     the global function would allocate a tuple of arguments at every
     level. *)
  fun insert (m, k, v) =
    let
      fun go E = T (1, E, k, v, E)
        | go (T (h, l, k', v', r)) =
          (case Key.compare (k, k') of
             LESS => bal (go l, k', v', r)
           | GREATER => bal (l, k', v', go r)
           | EQUAL => T (h, l, k, v, r))
    in
      go m
    end

  fun find (m, k) =
    let
      fun go E = NONE
        | go (T (_, l, k', v, r)) =
          (case Key.compare (k, k') of
             LESS => go l
           | GREATER => go r
           | EQUAL => SOME v)
    in
      go m
    end

  fun lookup (m, k) = case find (m, k) of SOME v => v | NONE => raise NotFound
  fun member (m, k) = case find (m, k) of SOME _ => true | NONE => false

  fun removeMin (T (_, E, k, v, r)) = (k, v, r)
    | removeMin (T (_, l, k, v, r)) =
      let val (mk', mv, l') = removeMin l in (mk', mv, bal (l', k, v, r)) end
    | removeMin E = raise NotFound

  fun remove (E, _) = E
    | remove (T (_, l, k', v', r), k) =
      (case Key.compare (k, k') of
         LESS => bal (remove (l, k), k', v', r)
       | GREATER => bal (l, k', v', remove (r, k))
       | EQUAL =>
         (case (l, r) of
            (E, _) => r
          | (_, E) => l
          | _ => let val (mk', mv, r') = removeMin r in bal (l, mk', mv, r') end))

  (* The folds and mapi recurse through a local function too, where the
     curried global one would build two closures at every node. *)
  fun foldli f acc m =
    let
      fun go (E, acc) = acc
        | go (T (_, l, k, v, r), acc) = go (r, f (k, v, go (l, acc)))
    in
      go (m, acc)
    end

  fun foldri f acc m =
    let
      fun go (E, acc) = acc
        | go (T (_, l, k, v, r), acc) = go (l, f (k, v, go (r, acc)))
    in
      go (m, acc)
    end

  fun foldl f acc m = foldli (fn (_, v, a) => f (v, a)) acc m

  fun numItems m = foldl (fn (_, n) => n + 1) 0 m
  fun listItemsi m = foldri (fn (k, v, acc) => (k, v) :: acc) [] m
  fun listItems m = foldri (fn (_, v, acc) => v :: acc) [] m
  fun listKeys m = foldri (fn (k, _, acc) => k :: acc) [] m

  fun app f m = foldl (fn (v, ()) => f v) () m
  fun appi f m = foldli (fn (k, v, ()) => f (k, v)) () m

  fun mapi f m =
    let
      fun go E = E
        | go (T (h, l, k, v, r)) = T (h, go l, k, f (k, v), go r)
    in
      go m
    end
  fun map f m = mapi (fn (_, v) => f v) m

  fun filteri p m =
    foldli (fn (k, v, acc) => if p (k, v) then insert (acc, k, v) else acc) E m

  (* Fold the (usually much smaller) second map into the first; the cost is
     proportional to the size of m2, not of m1 (see docs/plans/performance.md). *)
  fun unionWith f (m1, m2) =
    foldli (fn (k, v2, acc) =>
              case find (acc, k) of
                NONE => insert (acc, k, v2)
              | SOME v1 => insert (acc, k, f (v1, v2))) m1 m2

  fun fromList l = List.foldl (fn ((k, v), m) => insert (m, k, v)) E l
end

structure StringMap = OrdMapFn (struct type ord_key = string val compare = String.compare end)
structure IntMap = OrdMapFn (struct type ord_key = int val compare = Int.compare end)
