functor BenchBSPTDriverFn(P:sig val prog:string->char BenchStream.stream end) =
struct
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun expectedHash text=
    let fun loop i total power=if i<0 then total else
          loop(i-1)(W.+(total,W.*(W.fromInt(Char.ord(String.sub(text,i))),power)))(W.*(power,0w31))
    in loop(String.size text-1)(0w0:W.word)(0w1:W.word)end
  fun consume expected output=
    let fun loop i hash values=case BenchLazy.force values of BenchStream.Nil=>
          if i=String.size expected then(i,hash)else raise Fail "incorrect result: short BSPT output"
        |BenchStream.Cons(c,rest)=>
          let val c=BenchLazy.force c
          in if i<String.size expected andalso c=String.sub(expected,i)
             then loop(i+1)(W.+(W.*(hash,0w31),W.fromInt(Char.ord c)))rest
             else raise Fail "incorrect result: BSPT output differs"end
    in loop 0(0w0:W.word)output end
  fun run[repetitionsText,inputPath,referencePath]=
    let val repetitions=BenchInput.between(0,125000)(BenchInput.integer repetitionsText)
        val input=read inputPath val expected=read referencePath
        val wantedHash=expectedHash expected
        fun loop 0 checked hash=Int.toString repetitions^" "^IntInf.toString checked^" "^W.toString hash
          |loop left checked _=
            let val(count,hash)=consume expected(P.prog input)
            in if hash=wantedHash then loop(left-1)(IntInf.+(checked,IntInf.fromInt count))hash
               else raise Fail "incorrect result: BSPT hash"end
    in loop repetitions(IntInf.fromInt 0)(0w0:W.word)end
    |run _=raise Fail "bspt expects repetitions, command input and full output reference"
end
