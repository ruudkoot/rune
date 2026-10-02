(* MLton source at b15e2d289c3d701131733665a74e2dd8438410b6; notice in LICENSE.
   Input sizes are parameterized; the algorithm is retained. *)
structure Benchmark =
struct
  val name = "merge"
  (* Written by Stephen Weeks (sweeks@sweeks.com). *)
  fun merge (l1: int list, l2) =
     case (l1, l2) of
        ([], _) => l2
      | (_, []) => l1
      | (x1 :: l1', x2 :: l2') =>
           if x1 <= x2
              then x1 :: merge (l1', l2)
           else x2 :: merge (l1, l2')

  fun run [size, reps] =
        let val n = BenchInput.between (1, 1000000) (BenchInput.integer size)
            val count = BenchInput.between (1, 10000) (BenchInput.integer reps)
            val left = List.tabulate (n, fn i => 2 * i)
            val right = List.tabulate (n, fn i => 2 * i + 1)
            fun validate xs =
              let fun loop ([], i, sum) = if i = 2 * n then sum else raise Fail "merge length"
                    | loop (x :: rest, i, sum) =
                        if x = i then loop (rest, i + 1, IntInf.+ (sum, IntInf.fromInt x))
                        else raise Fail "merge contents"
              in loop (xs, 0, IntInf.fromInt 0) end
            fun loop (0, sum) = sum
              | loop (k, sum) = loop (k - 1, IntInf.+ (sum, validate (merge (left, right))))
        in IntInf.toString (loop (count, IntInf.fromInt 0)) end
    | run _ = raise Fail "merge expects size repetitions"
end
