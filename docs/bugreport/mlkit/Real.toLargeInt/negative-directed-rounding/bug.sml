fun show (what, expected, i) =
    print (what ^ " = " ^ IntInf.toString i ^ "   (expected " ^ expected ^ ")\n")
val () = show ("Real.toLargeInt TO_NEGINF ~2.5 ", "~3", Real.toLargeInt IEEEReal.TO_NEGINF ~2.5)
val () = show ("Real.toLargeInt TO_POSINF ~2.5 ", "~2", Real.toLargeInt IEEEReal.TO_POSINF ~2.5)
val () = show ("Real.toLargeInt TO_NEGINF ~0.5 ", "~1", Real.toLargeInt IEEEReal.TO_NEGINF ~0.5)
val () = show ("Real.toLargeInt TO_POSINF ~1E10 - 0.5", "~10000000000",
               Real.toLargeInt IEEEReal.TO_POSINF (~1E10 - 0.5))
val () = print ("for comparison, Real.floor ~2.5 = " ^ Int.toString (Real.floor ~2.5)
                ^ ", Real.ceil ~2.5 = " ^ Int.toString (Real.ceil ~2.5)
                ^ ", Real.toInt TO_NEGINF ~2.5 = " ^ Int.toString (Real.toInt IEEEReal.TO_NEGINF ~2.5) ^ "\n")
