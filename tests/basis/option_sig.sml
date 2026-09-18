(* requires: Option *)
(* uses: spec-sigs/OPTION.sml *)
(* Option matches OPTION, its type and exception are the top-level ones, and
   "The type, the Option exception, and the functions getOpt, valOf, and isSome
   are available in the top-level environment". *)
structure TestOptionSig =
struct
  structure C : SPEC_OPTION = Option
  val () = T.check ("Option:OPTION/matches", fn () => true)
  val () = T.check ("Option:OPTION/option-is-toplevel", fn () => C.getOpt (SOME 1 : int option, 0) = 1)
  val () = T.check ("Option:OPTION/toplevel-is-option", fn () => valOf (C.SOME 2 : int C.option) = 2)
  val () = T.check ("Option:OPTION/option-admits-equality", fn () => C.SOME 1 = SOME 1 andalso C.NONE <> SOME 1)
  val () = T.check ("Option:OPTION/exception-is-toplevel", fn () => T.isOption C.Option)
  val () = T.raises ("Option:OPTION/toplevel-is-exception", fn C.Option => true | _ => false,
                     fn () => valOf (NONE : int option))

  (* the top-level environment, collected in a structure, matches its part *)
  structure Top :
    sig
      datatype option = datatype option
      exception Option
      val getOpt : 'a option * 'a -> 'a
      val isSome : 'a option -> bool
      val valOf : 'a option -> 'a
    end =
  struct
    datatype option = datatype option
    exception Option = Option
    val getOpt = getOpt
    val isSome = isSome
    val valOf = valOf
  end
  val () = T.check ("Option:OPTION/toplevel-matches", fn () => Top.isSome (Top.SOME ()))
end
