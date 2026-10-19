structure IntegerCheck =
struct
  fun validate results path =
    let val input = TextIO.openIn path
        fun check [] = (case TextIO.inputLine input of NONE => ()
          | SOME _ => raise Fail "incorrect result: extra integer reference")
          | check ((count, hash) :: rest) =
              (case TextIO.inputLine input of
                 NONE => raise Fail "incorrect result: short integer reference"
               | SOME text =>
                   if text = Int.toString count ^ ":" ^ Word64.toString hash ^ "\n"
                   then check rest else raise Fail "incorrect result: integer count or digest differs")
        val _ = check results handle ex => (TextIO.closeIn input; raise ex)
    in TextIO.closeIn input end
end
