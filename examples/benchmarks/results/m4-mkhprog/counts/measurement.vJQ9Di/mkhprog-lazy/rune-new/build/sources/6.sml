(* Crown Copyright 1992. Benchmark adapter for N. D. North's generator. *)
functor BenchMkhprogDriverFn(K:sig
  type text
  datatype target=Hashed|File of string|Usage
  val normalized:string->string
  val run:string->(target*text->unit)->unit
  val hash:text->Word64.word
end) =
struct
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun reference text=
    Vector.fromList(List.map(fn value=>case IntInf.fromString value of
        SOME n=>if n>=0 andalso n<=18446744073709551615 then W.fromLargeInt n
          else raise Fail "mkhprog reference outside Word64"
      |NONE=>raise Fail "invalid mkhprog hash reference")(String.tokens Char.isSpace text))
  fun checked input wanted=
    let val index=ref 0 val sum=ref 0w0
        fun emit(K.Hashed,text)=
              let val observed=K.hash text
                  val _=if !index<Vector.length wanted andalso observed=Vector.sub(wanted,!index)then()
                    else raise Fail "incorrect result: mkhprog output block"
              in index:= !index+1;sum:=W.+(!sum,observed)end
          |emit(K.File _,_)=raise Fail "mkhprog timing profiles require hashed stdout"
          |emit(K.Usage,_)=raise Fail "incorrect result: mkhprog rejected the input specification"
        val _=K.run input emit
        val _=if !index=Vector.length wanted then()else raise Fail "incorrect result: missing mkhprog blocks"
    in(!index,!sum)end
  fun run[repeatText,inputPath,referencePath]=
    let val repetitions=BenchInput.between(0,18000)(BenchInput.integer repeatText)
        val input=K.normalized(read inputPath)
        val wanted=reference(read referencePath)
        fun loop 0 blocks sum=Int.toString repetitions^":"^Int.toString blocks^":"^W.toString sum
          |loop n blocks sum=let val(count,value)=checked input wanted
            in loop(n-1)(blocks+count)(W.+(sum,value))end
    in loop repetitions 0 0w0 end
    |run _=raise Fail "mkhprog expects repetitions, input specification and block hashes"
end
