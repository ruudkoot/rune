structure IntInfWorkload = struct
  structure I = IntInf
  val a = valOf (I.fromString "7601841011229232442320862612515570149030765678641131829653728000300505169677510875393722471553157469159428976369104016357523834757712176925406225317796303")
  val b = valOf (I.fromString "8055834033299873827330799691506740053105523175726239454064608365954094228038357081541908689960872756931519898286518925097635484168341667048549482405631106")
  val answer = ref (I.fromInt 0)
  fun fact (0, acc) = acc
    | fact (n, acc) = fact (n-1, I.* (acc,I.fromInt n))
  fun loop 0 = ()
    | loop i = let val x = I.+ (a,I.fromInt (i mod 17))
               in answer := I.* (x,b); loop (i-1) end
  val started = Time.now ()
  val () = loop 7500
  val elapsed = Time.- (Time.now (), started)
  val () = print ("TIMING " ^ Time.fmt 6 elapsed ^ "\n")
  val () = print (I.toString (!answer) ^ "\n")
end
