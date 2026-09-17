(* Array: mutable arrays with identity equality. *)
structure Array =
struct
  type 'a array = 'a array
  type 'a vector = 'a vector
  val maxLen = 100000000

  val array = _prim "array_new" : int * 'a -> 'a array
  val fromList = _prim "array_from_list" : 'a list -> 'a array
  val length = _prim "array_length" : 'a array -> int
  val sub = _prim "array_sub" : 'a array * int -> 'a
  val update = _prim "array_update" : 'a array * int * 'a -> unit

  fun tabulate (n, f) = fromList (List.tabulate (n, f))

  fun appi f a =
    let val n = length a
        fun go i = if i < n then (f (i, sub (a, i)); go (i + 1)) else ()
    in go 0 end

  fun app f a = appi (fn (_, x) => f x) a

  fun modifyi f a =
    let val n = length a
        fun go i = if i < n then (update (a, i, f (i, sub (a, i))); go (i + 1)) else ()
    in go 0 end

  fun modify f a = modifyi (fn (_, x) => f x) a

  fun foldli f init a =
    let val n = length a
        fun go (i, acc) = if i < n then go (i + 1, f (i, sub (a, i), acc)) else acc
    in go (0, init) end

  fun foldri f init a =
    let fun go (i, acc) = if i >= 0 then go (i - 1, f (i, sub (a, i), acc)) else acc
    in go (length a - 1, init) end

  fun foldl f init a = foldli (fn (_, x, acc) => f (x, acc)) init a
  fun foldr f init a = foldri (fn (_, x, acc) => f (x, acc)) init a

  fun toList a = foldr (op ::) [] a
  fun vector a = (_prim "vector_from_list" : 'a list -> 'a vector) (toList a)

  fun findi p a =
    let val n = length a
        fun go i = if i < n then (if p (i, sub (a, i)) then SOME (i, sub (a, i)) else go (i + 1)) else NONE
    in go 0 end

  fun find p a = Option.map #2 (findi (fn (_, x) => p x) a)
  fun exists p a = isSome (find p a)
  fun all p a = not (exists (not o p) a)

  fun copy {src, dst, di} = appi (fn (i, x) => update (dst, di + i, x)) src

  fun collate cmp (a, b) = List.collate cmp (toList a, toList b)
end
