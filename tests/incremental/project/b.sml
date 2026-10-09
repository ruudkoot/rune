(* uses a.sml *)
structure B : SHAPE =
struct
  type t = A.shape
  fun area s = A.area s + 1
end
