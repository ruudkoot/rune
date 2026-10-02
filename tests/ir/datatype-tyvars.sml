(* dump: --dump-after=mid *)
(* A datatype declared in a function that names the function's type
   variable: it is a parameter of the datatype after its own ('b of t), and
   of one that names the datatype (u), and the types of t and u in f give
   it as itself; so where simplify puts f, at bool, they say bool. *)
fun 'a f (x : 'a, y : int) =
  let
    datatype 'b t = T of 'a * 'b
    datatype u = U of int t
  in
    case U (T (x, y)) of U (T (a, b)) => (a, b)
  end
val r = f (true, 1)
