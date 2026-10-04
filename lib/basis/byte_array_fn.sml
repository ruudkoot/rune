(* The functor behind the arrays of bytes, Word8Array and CharArray: an array
   is the VM's array of bytes (RuneBytes), a byte an element, and its vector
   is a string underneath, so `vector`, `copy` and `copyVec` are each one
   primitive that moves the bytes. An element goes through a character,
   which is what the VM reads and writes. *)
functor RuneByteArrayFn (structure V : MONO_VECTOR
                         val toChar : V.elem -> char
                         val fromChar : char -> V.elem
                         val vectorOf : string -> V.vector     (* the string as the vector: nothing is copied *)
                         val stringOf : V.vector -> string) =
struct
  type elem = V.elem
  type vector = V.vector
  type array = RuneBytes.bytes
  (* An array's largest length is Array.maxLen, as it was when an array of
     bytes was an array of words, and as MONO_ARRAY documents it; the VM
     would hold more (a string's largest size). *)
  val maxLen = 100000000
  fun length (a : array) : int = RuneBytes.length a
  fun sub (a : array, i) : elem = fromChar (RuneBytes.sub (a, i))
  fun update (a : array, i, x : elem) = RuneBytes.update (a, i, toChar x)
  fun array (n, x : elem) : array = if n > maxLen then raise Size else RuneBytes.new (n, Char.ord (toChar x))
  (* "If n < 0 or maxLen < n, then the Size exception is raised": before f is applied *)
  fun tabulate (n, f : int -> elem) : array =
    if n < 0 orelse n > maxLen then raise Size
    else
      let val a = RuneBytes.new (n, 0)
          fun go i = if i >= n then a else (update (a, i, f i); go (i + 1))
      in go 0 end
  fun fromList (l : elem list) : array =
    let val n = List.length l
        val a = if n > maxLen then raise Size else RuneBytes.new (n, 0)
        fun go (_, []) = a
          | go (i, x :: rest) = (update (a, i, x); go (i + 1, rest))
    in go (0, l) end
  fun vector (a : array) : vector = vectorOf (RuneBytes.extract (a, 0, length a))
  fun copy {src : array, dst : array, di} = RuneBytes.blit (src, 0, dst, di, length src)
  fun copyVec {src : vector, dst : array, di} =
    let val s = stringOf src in RuneBytes.blitString (s, 0, dst, di, size s) end

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
