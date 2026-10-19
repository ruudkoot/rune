functor BenchPBMCheckFn(K : sig val render : int -> (Word8.word -> unit) -> unit end) =
struct
  fun run width path=
    let val input=BinIO.openIn path val count=ref 0
        fun emit byte=case BinIO.input1 input of SOME expected=>
            if byte=expected then count:= !count+1 else raise Fail "incorrect result: PBM byte differs"
          | NONE=>raise Fail "incorrect result: extra PBM byte"
        val _=K.render width emit handle ex=>(BinIO.closeIn input;raise ex)
        val extra=BinIO.input1 input val _=BinIO.closeIn input
    in case extra of NONE=> !count|SOME _=>raise Fail "incorrect result: missing PBM bytes"end
end
