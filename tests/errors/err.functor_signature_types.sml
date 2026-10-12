(* rule 54: an application whose code is made is typed by the functor's
   signature as well. In it isPointEq takes a v and a P.t of the same 'a;
   the argument's t drops its parameter, so a copy of the body elaborated
   with it would type isPointEq more generally, with the v's parameter
   free -- as Rune did before it typed applications by the signature *)
functor F (P : sig type 'a t val equals : ('a * 'a -> bool) -> 'a t * 'a t -> bool end) =
struct
  datatype 'a v = Bottom | Point of 'a P.t
  fun isPointEq eq (v, p') = case v of Point p => P.equals eq (p, p') | Bottom => false
end
structure S = F (struct type 'a t = int fun equals _ (a : int, b) = a = b end)
val b = S.isPointEq (op = : bool * bool -> bool) (S.Bottom : string S.v, 3)
