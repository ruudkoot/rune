(* main.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure PiKernel =
  struct

    val name = "f-arith"

    val results = []

    fun computePi steps = let
          fun loop (0, acc, _) = acc
            | loop (steps, acc, n) = let
                val acc' = acc + (1.0 / n) - (1.0 / (n + 2.0))
                in
                  loop (steps - 1, acc', n + 4.0)
                end
          in
            4.0 * loop (steps, 0.0, 1.0)
          end

end
structure Benchmark =
struct
  val name="f-arith"
  fun run [steps]=
    let val n=BenchInput.integer steps
        val _=if n>0 then () else raise Fail "positive step count required"
        val result=PiKernel.computePi n
        val count=Real.fromInt n
        val bound=4.0/(4.0*count+1.0)+8.0*count*0.00000000000000011102230246251565
    in if BenchInput.closeReal(result,Math.pi,bound,0.0) then "1" else raise Fail "pi series error" end
  | run _=raise Fail "f-arith expects paired-series steps"
end
