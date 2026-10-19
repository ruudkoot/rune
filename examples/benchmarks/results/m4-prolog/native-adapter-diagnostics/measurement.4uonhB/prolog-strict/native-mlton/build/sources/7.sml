functor BenchPrologDriverFn(K:sig
  type database
  val setup:string->database
  val runChars:bool->database->char list->char BenchStream.stream
end) =
struct
  structure S=BenchStream
  structure L=BenchLazy
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun reverseHash text=
    let fun loop i power sum=if i<0 then sum else
          loop(i-1)(W.*(power,0w31))
            (W.+(sum,W.*(power,W.fromInt(Char.ord(String.sub(text,i))))))
    in loop(String.size text-1)0w1 0w0 end
  fun consume text wanted=
    let val size=String.size wanted
        fun loop chars i hash=case L.force chars of
            S.Nil=>if i=size then hash else raise Fail "incorrect result: missing Prolog output"
          |S.Cons(c,rest)=>
            let val value=L.force c
                val _=if i<size andalso value=String.sub(wanted,i)then()
                  else raise Fail "incorrect result: Prolog transcript differs"
            in loop rest(i+1)(W.+(W.fromInt(Char.ord value),W.*(hash,0w31)))end
    in loop text 0 0w0 end
  fun run tree [repeatText,library,inputPath,referencePath]=
    let val repetitions=BenchInput.between(0,1000)(BenchInput.integer repeatText)
        val db=K.setup(read library)
        val input=String.explode(read inputPath)
        val wanted=read referencePath
        val hash=reverseHash wanted
        fun loop 0=Int.toString repetitions^":"^W.toString hash
          |loop n=if consume(K.runChars tree db input)wanted=hash then loop(n-1)
            else raise Fail "incorrect result: Prolog modular hash differs"
    in loop repetitions end
    |run _ _=raise Fail "Prolog expects repetitions, library, command file and transcript reference"
end
