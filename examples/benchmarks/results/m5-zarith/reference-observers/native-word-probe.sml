structure ZarithNativeWordProbe =
struct
 val n=case TextIO.inputLine TextIO.stdIn of SOME text=>(case Int.fromString text of SOME v=>v | NONE=>raise Fail "integer") | NONE=>raise Fail "input"
 val converted=Word64.fromInt n
 val subtracted=Word64.-(0w0,0w1)
 val sign=0wx8000000000000000:Word64.word
 fun line label value=TextIO.output(TextIO.stdOut,label^"="^Word64.toString value^"\n")
 val _=line "fromInt" converted
 val _=line "subtract" subtracted
 val _=line "fromInt-xor" (Word64.xorb(converted,sign))
 val _=line "subtract-xor" (Word64.xorb(subtracted,sign))
 val _=T.check("Word64.constant-minus-one-agrees-with-runtime",fn()=>converted=subtracted)
 val _=T.check("Word64.unsigned-signed-bias",fn()=>Word64.>(sign,Word64.xorb(subtracted,sign)))
 val _=T.check("Word64.runtime-signed-bias",fn()=>Word64.>(sign,Word64.xorb(converted,sign)))
 val _=T.check("Word64.constant-signed-bias",fn()=>Word64.>(Word64.xorb(Word64.fromInt 0,sign),Word64.xorb(Word64.fromInt ~1,sign)))
end
