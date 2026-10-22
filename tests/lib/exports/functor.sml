functor Make (X : sig val delta : int end) =
struct
  structure Fresh = Secret ()
  val value = Int.+ (Hidden.value,X.delta)
end
