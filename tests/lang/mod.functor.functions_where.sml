(* --functors=functions: a datatype of a functor's parameter with a
   constructor of the parameter's abstract type, whose argument came through
   `where type`: what the argument gives is an abbreviation of the type name,
   which an application's descriptors must see through (an internal error
   from functors-units on, which the nightly's SDL contract found) *)
signature T =
sig
  type q
  val mk : int -> q
  val un : q -> int
  datatype n = Quit of int | Message of q
end
structure C =
struct
  type q = int
  fun mk x = x
  fun un x = x
  datatype n = Quit of int | Message of q
end
structure S : T where type n = C.n = C
functor K (X : T) =
struct
  fun f (X.Message q) = X.un q + 100
    | f (X.Quit n) = n
  fun g b = if b then X.Message (X.mk 7) else X.Quit 8
end
structure R = K (S)
val () = print (Int.toString (R.f (R.g true)) ^ " " ^ Int.toString (R.f (R.g false)) ^ "\n")
val () = print (Int.toString (R.f (C.Quit 3)) ^ "\n")
