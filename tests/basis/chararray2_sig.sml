(* requires: CharArray2 CharVector *)
(* uses: spec-sigs/MONO_ARRAY2.sml *)
(* CharArray2 matches MONO_ARRAY2, `where type vector = CharVector.vector
   where type elem = char`; its array type admits equality, its traversal is
   that of Array2, and it can be implemented opaquely. *)
structure TestCharArray2Sig =
struct
  structure C : SPEC_MONO_ARRAY2 = CharArray2
  structure E : SPEC_MONO_ARRAY2 where type vector = CharVector.vector where type elem = char = CharArray2
  val () = T.check ("CharArray2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("CharArray2:MONO_ARRAY2/elem-is-char", fn () => (E.sub (E.array (1, 1, #"b"), 0, 0) : char) = #"b")
  val () = T.check ("CharArray2:MONO_ARRAY2/vector-is-CharVector.vector", fn () => CharVector.length (E.row (E.array (2, 3, #"x"), 1)) = 3)
  val () = T.check ("CharArray2:MONO_ARRAY2/vector-is-string", fn () => (E.column (E.array (2, 3, #"x"), 1) : string) = "xx")
  val () = T.check ("CharArray2:MONO_ARRAY2/array-is-CharArray2.array",
                    fn () => CharArray2.nRows (C.array (2, 3, #"x") : CharArray2.array) = 2
                             andalso C.nCols (CharArray2.array (2, 3, #"x") : C.array) = 3)
  val () = T.check ("CharArray2:MONO_ARRAY2/region-is-CharArray2.region",
                    fn () => let val a = CharArray2.array (2, 3, #"x")
                             in C.foldi C.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : CharArray2.region) = 3 end)
  val () = T.check ("CharArray2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (C.RowMajor : Array2.traversal) = Array2.RowMajor andalso CharArray2.ColMajor = (Array2.ColMajor : C.traversal))
  val () = T.check ("CharArray2:MONO_ARRAY2/eqtype", fn () => let val a = C.array (1, 1, #"x") in a = a end)
  structure O :> SPEC_MONO_ARRAY2 where type vector = string where type elem = char = CharArray2
  val () = T.check ("CharArray2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = O.tabulate O.ColMajor (2, 2, fn (i, j) => Char.chr (97 + 2 * i + j)) in O.row (a, 1) = "cd" andalso a = a end)
end
