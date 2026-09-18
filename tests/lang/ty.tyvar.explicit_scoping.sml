(* Section 4.6: explicit type variables are scoped at the outermost value
   declaration in which they occur unguarded, and are rigid there *)
fun 'a id (x : 'a) : 'a = x
fun pair (x : 'a, y : 'b) : 'a * 'b = (x, y)      (* 'a and 'b implicitly scoped at pair *)
val p = pair (1, "s")
val () = print (#2 p ^ Int.toString (#1 p) ^ Int.toString (id 3) ^ "\n")
(* 'a scoped at outer: the inner declaration sees the same variable *)
fun outer (x : 'a) =
  let
    fun inner (y : 'a) = [x, y]           (* 'a here is outer's 'a *)
  in inner x end
val () = print (Int.toString (length (outer 1) + length (outer "s")) ^ "\n")
(* 'b is scoped at twice, so the inner declaration shares it *)
fun twice (f : 'b -> 'b) = let fun g (x : 'b) : 'b = f (f x) in g end
val () = print (Int.toString (twice (fn n => n + 1) 0) ^ "\n")
(* datatypes and exceptions in the body may mention the scoped variable *)
fun 'a wrap (x : 'a) =
  let
    exception Boxed of 'a
    datatype box = Box of 'a
  in
    (Box x, (raise Boxed x) handle Boxed y => y)
  end
val () = print (case wrap 7 of (_, y) => Int.toString y ^ "\n")
(* ''a: an explicit equality type variable *)
fun ''a same (x : ''a, y : ''a) = x = y
val () = print (Bool.toString (same ("a", "a")) ^ "\n")
