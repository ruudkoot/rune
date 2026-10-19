structure Benchmark =
struct
  val name = "kahan"
  val dimension = 100
  val epsilon = 2.220446049250313E~16
  fun prng w =
    let val a = Word64.xorb (w, Word64.<< (w, 0w13))
        val b = Word64.xorb (a, Word64.>> (a, 0w7))
    in Word64.xorb (b, Word64.<< (b, 0w17)) end
  fun calculate count =
    let val sums = Array.array (dimension, 0.0)
        val corrections = Array.array (dimension, 0.0)
        fun inner (w, j) =
          let val cj = Array.sub (corrections, j)
              val sj = Array.sub (sums, j)
              val y = Real.fromLargeInt (Word64.toLargeInt w) - cj
              val t = sj + y
              val _ = Array.update (corrections, j, (t - sj) - y)
              val _ = Array.update (sums, j, t)
          in if j+1 < dimension then inner (prng w, j+1) else () end
        fun outer i = if i > count then ()
          else (inner (Word64.fromInt i, 0); outer (i+1))
        val _ = outer 1
    in (sums, corrections) end
  fun validate count reference (sums, corrections) =
    let val stream = TextIO.openIn reference
        val fields = String.tokens Char.isSpace (TextIO.inputAll stream)
        val _ = TextIO.closeIn stream
        val expected = List.map (fn s => case IntInf.fromString s of SOME n => n
          | NONE => raise Fail "invalid exact Kahan sum") fields
        val _ = if List.length expected = dimension then () else raise Fail "Kahan reference dimension"
        fun one (_, []) = ()
          | one (j, exact::rest) =
            let val target = Real.fromLargeInt exact
                val actual = Array.sub (sums,j)
                val correction = Array.sub (corrections,j)
                val bound = if j=0 then 0.0 else
                  Real.fromInt count * 1024.0 + 4.0 * epsilon * Real.abs target
                val cBound = if j=0 then 0.0 else
                  2.0 * epsilon * (Real.abs actual + 18446744073709551616.0)
                val _ = if Real.isFinite actual andalso Real.isFinite correction
                  andalso Real.abs (actual-target) <= bound andalso Real.abs correction <= cBound
                  then () else raise Fail ("Kahan state differs at coordinate " ^ Int.toString j)
            in one (j+1,rest) end
    in one (0,expected) end
  fun run [size, reference] =
    let val n = BenchInput.between (1,7500000) (BenchInput.integer size)
        val _ = if List.exists (fn p => p=reference)
          ["expected/smoke.txt","expected/normal.txt","expected/large.txt"] then () else raise Fail "Kahan reference path"
        val result = calculate n
        val _ = validate n reference result
    in Int.toString n ^ " " ^ Int.toString (Array.length (#1 result)) end
    | run _ = raise Fail "kahan expects vector-count exact-reference"
end
