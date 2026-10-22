(* An outer comment (* and an inner comment *) which ends here. *)
structure Nested =
struct
  infixr 5 :::
  datatype 'a stream = Nil | ::: of 'a * 'a stream
  fun head (x ::: _) = SOME x
    | head Nil = NONE
  fun choose xs =
    let
      val text = "line one\
                 \ and line two"
    in
      case head xs of NONE => size text | SOME n => n
    end
end
