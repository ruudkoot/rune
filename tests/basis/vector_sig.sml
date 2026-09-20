(* requires: Vector *)
(* uses: spec-sigs/VECTOR.sml *)
(* Vector matches VECTOR, its type is the top-level one and admits equality. *)
structure TestVectorSig =
struct
  structure C : SPEC_VECTOR = Vector
  val () = T.check ("Vector:VECTOR/matches", fn () => true)
  val () = T.check ("Vector:VECTOR/vector-is-toplevel", fn () => C.length (Vector.fromList [1, 2] : int vector) = 2)
  val () = T.check ("Vector:VECTOR/toplevel-is-vector",
                    fn () => Vector.length (C.fromList [1] : int C.vector) = 1)
  val () = T.check ("Vector:VECTOR/eqtype", fn () => C.fromList [1, 2] = C.tabulate (2, fn i => i + 1))
end
