(* Written by Stephen Weeks (sweeks@acm.org). *)
(*
 * Random number generator based on page 302 of Numerical Recipes in C.
 *)
local
   fun natFold (start, stop, ac, f) =
      let
         fun loop (i, ac) =
            if i = stop
               then ac
            else loop (i + 1, f (i, ac))
      in loop (start, ac)
      end
   val niter: int = 4
   open Word32
   fun make (l: word list) =
      let val a = Array.fromList l
      in fn i => Array.sub (a, i)
      end
   val c1 = make [0wxbaa96887, 0wx1e17d32c, 0wx03bdcd3c, 0wx0f33d1b2]
   val c2 = make [0wx4b0f3b58, 0wxe874f0c3, 0wx6955c5a6, 0wx55a7ca46]
   val half: Word.word = 0w16
   fun reverse w = orb (>> (w, half), << (w, half))
   fun psdes (lword: word, irword: word): word * word =
      natFold
      (0, niter, (lword, irword), fn (i, (lword, irword)) =>
       let
          val ia = xorb (irword, c1 i)
          val itmpl = andb (ia, 0wxffff)
          val itmph = >> (ia, half)
          val ib = itmpl * itmpl + notb (itmph * itmph)
       in (irword,
           xorb (lword, itmpl * itmph + xorb (c2 i, reverse ib)))
       end)
   val zero: word = 0wx13
   val lword: word ref = ref 0w13
   val irword: word ref = ref 0w14
   val needTo = ref true
in
   fun reset () = (lword := 0w13; irword := 0w14; needTo := true)
   fun word () =
      if !needTo
         then
            let
               val (l, i) = psdes (!lword, !irword)
               val _ = lword := l
               val _ = irword := i
               val _ = needTo := false
            in
               l
            end
      else (needTo := true
            ; !irword)
end

structure Benchmark=struct val name="psdes-random-mlkit"
fun run [words]=let val n=BenchInput.between(1,10000000)(BenchInput.integer words) val _=reset()
fun loop(0,sum)=sum |loop(k,sum)=loop(k-1,Word32.+(sum,word()))
in Word32.toString(loop(n,0w0))end |run _=raise Fail "pseudo-DES expects generated words"end
