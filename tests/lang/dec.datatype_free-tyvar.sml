(* Datatypes declared in a function, naming its type variable 'a, directly
   (t) or through another (u): 'a is a parameter of each, after their own.
   f is put where it is called, and a function of lifted is lifted, each at
   bool: their types say bool for 'a there, where the lint once wanted the
   'a of the scheme (MLton's regression datatype-with-free-tyvars). *)
fun 'a f (x1 : 'a, x2 : 'a, aToString : 'a -> string) : unit =
  let
    datatype 'b t = T of 'a * 'b
    and u = U of int t
    val y1 : int t = T (x1, 13)
    val _ : u = U y1
    val y2 = T (x2, "foo")
    fun 'b g (T (a, b), bToString : 'b -> string) : unit =
      print (concat [aToString a, " ", bToString b, "\n"])
    val _ = g (y1, Int.toString)
    val _ = g (y2, fn s => s)
  in
    ()
  end

val _ = f (true, false, Bool.toString)

fun 'a lifted (xs : 'a list, s : 'a -> string) =
  let
    datatype 'b t = T of 'a * 'b
    fun g (T (a, b), n) = if n = 0 then s a ^ b else g (T (a, b ^ "!"), n - 1)
  in
    List.app (fn x => print (g (T (x, ""), 2) ^ "\n")) xs
  end

val _ = lifted ([true, false], Bool.toString)
