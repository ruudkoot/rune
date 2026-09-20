(* requires: VectorSlice Vector *)
(* uses: spec-sigs/VECTOR_SLICE.sml *)
(* VectorSlice matches VECTOR_SLICE, and its slices are slices of the top-level
   vector type. *)
structure TestVectorSliceSig =
struct
  structure C : SPEC_VECTOR_SLICE = VectorSlice
  val () = T.check ("VectorSlice:VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("VectorSlice:VECTOR_SLICE/slice-is-VectorSlice.slice",
                    fn () => VectorSlice.length (C.full (Vector.fromList [1, 2]) : int VectorSlice.slice) = 2)
  val () = T.check ("VectorSlice:VECTOR_SLICE/of-toplevel-vector",
                    fn () => C.length (C.full (Vector.fromList [1, 2] : int vector)) = 2)
  val () = T.check ("VectorSlice:VECTOR_SLICE/vector-is-toplevel",
                    fn () => (C.vector (C.full (Vector.fromList [1, 2])) : int vector) = Vector.fromList [1, 2])
  val () = T.check ("VectorSlice:VECTOR_SLICE/base-is-toplevel",
                    fn () => (#1 (C.base (C.full (Vector.fromList [1, 2]))) : int vector) = Vector.fromList [1, 2])
end
