structure IntInfWorkload = struct
  structure I = IntInf
  val a = valOf (I.fromString "1")
  val b = valOf (I.fromString "1")
  val answer = ref (I.fromInt 0)
  fun fact (0, acc) = acc
    | fact (n, acc) = fact (n-1, I.* (acc,I.fromInt n))
  fun loop 0 = ()
    | loop i = let val x = I.+ (a,I.fromInt (i mod 17))
               in answer := fact (300, I.fromInt 1); loop (i-1) end
  val started = Time.now ()
  val () = loop 300
  val elapsed = Time.- (Time.now (), started)
  val () = print ("TIMING " ^ Time.fmt 6 elapsed ^ "\n")
  val () = print (I.toString (!answer) ^ "\n")
end
