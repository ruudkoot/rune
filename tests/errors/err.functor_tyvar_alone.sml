(* Rule 89, as err.functor_tyvar_two_types, for the functor's declaration
   alone: its signature has r : 'a list ref with 'a free. The Definition
   lets an implementation refuse it or give 'a an arbitrary monotype
   (Appendix G); Rune refuses it, at the declaration, as HaMLet and MLKit
   do (SML/NJ, Poly/ML and MLton accept it with a warning) *)
functor F () = struct val r = ref [] end
