(* Polymorphic values bound by patterns inside a function: a tuple's, a
   constructor's, and typed ones. Mid is System F
   (docs/ir.md, What a Mid keeps; the linting roadmap's M5): the value a
   pattern takes apart abstracts over the variables its binders do, each
   use gives them, and a use that needs no particular type (the int of
   the pair) gives unit. *)
datatype 'a box = Box of 'a
fun f (n : int) =
  let
    val (p, q) = (fn y => y, n)
    val Box id = Box (fn x => x)
    val e : 'a list = []
    val g : 'b -> 'b list = fn x => [x]
    val (r, s) : ('c -> 'c) * int = (fn y => y, n)
  in
    p q + (if p true then 1 else 0) + id 2 + size (id "ab") + length (e : int list) + length (e : string list)
    + length (g 1) + length (g "s") + r s + (if r false then 0 else 1)
  end
val () = print (Int.toString (f 3) ^ "\n")
