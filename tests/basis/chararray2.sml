(* requires: CharArray2 CharVector Char String List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY2.sml fn/mono_array2_fn.sml *)
(* CharArray2 (optional in the specification: MONO_ARRAY2 "where type vector =
   CharVector.vector where type elem = char"): the checks that hold for every
   MONO_ARRAY2 structure, from fn/mono_array2_fn.sml, on 16 sample characters
   that include #"\000" and #"\255", and those of the vector type, which is
   string ("The type String.string is identical to CharVector.vector"). *)
structure TestCharArray2 =
struct
  val chars = Vector.fromList [#"\000", #"a", #"b", #"Z", #"\n", #" ", #"\127", #"\255",
                               #"0", #"9", #"z", #"A", #"~", #"\t", #"\128", #"\001"]
  structure Generic = TestMonoArray2Fn (structure A = CharArray2 structure V = CharVector val name = "CharArray2" val elems = chars val show = T.char val same = op =)
  structure Laws = TestMonoArray2LawsFn (structure A = CharArray2 structure V = CharVector val name = "CharArray2" val elems = chars val show = T.char val same = op = val empty = false)

  val eqS = T.eq T.string
  fun ofStrings l = CharArray2.fromList (List.map String.explode l)

  (* ---- rows and columns are strings ---- *)
  val () = eqS ("CharArray2.row/is-a-string", "def", fn () => CharArray2.row (ofStrings ["abc", "def"], 1))
  val () = eqS ("CharArray2.column/is-a-string", "be", fn () => CharArray2.column (ofStrings ["abc", "def"], 1))
  val () = eqS ("CharArray2.column/is-CharVector.vector", "ad",
                fn () => (CharArray2.column (ofStrings ["abc", "def"], 0) : CharVector.vector))
  val () = eqS ("CharArray2.modify/toUpper", "ABC",
                fn () => let val a = ofStrings ["abc", "def"] in CharArray2.modify CharArray2.RowMajor Char.toUpper a; CharArray2.row (a, 0) end)
  val () = eqS ("CharArray2.fold/implode-ColMajor", "adbecf",
                fn () => String.implode (List.rev (CharArray2.fold CharArray2.ColMajor op :: [] (ofStrings ["abc", "def"]))))
  val () = eqS ("CharArray2.tabulate/high-characters", "\253\254\255",
                fn () => CharArray2.row (CharArray2.tabulate CharArray2.RowMajor (2, 3, fn (i, j) => Char.chr (250 + 3 * i + j)), 1))

  (*<< no-elements *)
  structure Empty = TestMonoArray2EmptyFn (structure A = CharArray2 val name = "CharArray2" val elems = chars val show = T.char val same = op =)
  structure LawsEmpty = TestMonoArray2LawsFn (structure A = CharArray2 structure V = CharVector val name = "CharArray2" val elems = chars val show = T.char val same = op = val empty = true)
  (*>> no-elements *)

  (*<< overflow *)
  structure Overflow = TestMonoArray2OverflowFn (structure A = CharArray2 val name = "CharArray2" val elem = #"a")
  (*>> overflow *)

  (*<< too-large *)
  structure Size = TestMonoArray2SizeFn (structure A = CharArray2 val name = "CharArray2" val elem = #"a")
  (*>> too-large *)
end
