(* The vector and the array on the representation they share, the VM's array
   of reals, behind one opaque ascription: nothing outside sees that a
   vector is an array that is not written again. *)
structure RuneRealSeq :>
sig
  structure V : MONO_VECTOR where type elem = real
  structure A : MONO_ARRAY where type elem = real where type vector = V.vector
end =
struct
  val maxLen = 100000000
  fun tabulate (n, f : int -> real) : RuneReals.reals =
    if n < 0 orelse n > maxLen then raise Size
    else
      let val a = RuneReals.new (n, 0.0)
          fun go i = if i >= n then a else (RuneReals.update (a, i, f i); go (i + 1))
      in go 0 end
  fun fromList (l : real list) : RuneReals.reals =
    let val a = RuneReals.new (List.length l, 0.0)
        fun go (_, []) = a
          | go (i, x :: rest) = (RuneReals.update (a, i, x); go (i + 1, rest))
    in go (0, l) end
  fun copied (v : RuneReals.reals) : RuneReals.reals =
    let val n = RuneReals.length v
        val a = RuneReals.new (n, 0.0)
    in RuneReals.blit (v, 0, a, 0, n); a end
  (* what a vector and an array have in common *)
  structure Seq =
  struct
    type elem = real
    val maxLen = maxLen
    (* functions, not names for the primitives: a name with a type of its
       own is a closure to call, and its pair of arguments an object *)
    fun length (s : RuneReals.reals) : int = RuneReals.length s
    fun sub (s : RuneReals.reals, i : int) : real = RuneReals.sub (s, i)
    fun foldli f init s =
      let val n = length s
          fun go (k, acc) = if k >= n then acc else go (k + 1, f (k, sub (s, k), acc))
      in go (0, init) end
    fun foldri f init s =
      let fun go (k, acc) = if k < 0 then acc else go (k - 1, f (k, sub (s, k), acc))
      in go (length s - 1, init) end
    fun foldl f init s = foldli (fn (_, x, acc) => f (x, acc)) init s
    fun foldr f init s = foldri (fn (_, x, acc) => f (x, acc)) init s
    fun appi f s = foldli (fn (k, x, ()) => f (k, x)) () s
    fun app f s = foldli (fn (_, x, ()) => f x) () s
    fun findi p s =
      let
        val n = length s
        fun go k =
          if k >= n then NONE
          else let val x = sub (s, k) in if p (k, x) then SOME (k, x) else go (k + 1) end
      in go 0 end
    fun find p s = case findi (fn (_, x) => p x) s of SOME (_, x) => SOME x | NONE => NONE
    fun exists p s = case find p s of SOME _ => true | NONE => false
    fun all p s = not (exists (fn x => not (p x)) s)
    fun collate cmp (a, b) =
      let
        val n = length a and m = length b
        fun go k =
          if k >= n then (if k >= m then EQUAL else LESS)
          else if k >= m then GREATER
          else case cmp (sub (a, k), sub (b, k)) of EQUAL => go (k + 1) | other => other
      in go 0 end
  end
  structure V =
  struct
    open Seq
    type vector = RuneReals.reals
    val fromList = fromList
    val tabulate = tabulate
    fun update (v, i, x) =
      if i < 0 orelse i >= length v then raise Subscript
      else let val a = copied v in RuneReals.update (a, i, x); a end
    fun concat (l : vector list) : vector =
      let
        val n = List.foldl (fn (v, n) => n + length v) 0 l
        val () = if n > maxLen then raise Size else ()
        val a = RuneReals.new (n, 0.0)
        fun go (_, []) = a
          | go (at, v :: rest) = (RuneReals.blit (v, 0, a, at, length v); go (at + length v, rest))
      in go (0, l) end
    fun mapi f (v : vector) : vector = tabulate (length v, fn i => f (i, sub (v, i)))
    fun map f (v : vector) : vector = tabulate (length v, fn i => f (sub (v, i)))
  end
  structure A =
  struct
    open Seq
    type vector = RuneReals.reals
    type array = RuneReals.reals
    fun array (n, x : real) : array = RuneReals.new (n, x)
    val fromList = fromList
    val tabulate = tabulate
    fun update (a : array, i : int, x : real) : unit = RuneReals.update (a, i, x)
    fun vector (a : array) : vector = copied a
    fun copy {src : array, dst : array, di} = RuneReals.blit (src, 0, dst, di, length src)
    fun copyVec {src : vector, dst : array, di} = RuneReals.blit (src, 0, dst, di, length src)
    fun modifyi f (a : array) =
      let val n = length a
          fun go k = if k >= n then () else (update (a, k, f (k, sub (a, k))); go (k + 1))
      in go 0 end
    fun modify f a = modifyi (fn (_, x) => f x) a
  end
end
(* RealVector: immutable vectors of reals.

   The monomorphic vectors and arrays of real, their slices and the
   two-dimensional arrays (optional in the specification). The elements do not
   admit equality, which MONO_VECTOR and MONO_ARRAY do not ask of them, and so
   neither does a vector. LargeRealVector, Real64Vector and the rest of those
   families are these (mono_largereal.sml, mono_real64.sml).

   A vector is the reals themselves side by side, eight bytes each, and so
   is an array.

   Implements: MONO_VECTOR where type elem = real

   Status: optional *)
structure RealVector = RuneRealSeq.V
(* RealVectorSlice: stretches of `RealVector` vectors, without a copy.

   Implements: MONO_VECTOR_SLICE where type vector = RealVector.vector where
   type elem = real

   Status: optional *)
structure RealVectorSlice :> MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real = RuneMonoVectorSliceFn (structure V = RealVector)
(* RealArray: mutable arrays of reals, a type of their own with identity
   equality, whose vectors are those of `RealVector`.

   Implements: MONO_ARRAY where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray = RuneRealSeq.A
(* RealArraySlice: stretches of `RealArray` arrays, without a copy: an update
   through a slice changes the array.

   Implements: MONO_ARRAY_SLICE where type vector = RealVector.vector where
   type vector_slice = RealVectorSlice.slice where type array =
   RealArray.array where type elem = real

   Status: optional *)
structure RealArraySlice :> MONO_ARRAY_SLICE where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real = RuneMonoArraySliceFn (structure V = RealVector structure A = RealArray structure VS = RealVectorSlice)
(* RealArray2: two-dimensional arrays of reals, whose rows and columns are
   `RealVector` vectors.

   Implements: MONO_ARRAY2 where type vector = RealVector.vector where type
   elem = real

   Status: optional *)
structure RealArray2 :> MONO_ARRAY2 where type vector = RealVector.vector where type elem = real = RuneMonoArray2Fn (structure V = RealVector)
