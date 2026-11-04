(* a functor of ARGS (sigs.sml): its static layer holds the constructors
   of the parameter's Operand.t *)
functor Allocate (S : ARGS) =
struct
  fun registers (S.amd64.Operand.Register _) = 1
    | registers _ = 0
end
