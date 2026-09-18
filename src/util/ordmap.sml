(* Persistent ordered maps (AVL trees). Deterministic iteration order is
   required so that all three compiler builds emit identical bytecode.

   The compiler must be compilable by Rune itself, which has no functors yet,
   so the generic map takes its comparison function as a value and StringMap /
   IntMap are plain structures specialising it. The interface of each
   specialised map is:

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
     val unionWith : ('a * 'a -> 'a) -> 'a map * 'a map -> 'a map
     val fromList : (key * 'a) list -> 'a map
     exception NotFound

   unionWith f (m1, m2): keys of m2 override m1 unless f is used to combine;
   the cost is proportional to the size of m2, so pass the smaller map second. *)

structure OrdMap =
struct
  exception NotFound

  datatype ('k, 'a) map = E | T of int * ('k, 'a) map * 'k * 'a * ('k, 'a) map

  val empty = E
  fun isEmpty E = true | isEmpty _ = false

  fun height E = 0
    | height (T (h, _, _, _, _)) = h

  fun mk (l, k, v, r) =
    T (Int.max (height l, height r) + 1, l, k, v, r)

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
      else mk (l, k, v, r)
    end

  fun singleton (k, v) = T (1, E, k, v, E)

  fun insert cmp (E, k, v) = singleton (k, v)
    | insert cmp (T (h, l, k', v', r), k, v) =
      (case cmp (k, k') of
         LESS => bal (insert cmp (l, k, v), k', v', r)
       | GREATER => bal (l, k', v', insert cmp (r, k, v))
       | EQUAL => T (h, l, k, v, r))

  fun find cmp (E, _) = NONE
    | find cmp (T (_, l, k', v, r), k) =
      (case cmp (k, k') of
         LESS => find cmp (l, k)
       | GREATER => find cmp (r, k)
       | EQUAL => SOME v)

  fun lookup cmp (m, k) = case find cmp (m, k) of SOME v => v | NONE => raise NotFound
  fun member cmp (m, k) = case find cmp (m, k) of SOME _ => true | NONE => false

  fun removeMin (T (_, E, k, v, r)) = (k, v, r)
    | removeMin (T (_, l, k, v, r)) =
      let val (mk', mv, l') = removeMin l in (mk', mv, bal (l', k, v, r)) end
    | removeMin E = raise NotFound

  fun remove cmp (E, _) = E
    | remove cmp (T (_, l, k', v', r), k) =
      (case cmp (k, k') of
         LESS => bal (remove cmp (l, k), k', v', r)
       | GREATER => bal (l, k', v', remove cmp (r, k))
       | EQUAL =>
         (case (l, r) of
            (E, _) => r
          | (_, E) => l
          | _ => let val (mk', mv, r') = removeMin r in bal (l, mk', mv, r') end))

  fun foldli f acc E = acc
    | foldli f acc (T (_, l, k, v, r)) = foldli f (f (k, v, foldli f acc l)) r

  fun foldri f acc E = acc
    | foldri f acc (T (_, l, k, v, r)) = foldri f (f (k, v, foldri f acc r)) l

  fun foldl f acc m = foldli (fn (_, v, a) => f (v, a)) acc m

  fun numItems m = foldl (fn (_, n) => n + 1) 0 m
  fun listItemsi m = foldri (fn (k, v, acc) => (k, v) :: acc) [] m
  fun listItems m = foldri (fn (_, v, acc) => v :: acc) [] m
  fun listKeys m = foldri (fn (k, _, acc) => k :: acc) [] m

  fun app f m = foldl (fn (v, ()) => f v) () m
  fun appi f m = foldli (fn (k, v, ()) => f (k, v)) () m

  fun mapi f E = E
    | mapi f (T (h, l, k, v, r)) = T (h, mapi f l, k, f (k, v), mapi f r)
  fun map f m = mapi (fn (_, v) => f v) m

  fun filteri cmp p m =
    foldli (fn (k, v, acc) => if p (k, v) then insert cmp (acc, k, v) else acc) E m

  (* Inserts the bindings of m2 into m1: O(|m2| log |m1|). *)
  fun unionWith cmp f (m1, m2) =
    foldli (fn (k, v2, acc) =>
              case find cmp (acc, k) of
                NONE => insert cmp (acc, k, v2)
              | SOME v1 => insert cmp (acc, k, f (v1, v2))) m1 m2

  fun fromList cmp l = List.foldl (fn ((k, v), m) => insert cmp (m, k, v)) E l
end

(* Every wrapper that needs the comparison is a `fun`: a partial application
   such as `val insert = OrdMap.insert String.compare` would be expansive and
   therefore monomorphic under the value restriction. *)
structure StringMap =
struct
  type key = string
  type 'a map = (string, 'a) OrdMap.map
  exception NotFound = OrdMap.NotFound

  val empty = OrdMap.empty
  val isEmpty = OrdMap.isEmpty
  val singleton = OrdMap.singleton
  fun insert (m, k, v) = OrdMap.insert String.compare (m, k, v)
  fun find (m, k) = OrdMap.find String.compare (m, k)
  fun lookup (m, k) = OrdMap.lookup String.compare (m, k)
  fun member (m, k) = OrdMap.member String.compare (m, k)
  fun remove (m, k) = OrdMap.remove String.compare (m, k)
  val numItems = OrdMap.numItems
  val listItems = OrdMap.listItems
  val listItemsi = OrdMap.listItemsi
  val listKeys = OrdMap.listKeys
  val foldl = OrdMap.foldl
  val foldli = OrdMap.foldli
  val foldri = OrdMap.foldri
  val app = OrdMap.app
  val appi = OrdMap.appi
  val map = OrdMap.map
  val mapi = OrdMap.mapi
  fun filteri p m = OrdMap.filteri String.compare p m
  fun unionWith f (m1, m2) = OrdMap.unionWith String.compare f (m1, m2)
  fun fromList l = OrdMap.fromList String.compare l
end

structure IntMap =
struct
  type key = int
  type 'a map = (int, 'a) OrdMap.map
  exception NotFound = OrdMap.NotFound

  val empty = OrdMap.empty
  val isEmpty = OrdMap.isEmpty
  val singleton = OrdMap.singleton
  fun insert (m, k, v) = OrdMap.insert Int.compare (m, k, v)
  fun find (m, k) = OrdMap.find Int.compare (m, k)
  fun lookup (m, k) = OrdMap.lookup Int.compare (m, k)
  fun member (m, k) = OrdMap.member Int.compare (m, k)
  fun remove (m, k) = OrdMap.remove Int.compare (m, k)
  val numItems = OrdMap.numItems
  val listItems = OrdMap.listItems
  val listItemsi = OrdMap.listItemsi
  val listKeys = OrdMap.listKeys
  val foldl = OrdMap.foldl
  val foldli = OrdMap.foldli
  val foldri = OrdMap.foldri
  val app = OrdMap.app
  val appi = OrdMap.appi
  val map = OrdMap.map
  val mapi = OrdMap.mapi
  fun filteri p m = OrdMap.filteri Int.compare p m
  fun unionWith f (m1, m2) = OrdMap.unionWith Int.compare f (m1, m2)
  fun fromList l = OrdMap.fromList Int.compare l
end
