(* requires: Array2 Vector *)
(* uses: spec-sigs/ARRAY2.sml *)
(* Array2 matches ARRAY2: its array type admits equality (in the section,
   whatever the type of the elements), a region is the record type of the page,
   traversal is a datatype, and row and column give top-level vectors. *)
structure TestArray2Sig =
struct
  structure C : SPEC_ARRAY2 = Array2
  val () = T.check ("Array2:ARRAY2/matches", fn () => true)
  val () = T.check ("Array2:ARRAY2/eqtype",
                    fn () => let val a = C.array (1, 1, 1) in a = a andalso a <> C.array (1, 1, 1) end)
  (*<< eq-any-element *)
  (* "Thus, the type ty array admits equality even if ty does not." *)
  val () = T.check ("Array2:ARRAY2/eqtype-of-reals",
                    fn () => let val a = Array2.array (1, 1, 1.0) in a = a andalso a <> Array2.array (1, 1, 1.0) end)
  val () = T.check ("Array2:ARRAY2/eqtype-of-functions",
                    fn () => let val a = Array2.array (1, 1, fn (x : int) => x) in a = a end)
  (*>> eq-any-element *)
  val () = T.check ("Array2:ARRAY2/region-is-a-record",
                    fn () => let val a = Array2.array (2, 3, 0)
                                 val r : int Array2.region = {base = a, row = 0, col = 1, nrows = NONE, ncols = SOME 1}
                             in #base r = a andalso #row r = 0 andalso #col r = 1
                                andalso #nrows r = NONE andalso #ncols r = SOME 1
                             end)
  val () = T.check ("Array2:ARRAY2/traversal-is-a-datatype",
                    fn () => List.map (fn C.RowMajor => 1 | C.ColMajor => 2) [Array2.RowMajor, Array2.ColMajor] = [1, 2])
  val () = T.check ("Array2:ARRAY2/traversal-admits-equality",
                    fn () => Array2.RowMajor = C.RowMajor andalso Array2.RowMajor <> Array2.ColMajor)
  val () = T.check ("Array2:ARRAY2/row-is-toplevel-vector",
                    fn () => (C.row (C.fromList [[1, 2]], 0) : int vector) = Vector.fromList [1, 2])
  val () = T.check ("Array2:ARRAY2/column-is-toplevel-vector",
                    fn () => (C.column (C.fromList [[1, 2]], 1) : int vector) = Vector.fromList [2])
end
