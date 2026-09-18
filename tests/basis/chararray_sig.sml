(* requires: CharArray CharVector String *)
(* uses: spec-sigs/MONO_ARRAY.sml *)
(* CharArray matches MONO_ARRAY, `where type vector = CharVector.vector where
   type elem = char`, and its array type admits equality. *)
structure TestCharArraySig =
struct
  structure C : SPEC_MONO_ARRAY = CharArray
  structure E : SPEC_MONO_ARRAY where type vector = CharVector.vector where type elem = char = CharArray
  val () = T.check ("CharArray:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("CharArray:MONO_ARRAY/elem-is-char", fn () => (E.sub (E.array (1, #"b"), 0) : char) = #"b")
  val () = T.check ("CharArray:MONO_ARRAY/vector-is-CharVector.vector",
                    fn () => CharVector.length (E.vector (E.array (3, #"x"))) = 3)
  val () = T.check ("CharArray:MONO_ARRAY/vector-is-string", fn () => (E.vector (E.array (3, #"x")) : string) = "xxx")
  val () = T.check ("CharArray:MONO_ARRAY/array-is-CharArray.array",
                    fn () => CharArray.length (C.fromList [] : CharArray.array) = 0
                             andalso C.length (CharArray.fromList [] : C.array) = 0)
  val () = T.check ("CharArray:MONO_ARRAY/eqtype", fn () => let val a = C.fromList [] in a = a end)
  (* the signature can be implemented opaquely, given elem and vector *)
  structure O :> SPEC_MONO_ARRAY where type vector = string where type elem = char = CharArray
  val () = T.check ("CharArray:MONO_ARRAY/opaque-array",
                    fn () => let val a = O.tabulate (3, fn i => Char.chr (65 + i)) in O.vector a = "ABC" andalso a = a end)
end
