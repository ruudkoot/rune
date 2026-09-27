val nan = Real.posInf - Real.posInf
fun show (what, r) = print (what ^ " = " ^ Real.toString r ^ "   (expected nan)\n")
val () = show ("Math.ln nan   ", Math.ln nan)
val () = show ("Math.log10 nan", Math.log10 nan)
val () = print ("for comparison, Math.exp nan = " ^ Real.toString (Math.exp nan) ^ "\n")
