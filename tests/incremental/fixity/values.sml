(* parses only in the fixity ops.sml leaves, x <+> _ a pattern of an infix
   constructor and <~> a nonfix value; a parse that fails names its tokens,
   Vector among them, which takes the Basis Library's vector.sml *)
structure Values =
struct
  datatype tag = Vector | Plain
  fun first (x <+> _) = x
  val times = <~>
  fun weigh Vector = 2 | weigh Plain = 1
  val total = first (5 <+> 1) <-> 2
end
