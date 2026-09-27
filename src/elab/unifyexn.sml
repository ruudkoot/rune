(* The exception of Unify (unify.sml), which binds it again there. It is
   declared in a compilation unit of its own for MLKit 4.7.23: MLKit stops
   with "Impossible: Mul: diffef failed" on a recursive function that passes
   itself to List.app and raises an exception with an argument declared in
   the same unit, as occursAdjust does
   (docs/bugreport/mlkit/Mul/diffef-failed/BUGREPORT.md). It costs nothing:
   compiling a program executes the same instructions either way. *)
structure UnifyExn =
struct
  exception Unify of string
end
