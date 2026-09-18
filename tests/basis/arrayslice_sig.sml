(* requires: ArraySlice VectorSlice Array Vector *)
(* uses: spec-sigs/ARRAY_SLICE.sml *)
(* ArraySlice matches ARRAY_SLICE, its slices are slices of the top-level array
   type, and copyVec takes the slices of VectorSlice. *)
structure TestArraySliceSig =
struct
  structure C : SPEC_ARRAY_SLICE = ArraySlice
  val () = T.check ("ArraySlice:ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("ArraySlice:ARRAY_SLICE/slice-is-ArraySlice.slice",
                    fn () => ArraySlice.length (C.full (Array.fromList [1, 2]) : int ArraySlice.slice) = 2)
  val () = T.check ("ArraySlice:ARRAY_SLICE/of-toplevel-array",
                    fn () => C.length (C.full (Array.fromList [1, 2] : int array)) = 2)
  val () = T.check ("ArraySlice:ARRAY_SLICE/base-is-toplevel",
                    fn () => let val a : real array = Array.array (2, 1.0) in (#1 (C.base (C.full a)) : real array) = a end)
  val () = T.check ("ArraySlice:ARRAY_SLICE/vector-is-toplevel",
                    fn () => (C.vector (C.full (Array.fromList [1, 2])) : int vector) = Vector.fromList [1, 2])
  val () = T.check ("ArraySlice:ARRAY_SLICE/copyVec-takes-VectorSlice.slice",
                    fn () => let val a = Array.array (2, 0)
                             in C.copyVec {src = VectorSlice.full (Vector.fromList [1, 2]), dst = a, di = 0};
                                Array.sub (a, 1) = 2
                             end)
end
