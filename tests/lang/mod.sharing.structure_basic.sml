signature KEY = sig type key type extra val k : key end
signature PAIR =
sig
  structure L : KEY
  structure R : KEY
  sharing L = R
  val eq : L.key * R.key -> bool
end
structure P : PAIR =
struct
  structure L = struct type key = int type extra = bool val k = 1 end
  structure R = L
  fun eq (a : int, b) = a = b
end
val () = print (Bool.toString (P.eq (P.L.k, P.R.k)) ^ "\n")
