structure MandelDoubleCheck =
struct
  fun run old strict width height limit path =
    let val input = TextIO.openIn path
        fun emit row = case TextIO.inputLine input of
            SOME expected => if row = expected then () else raise Fail "incorrect result: Mandel RGB row differs"
          | NONE => raise Fail "incorrect result: extra Mandel RGB row"
        val _ = BenchMandelDouble.render old strict (~2.0, ~2.0, 2.0, 2.0)
          (IntInf.fromInt width) (IntInf.fromInt height) limit emit
          handle ex => (TextIO.closeIn input; raise ex)
        val extra = TextIO.inputLine input val _ = TextIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short Mandel RGB output" else () end
end
