functor ParstofLexPilotFn(D:BENCH_SUSPEND)=
struct
 structure X=BenchParstofLexFn(D)
 fun quote text="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)text^"\""
 fun arr xs="["^String.concatWith","xs^"]"
 fun n x=String.map(fn #"~"=> #"-"|c=>c)(Int.toString x)
 fun value X.Empty=arr[quote"C_Tokv_E"]
   |value(X.Character x)=arr[quote"F_Tokv_ch",n(Char.ord(D.force x))]
   |value(X.Integer x)=arr[quote"F_Tokv_i",n(D.force x)]
   |value(X.Text x)=arr[quote"F_Tokv_str",quote(String.implode(D.force x))]
   |value(X.Error(c,message))=arr[quote"F_Tokv_err",n(Char.ord c),quote message]
 fun tokens stream=case BenchLazy.force stream of X.Done=>arr[quote"[]"]
   |X.Tok((tag,v,line),tail)=>arr[quote"(:)",arr[quote"(,,)",n tag,value v,n line],tokens tail]
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun check name=
   let val actual=tokens(X.tokenize(read(name^".input")))^"\n"
       val expected=read(name^"-tokens.reference")
   in if actual=expected then print("PASS "^name^"\n")else
      let val f=TextIO.openOut(name^"-actual.json")
      in TextIO.output(f,actual);TextIO.closeOut f;raise Fail name end end
 val _=List.app check["default","identity","application","types","conditional","let-case","lexemes","bad","empty","unterminated-comment"]
end
structure N=ParstofLexPilotFn(BenchNeed)
structure E=ParstofLexPilotFn(BenchStrict)
