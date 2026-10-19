structure RevcompCheck =
struct
  fun run path reference=
    let val expected=BinIO.openIn reference val count=ref 0
        fun emit byte=case BinIO.input1 expected of
            SOME value=>if byte=value then count:= !count+1 else raise Fail "incorrect result: reverse complement byte differs"
          | NONE=>raise Fail "incorrect result: extra reverse complement byte"
        val _=BenchReverseComplementTwo.run path emit handle ex=>(BinIO.closeIn expected;raise ex)
        val extra=BinIO.input1 expected val _=BinIO.closeIn expected
    in if Option.isSome extra then raise Fail "incorrect result: short reverse complement output"else !count end
end
