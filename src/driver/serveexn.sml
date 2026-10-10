(* The exception of Serve (serve.sml), which binds it again there. It is
   declared in a compilation unit of its own for MLKit 4.7.23: MLKit stops
   with "Impossible: Mul: diffef failed" on Serve's parser, whose recursive
   functions raise an exception with an argument declared in the same unit
   (docs/bugreport/mlkit/Mul/diffef-failed/BUGREPORT.md). *)
structure ServeExn =
struct
  exception Bad of string
end
