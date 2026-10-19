functor ParseTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchVeritasFn(D)
 structure L=BenchLazy
 val root="tests/out/benchmarks/nofib-veritas-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun hex value=String.concat(List.map(fn c=>let val value=Int.fmt StringCvt.HEX(Char.ord c)
     in String.map Char.toLower(if size value=1 then"0"^value else value)end)(K.F.toList value))
 fun unhex value=let fun digit c=if c>= #"0"andalso c<= #"9"then Char.ord c-48 else Char.ord c-87
       fun loop i=if i=size value then[]else Char.chr(16*digit(String.sub(value,i))+digit(String.sub(value,i+1)))::loop(i+2)
   in K.text(String.implode(loop 0))end
 fun check name actual=let val expected=read(root^name^".reference")
    in if actual=expected then print("PASS "^label^" "^name^"\n")
      else(print("ACTUAL "^actual^"\nEXPECTED "^expected^"\n");raise Fail name)end
 fun tokens values=let fun loop values=case L.force values of K.C.Nil=>[]|K.C.Cons(value,rest)=>
        let val kind=case D.force(L.force value)of K.Reserved s=>"r:"^hex s|K.Clear s=>"c:"^hex s
           |K.BinderToken b=>"b:"^hex(K.unparseBinder b)|K.InfixBinderToken s=>"d:"^hex s
           |K.InfixOperatorToken s=>"o:"^hex s|K.ScanError s=>"e:"^hex s
        in kind::loop rest end
    in String.concatWith"\n"(loop values)end
 fun one row=case String.fields(fn c=>c= #"\t")row of[name,input]=>
    let val input=unhex input
        val _=check("tokens-"^name)(tokens(K.tokenize input))
        val flag=K.parseIterm(K.defaultTags,K.emptySignature)input
    in check("parse-"^name)(hex(K.unparseFlagged(K.internalSignature K.emptySignature)flag))end
   |_=>raise Fail"input table"
 val _=List.app one(List.filter(fn s=>s<>"")(String.fields(fn c=>c= #"\n")(read(root^"parser-inputs.tsv"))))
end
structure Need=ParseTests(structure D=BenchNeed val label="lazy")
structure Strict=ParseTests(structure D=BenchStrict val label="strict")
