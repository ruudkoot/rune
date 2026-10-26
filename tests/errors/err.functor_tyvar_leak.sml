(* Rule 89 at F's declaration (err.functor_tyvar_two_types), and rule 54
   besides: F's signature types isPointEq with the v's parameter and the
   P.t's one variable (err.functor_signature_types), so `string S.v` with
   an equality on bool is a type error. A copy of the body elaborated with
   t = int, which typed this application before such a functor was refused,
   typed isPointEq more generally *)
functor F (P : sig type 'a t val equals : ('a * 'a -> bool) -> 'a t * 'a t -> bool end) =
struct
  datatype 'a v = Bottom | Point of 'a P.t
  fun isPointEq eq (v, p') = case v of Point p => P.equals eq (p, p') | Bottom => false
  val r = ref []
end
structure S = F (struct type 'a t = int fun equals _ (a : int, b) = a = b end)
val () = S.r := [()]
val b = S.isPointEq (op = : bool * bool -> bool) (S.Bottom : string S.v, 3)
val _ = print (if b then "true\n" else "false\n")
