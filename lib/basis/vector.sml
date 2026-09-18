(* Vector: immutable arrays with structural equality. *)
structure Vector =
struct
  type 'a vector = 'a vector
  val maxLen = 100000000

  val fromList = vector
  val length = _prim "vector_length" : 'a vector -> int
  val sub = _prim "vector_sub" : 'a vector * int -> 'a

  fun tabulate (n, f) = fromList (List.tabulate (n, f))

  fun foldli f init v =
    let val n = length v
        fun go (i, acc) = if i < n then go (i + 1, f (i, sub (v, i), acc)) else acc
    in go (0, init) end

  fun foldri f init v =
    let fun go (i, acc) = if i >= 0 then go (i - 1, f (i, sub (v, i), acc)) else acc
    in go (length v - 1, init) end

  fun foldl f init v = foldli (fn (_, x, acc) => f (x, acc)) init v
  fun foldr f init v = foldri (fn (_, x, acc) => f (x, acc)) init v

  fun toList v = foldr (op ::) [] v
  fun appi f v = foldli (fn (i, x, ()) => f (i, x)) () v
  fun app f v = appi (fn (_, x) => f x) v
  fun mapi f v = fromList (List.rev (foldli (fn (i, x, acc) => f (i, x) :: acc) [] v))
  fun map f v = mapi (fn (_, x) => f x) v
  fun concat vs = fromList (List.concat (List.map toList vs))
  fun update (v, i, x) = mapi (fn (j, y) => if i = j then x else y) v

  fun findi p v =
    let val n = length v
        fun go i = if i < n then (if p (i, sub (v, i)) then SOME (i, sub (v, i)) else go (i + 1)) else NONE
    in go 0 end

  fun find p v = Option.map #2 (findi (fn (_, x) => p x) v)
  fun exists p v = isSome (find p v)
  fun all p v = not (exists (not o p) v)
  fun collate cmp (a, b) = List.collate cmp (toList a, toList b)
end
