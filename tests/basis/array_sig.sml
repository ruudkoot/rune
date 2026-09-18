(* requires: Array Vector *)
(* uses: spec-sigs/ARRAY.sml *)
(* Array matches ARRAY, its types are the top-level ones, and its array type
   admits equality whatever the type of the elements. The signature is matched
   in a section, so that an implementation that lacks a member is reported as
   @section/array_sig/ARRAY and the other checks still run. *)
structure TestArraySig =
struct
  (*<< ARRAY *)
  structure C : SPEC_ARRAY = Array
  val () = T.check ("Array:ARRAY/matches", fn () => true)
  val () = T.check ("Array:ARRAY/array-is-toplevel", fn () => C.length (Array.fromList [1, 2] : int array) = 2)
  val () = T.check ("Array:ARRAY/toplevel-is-array", fn () => Array.length (C.fromList [1] : int C.array) = 1)
  val () = T.check ("Array:ARRAY/vector-is-Vector.vector",
                    fn () => (C.vector (C.fromList [1, 2]) : int C.vector) = (Vector.fromList [1, 2] : int Vector.vector))
  val () = T.check ("Array:ARRAY/eqtype", fn () => let val a = C.array (1, 1.0) in a = a andalso a <> C.array (1, 1.0) end)
  (*>> ARRAY *)
  val () = T.check ("Array:ARRAY/eqtype-toplevel",
                    fn () => let val a : real array = Array.array (1, 1.0) in a = a andalso a <> Array.array (1, 1.0) end)
  val () = T.check ("Array:ARRAY/vector-is-toplevel",
                    fn () => (Array.vector (Array.fromList [1, 2]) : int vector) = Vector.fromList [1, 2])
end
