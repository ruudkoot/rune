fun r x = Real.toString (Real.fromInt (Real.round (x * 10000.0)) / 10000.0)
val () = print (r Math.pi ^ " " ^ r Math.e ^ " " ^ r (Math.sqrt 16.0) ^ " " ^ r (Math.sin 0.0) ^ " " ^ r (Math.cos 0.0) ^ "\n")
val () = print (r (Math.exp 1.0) ^ " " ^ r (Math.ln Math.e) ^ " " ^ r (Math.pow (2.0, 10.0)) ^ " " ^ r (Math.atan 1.0 * 4.0) ^ " " ^ r (Math.atan2 (1.0, 1.0)) ^ " " ^ r (Math.log10 1000.0) ^ " " ^ r (Math.tan 0.0) ^ "\n")
