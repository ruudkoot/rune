(* Option

   Implements: OPTION *)
structure Option =
struct
  datatype option = datatype option
  exception Option = Option
  val getOpt = getOpt
  val isSome = isSome
  val valOf = valOf
  fun filter p x = if p x then SOME x else NONE
  fun join (SOME x) = x
    | join NONE = NONE
  fun app f (SOME x) = f x
    | app f NONE = ()
  fun map f (SOME x) = SOME (f x)
    | map f NONE = NONE
  fun mapPartial f (SOME x) = f x
    | mapPartial f NONE = NONE
  fun compose (f, g) x = case g x of NONE => NONE | SOME y => SOME (f y)
  fun composePartial (f, g) x = case g x of NONE => NONE | SOME y => f y
end
