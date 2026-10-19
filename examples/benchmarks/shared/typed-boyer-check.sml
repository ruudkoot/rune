functor TypedBoyerFormCheckFn (K:sig
 type term
 val input:int->term
 val normal:int->term
 val write:term->(string->unit)->unit
end)=
struct
 fun check term path=
  let val input=BinIO.openIn path
      fun emit text=
       let fun loop i=if i=String.size text then()else(case BinIO.input1 input of
             SOME value=>if Word8.toInt value=Char.ord(String.sub(text,i))then loop(i+1)
               else raise Fail "incorrect result: typed Boyer form differs"
           |NONE=>raise Fail "incorrect result: extra typed Boyer form")
       in loop 0 end
      val _=(K.write term emit;emit "\n")handle ex=>(BinIO.closeIn input;raise ex)
      val extra=BinIO.input1 input val _=BinIO.closeIn input
  in if Option.isSome extra then raise Fail "incorrect result: short typed Boyer form"else()end
 fun original id path=check(K.input id)path
 fun normal id path=check(K.normal id)path
end
