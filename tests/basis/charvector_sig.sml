(* requires: CharVector String *)
(* uses: spec-sigs/MONO_VECTOR.sml *)
(* CharVector matches MONO_VECTOR, `where type vector = String.string where
   type elem = char`. *)
structure TestCharVectorSig =
struct
  structure C : SPEC_MONO_VECTOR = CharVector
  structure E : SPEC_MONO_VECTOR where type vector = String.string where type elem = char = CharVector
  val () = T.check ("CharVector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("CharVector:MONO_VECTOR/vector-is-String.string", fn () => String.size (E.fromList [#"a", #"b"]) = 2)
  val () = T.check ("CharVector:MONO_VECTOR/vector-is-toplevel-string", fn () => E.length ("abc" : string) = 3)
  val () = T.check ("CharVector:MONO_VECTOR/elem-is-char", fn () => (E.sub ("abc", 1) : char) = #"b")
  val () = T.check ("CharVector:MONO_VECTOR/elem-is-Char.char", fn () => Char.ord (E.sub ("abc", 1) : Char.char) = 98)
  val () = T.check ("CharVector:MONO_VECTOR/vector-is-CharVector.vector",
                    fn () => CharVector.length (C.fromList [] : CharVector.vector) = 0)
  (* the signature can be implemented opaquely, given elem *)
  structure O :> SPEC_MONO_VECTOR where type elem = char = CharVector
  val () = T.check ("CharVector:MONO_VECTOR/opaque-vector", fn () => O.sub (O.tabulate (3, fn i => Char.chr (65 + i)), 2) = #"C")
end
