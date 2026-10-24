(* Appendix E and rule 54, as err.functor_overload_topdec, with the
   application and the use inside another functor's body: rule 86
   elaborates G's body once, in which F's signature types T.double :
   int -> int, and T.double 1.5 is a type error at G's declaration. Refused
   in every mode: inside a declaration's check an application is typed by
   the functor's signature alone, and no copy of F's body is elaborated *)
functor F () = struct fun double x = x + x end
functor G () = struct
  structure T = F ()
  val r = T.double 1.5
end
