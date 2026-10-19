functor BenchIntegerDriverFn (K : sig
  val run : IntInf.int * IntInf.int * IntInf.int -> (int * Word64.word) list
end) =
struct
  fun integer text =
    case IntInf.fromString text of
      SOME n => if IntInf.toString n = text then n else raise Fail "invalid integer argument"
    | NONE => raise Fail "invalid integer argument"
  fun run [first, stride, last, path] =
    let val start = integer first val step = integer stride val limit = integer last
        val _ = if IntInf.<= (~2100000000, start) andalso IntInf.<= (start, limit)
                   andalso IntInf.<= (limit, 2100000000) andalso IntInf.> (step, 0)
                then () else raise Fail "integer grid out of range"
        val size = IntInf.+ (IntInf.div (IntInf.- (limit, start), step), 1)
        val _ = if IntInf.<= (size, 2100) then () else raise Fail "integer grid too large"
        val results = K.run (start, step, limit)
        val _ = IntegerCheck.validate results path
    in Int.toString (IntInf.toInt size) ^ ":checked" end
    | run _ = raise Fail "integer expects start step limit and reference"
end
