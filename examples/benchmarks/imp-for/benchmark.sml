(* MLton source at b15e2d289c3d701131733665a74e2dd8438410b6; notice in LICENSE.
   Input sizes are parameterized; the algorithm is retained. *)
structure Benchmark =
struct
  val name = "imp-for"
  fun for (start, stop, f) =
    let val i = ref start
        fun loop () = if !i >= stop then () else (f (!i); i := !i + 1; loop ())
    in loop () end
  fun run [size, reps] =
        let val width = BenchInput.between (1, 10) (BenchInput.integer size)
            val count = BenchInput.between (1, 1000) (BenchInput.integer reps)
            fun one () =
              let val x = ref 0
                  val _ = for (0, width, fn _ => for (0, width, fn _ =>
                    for (0, width, fn _ => for (0, width, fn _ =>
                    for (0, width, fn _ => for (0, width, fn _ =>
                    for (0, width, fn _ => x := !x + 1)))))))
              in !x end
        in IntInf.toString (BenchInput.repeat count one) end
    | run _ = raise Fail "imp-for expects width repetitions"
end
