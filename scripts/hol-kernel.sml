(* HOL4's kernel at work (bin/rune-measure hol-kernel; docs/plans/performance.md,
   E7): the same file on Rune and on Poly/ML. Each workload prints a line
   `HOLBENCH NAME: SECONDS`, the processor time of the process while it ran,
   user and system. *)
fun cpu f =
  let val t = Timer.startCPUTimer ()
      val _ = f ()
      val {usr, sys} = Timer.checkCPUTimer t
  in Time.toReal usr + Time.toReal sys end
fun report name f =
  print ("HOLBENCH " ^ name ^ ": " ^ Real.fmt (StringCvt.FIX (SOME 3)) (cpu f) ^ "\n")
fun times n f = let fun go 0 = () | go k = (ignore (f ()); go (k - 1)) in go n end
val _ = report "EVAL-FACT-60" (fn () => EVAL ``FACT 60``)
val _ = report "EVAL-FACT-150" (fn () => EVAL ``FACT 150``)
val g1 = ``(!x:'a. P x ==> Q x) /\ (!x. Q x ==> R x) /\ P a ==> R a``
val g2 = ``(!x y. x < y ==> f x < f y) /\ a < b /\ b < c ==> f a < f c``
val _ = report "PROVE_TAC-x20" (fn () => times 10 (fn () => (prove (g1, PROVE_TAC []), prove (g2, PROVE_TAC [arithmeticTheory.LESS_TRANS]))))
val _ = report "SIMP_CONV-arith-x200" (fn () => times 200 (fn () => SIMP_CONV arith_ss [] ``x + 2 * y + 3 = y + x + y + 3``))
val _ = report "DECIDE-x200" (fn () => times 200 (fn () => DECIDE ``a < b /\ b < c ==> a + 1 < c + 1``))
val big = Arbnum.fromString "123456789012345678901234567890123456789"
val _ = report "Arbnum-mul-x200000" (fn () => times 200000 (fn () => Arbnum.* (big, big)))
val _ = report "type_of-term-x200000" (fn () => times 200000 (fn () => type_of (concl arithmeticTheory.LESS_TRANS)))
