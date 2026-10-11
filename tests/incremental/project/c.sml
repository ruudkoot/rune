(* a functor *)
functor Twice (S : SHAPE) =
struct
  fun area2 x = 2 * S.area x
end
