structure Bug =
struct
  val value = 4503599627370497.0
  val wanted : IntInf.int = 4503599627370497
  val nearest = Real.toLargeInt IEEEReal.TO_NEAREST value
  val truncated = Real.toLargeInt IEEEReal.TO_ZERO value
  val _ = print ("nearest=" ^ IntInf.toString nearest ^
    " truncated=" ^ IntInf.toString truncated ^
    " expected=" ^ IntInf.toString wanted ^ "\n")
  val _ = if nearest = wanted then print "PASS\n" else print "FAIL\n"
end
