(* Adapted from ML Kit test/kittmergesort.sml; GPL-2.0-or-later, see LICENSE
   and UPSTREAM-LICENSE. The upstream attributes tmergesort to Paulson's
   book, page 99. It deliberately rebuilds both merge arguments, permitting
   locally allocated regions; keep the copies in the empty-list cases. *)
structure Benchmark =
struct
  val name = "kittmergesort"
  exception Take and Drop

  fun take (0, _) = []
    | take (n, x :: xs) = x :: take (n - 1, xs)
    | take (_, []) = raise Take

  fun drop (0, xs) = xs
    | drop (n, _ :: xs) = drop (n - 1, xs)
    | drop (_, []) = raise Drop

  fun nextrand seed =
    let val t = 167 * seed in t - (2147 * (t div 2147)) end

  fun randlist (0, seed, tail) = (seed, tail)
    | randlist (n, seed, tail) = randlist (n - 1, nextrand seed, seed :: tail)

  fun length [] = 0
    | length (_ :: xs) = 1 + length xs

  fun merge ([], ys) = (ys : int list) @ []
    | merge (xs, []) = xs @ []
    | merge (left as x :: xs, right as y :: ys) =
        if x <= y then x :: merge (xs, right) else y :: merge (left, ys)

  fun tmergesort [] = []
    | tmergesort [x] = [x]
    | tmergesort xs =
        let val k = length xs div 2
        in merge (tmergesort (take (k, xs)), tmergesort (drop (k, xs))) end

  fun summarize xs =
    let
      fun loop ([], _, n, sum, hash) =
            Int.toString n ^ " " ^ IntInf.toString sum ^ " " ^ Word32.toString hash
        | loop (x :: rest, previous, n, sum, hash) =
            if x < previous then raise Fail "sort order"
            else loop (rest, x, n + 1, IntInf.+ (sum, IntInf.fromInt x),
                       Word32.+ (Word32.* (hash, 0w16777619), Word32.fromInt x))
    in loop (xs, 0, 0, IntInf.fromInt 0, 0w0) end

  fun run [size] =
        let
          val n = BenchInput.between (1, 1000000) (BenchInput.integer size)
          val (_, xs) = randlist (n, 1, [])
        in summarize (tmergesort xs) end
    | run _ = raise Fail "kittmergesort expects size"
end
