structure BenchSpellCheck =
struct
  fun space c=let val n=Char.ord c in(n>=9 andalso n<=13)orelse n=32 orelse n=133 orelse n=160 end
  fun file path=let val stream=TextIO.openIn path val text=TextIO.inputAll stream val _=TextIO.closeIn stream in text end
  fun words text =
    let val length=String.size text
        fun skip i=if i<length andalso space(String.sub(text,i))then skip(i+1)else i
        fun finish i=if i<length andalso not(space(String.sub(text,i)))then finish(i+1)else i
        fun rest pos=BenchLazy.delay(fn()=>let val start=skip pos in if start=length then BenchStream.Nil else
          let val stop=finish start in BenchStream.Cons(BenchLazy.delay(fn()=>String.substring(text,start,stop-start)),rest stop)end end)
    in rest 0 end
  fun run calculate [dictionary,input,reference]=
    let val _=if List.exists(fn trio=>trio=(dictionary,input,reference))
          [("DATA/smoke.words","DATA/smoke.input","expected/smoke.txt"),
           ("DATA/normal.words","DATA/normal.input","expected/normal.txt"),
           ("DATA/large.words","DATA/large.input","expected/large.txt")]
          then()else raise Fail "spellcheck input paths"
        val dict=String.tokens space(file dictionary)
        val tree=BenchWordSet.fromList dict
        val unique=BenchWordSet.validate tree
        val _=if List.all(fn word=>BenchWordSet.member word tree)dict then()else raise Fail "dictionary membership differs"
        val(missing,count)=calculate tree(file input)
        val rendered=String.concatWith"\n"missing^(if null missing then""else"\n")
        val _=if rendered=file reference then()else raise Fail "misspelled words differ"
    in Int.toString unique^" "^Int.toString count^" "^Int.toString(List.length missing)end
    |run _ _=raise Fail "spellcheck expects dictionary input and reference"
end
