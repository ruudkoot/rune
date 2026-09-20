(* requires: ListPair *)
(* uses: spec-sigs/LIST_PAIR.sml *)
(* ListPair matches LIST_PAIR, and its exception is the one its functions
   raise. *)
structure TestListPairSig =
struct
  structure C : SPEC_LIST_PAIR = ListPair
  val () = T.check ("ListPair:LIST_PAIR/matches", fn () => true)
  val () = T.check ("ListPair:LIST_PAIR/lists-are-toplevel",
                    fn () => C.zip ([1, 2] : int list, ["a"] : string list) = [(1, "a")])
  val () = T.raises ("ListPair:LIST_PAIR/exception-is-shared", fn C.UnequalLengths => true | _ => false,
                     fn () => ListPair.zipEq ([1], [] : int list))
end
