(* One of the functors behind the monomorphic vectors, arrays and slices. Each
   is in a file of its own, and so is each application, because a program
   pays for what it loads: BinIO needs Word8Vector and nothing else. *)
(* An array of any element type is an array. *)
functor RuneMonoArrayFn (structure V : MONO_VECTOR) =
struct
  type elem = V.elem
  type vector = V.vector
  type array = elem Array.array
  val maxLen = Array.maxLen
  val array : int * elem -> array = Array.array
  val fromList : elem list -> array = Array.fromList
  val tabulate : int * (int -> elem) -> array = Array.tabulate
  val length : array -> int = Array.length
  val sub : array * int -> elem = Array.sub
  val update : array * int * elem -> unit = Array.update
  fun vector (a : array) = V.tabulate (length a, fn i => sub (a, i))
  val copy : {src : array, dst : array, di : int} -> unit = Array.copy
  fun copyVec {src : vector, dst : array, di} =
    if di < 0 orelse di > length dst - V.length src then raise Subscript
    else V.appi (fn (i, x) => update (dst, di + i, x)) src

  fun foldli f init (s : array) =
    let val n = length s
        fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (s, k), acc))
    in go (0, init) end
  fun foldri f init (s : array) =
    let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (s, k), acc))
    in go (length s - 1, init) end
  fun foldl f init s = foldli (fn (_, x, acc) => f (x, acc)) init s
  fun foldr f init s = foldri (fn (_, x, acc) => f (x, acc)) init s
  fun appi f s = foldli (fn (k, x, ()) => f (k, x)) () s
  fun app f s = foldli (fn (_, x, ()) => f x) () s
  fun findi p (s : array) =
    let
      val n = length s
      fun go k =
        if k >= n then NONE
        else let val x = sub (s, k) in if p (k, x) then SOME (k, x) else go (k + 1) end
    in go 0 end
  fun find p s = case findi (fn (_, x) => p x) s of SOME (_, x) => SOME x | NONE => NONE
  fun exists p s = case find p s of SOME _ => true | NONE => false
  fun all p s = not (exists (fn x => not (p x)) s)
  fun collate cmp (a : array, b : array) =
    let
      val n = length a and m = length b
      fun go k =
        if k >= n then (if k >= m then EQUAL else LESS)
        else if k >= m then GREATER
        else case cmp (sub (a, k), sub (b, k)) of EQUAL => go (k + 1) | other => other
    in go 0 end

  fun modifyi f (a : array) =
    let val n = length a
        fun go k = if k >= n then () else (update (a, k, f (k, sub (a, k))); go (k + 1))
    in go 0 end
  fun modify f a = modifyi (fn (_, x) => f x) a
end
