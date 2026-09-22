(* requires: Array2 RealArray2 Vector *)
(* uses: spec-sigs/ARRAY2.sml *)
(* Array2 matches ARRAY2: its array type admits equality, a region is the
   record type of the page, traversal is a datatype, and row and column give
   top-level vectors. The page also says "the type ty array admits equality
   even if ty does not", which no sealed structure can do
   (ARRAY2/sealed-and-equal-at-any-element): the section below checks the
   reading taken here, that an array of a type which admits equality has one
   and the elements are not compared. *)
structure TestArray2Sig =
struct
  structure C : SPEC_ARRAY2 = Array2
  val () = T.check ("Array2:ARRAY2/matches", fn () => true)
  val () = T.check ("Array2:ARRAY2/eqtype",
                    fn () => let val a = C.array (1, 1, 1) in a = a andalso a <> C.array (1, 1, 1) end)
  (* equality is identity, and it does not look at the elements: two arrays
     of equal elements are different arrays *)
  val () = T.check ("Array2:ARRAY2/eqtype-is-identity",
                    fn () => let val a = C.array (2, 2, 0)
                                 val b = C.array (2, 2, 0)
                             in a = a andalso a <> b andalso (C.update (a, 0, 0, 1); a = a) end)
  (* the monomorphic arrays do admit equality whatever they hold: MONO_ARRAY2
     asks for an eqtype array and it is monomorphic *)
  val () = T.check ("RealArray2:MONO_ARRAY2/eqtype",
                    fn () => let val a = RealArray2.array (1, 1, 1.0)
                             in a = a andalso a <> RealArray2.array (1, 1, 1.0) end)
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
