(* Portable argument checks for the benchmark drivers. *)
structure BenchInput =
struct
  fun integer text =
    case Int.fromString text of
      SOME n => if Int.toString n = text then n else raise Fail "invalid integer argument"
    | NONE => raise Fail "invalid integer argument"

  fun between (lo, hi) n =
    if n >= lo andalso n <= hi then n else raise Fail "argument out of range"

  fun closeReal (observed, expected, absolute, relative) =
    let val bound = absolute + relative * Real.abs expected
    in Real.isFinite observed andalso Real.isFinite expected andalso
       Real.isFinite absolute andalso Real.isFinite relative andalso
       absolute >= 0.0 andalso relative >= 0.0 andalso Real.isFinite bound andalso
       Real.abs (observed - expected) <= bound
    end

  fun repeat n f =
    let
      fun loop (0, sum) = sum
        | loop (left, sum) = loop (left - 1, IntInf.+ (sum, IntInf.fromInt (f ())))
    in
      loop (n, IntInf.fromInt 0)
    end
end
