structure SecretaryCheck =
struct
  fun validate n results path =
    let val input = TextIO.openIn path
        fun rows [] k = (case TextIO.inputLine input of NONE => ()
          | SOME _ => raise Fail "incorrect result: extra secretary reference")
          | rows ((count, probability) :: rest) k =
              (case TextIO.inputLine input of NONE => raise Fail "incorrect result: short secretary reference"
               | SOME line => case String.tokens Char.isSpace line of
                   [key, successes, reference] =>
                     (case (Int.fromString key, Int.fromString successes, Real.fromString reference) of
                        (SOME expectedK, SOME expectedCount, SOME p) =>
                          if k = expectedK andalso count = expectedCount andalso count >= 0 andalso count <= n
                             andalso BenchInput.closeReal (probability, p, 1.0E~15, 0.0)
                          then rows rest (k + 1) else raise Fail "incorrect result: secretary count or probability differs"
                      | _ => raise Fail "incorrect result: malformed secretary reference")
                 | _ => raise Fail "incorrect result: malformed secretary row")
        val _ = rows results 35 handle ex => (TextIO.closeIn input; raise ex)
    in TextIO.closeIn input end
end
