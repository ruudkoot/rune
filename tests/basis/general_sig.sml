(* requires: General *)
(* uses: spec-sigs/GENERAL.sml *)
(* General matches GENERAL, its types and exceptions are the top-level ones,
   and "All of the types and values defined in General are available
   unqualified at the top-level". *)
structure TestGeneralSig =
struct
  structure C : SPEC_GENERAL = General
  val () = T.check ("General:GENERAL/matches", fn () => true)
  val () = T.check ("General:GENERAL/unit-is-toplevel", fn () => (() : C.unit) = (() : unit))
  val () = T.check ("General:GENERAL/exn-is-toplevel", fn () => C.exnName (Div : exn) = exnName (C.Div : C.exn))
  val () = T.check ("General:GENERAL/order-is-toplevel", fn () => Int.compare (1, 2) = C.LESS)
  val () = T.check ("General:GENERAL/toplevel-is-order",
                    fn () => (case (LESS : order) of C.LESS => true | C.EQUAL => false | C.GREATER => false))
  val () = T.check ("General:GENERAL/exceptions-are-toplevel",
                    fn () => List.all (fn (e, isTop) => isTop e)
                               [(C.Bind, T.isBind), (C.Match, T.isMatch), (C.Chr, T.isChr), (C.Div, T.isDiv),
                                (C.Domain, T.isDomain), (C.Fail "x", T.isFail), (C.Overflow, T.isOverflow),
                                (C.Size, T.isSize), (C.Span, T.isSpan), (C.Subscript, T.isSubscript)])

  (* the top-level environment, collected in a structure, matches too *)
  structure Top : SPEC_GENERAL =
  struct
    type unit = unit
    type exn = exn
    exception Bind = Bind
    exception Match = Match
    exception Chr = Chr
    exception Div = Div
    exception Domain = Domain
    exception Fail = Fail
    exception Overflow = Overflow
    exception Size = Size
    exception Span = Span
    exception Subscript = Subscript
    val exnName = exnName
    val exnMessage = exnMessage
    datatype order = datatype order
    val ! = !
    val op := = op :=
    val op o = op o
    val op before = op before
    val ignore = ignore
  end
  val () = T.check ("General:GENERAL/toplevel-matches", fn () => Top.! (ref true))
end
