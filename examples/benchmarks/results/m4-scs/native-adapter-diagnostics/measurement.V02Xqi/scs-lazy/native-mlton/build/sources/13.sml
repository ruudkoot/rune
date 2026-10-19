structure BenchScsCheck =
struct
  structure Q=BenchScsRational
  structure P=BenchScsParse
  structure K=BenchScsSimulate
  structure M=K.M
  structure L=BenchLazy
  structure S=BenchStream
  val relative=1.0E~11
  fun absolute name=if String.isPrefix "i:" name then 1.0E~24 else 1.0E~15
  fun close name(observed,expected)=Real.isFinite observed andalso Real.isFinite expected andalso
    Real.abs(observed-expected)<=absolute name+relative*Real.abs expected
  fun read path=
    let val input=TextIO.openIn path val text=TextIO.inputAll input handle ex=>(TextIO.closeIn input;raise ex)
        val _=TextIO.closeIn input in text end
  fun integer text=case IntInf.fromString(String.translate(fn #"-"=>"~"|c=>String.str c)text)of
      SOME value=>value|NONE=>raise Fail "incorrect result: invalid reference integer"
  fun real text=case Real.fromString(String.translate(fn #"-"=>"~"|c=>String.str c)text)of
      SOME value=>value|NONE=>raise Fail "incorrect result: invalid reference number"
  fun join []=""|join[x]=x|join(x::xs)=x^","^join xs
  fun namesHeader names="["^join(List.map(fn name=>"\""^name^"\"")names)^"]"
  fun split text=String.tokens Char.isSpace(String.map(fn c=>if c= #"["orelse c= #"]"orelse c= #","then #" "else c)text)
  fun stripLF text=if String.size text>0 andalso String.sub(text,String.size text-1)= #"\n"
    then String.substring(text,0,String.size text-1)else text
  fun runStats strict[path,seedArg,dtArg,endArg,tempArg,rbcArg,reference]=
    let val(circuit,names)=P.readCircuit(read path)
        val seed=P.readInteger seedArg val dt=P.readExact dtArg val ending=P.readExact endArg
        val temperature=P.readApproximate tempArg val rbc=P.readApproximate rbcArg
        val _=if Q.compare(dt,Q.zero)<>GREATER then raise Fail "dt must be positive"
              else if Q.compare(ending,Q.zero)<>GREATER then raise Fail "end time must be positive"
              else if temperature<0.0 then raise Fail "temperature must be nonnegative"else()
        val labels=tl names
        val input=TextIO.openIn reference
        val formatted=ref 2
        fun consume text=
          let fun loop i=if i=String.size text then()else
                let val c=String.sub(text,i)
                in formatted:= !formatted+(if c= #"\""orelse c= #"\\"orelse c= #"\t"orelse c= #"\n"then 2 else 1);loop(i+1)end
          in loop 0 end
        val _=consume("t:Time\t"^namesHeader labels^"\n")
        val format=Real.fmt(StringCvt.GEN(SOME 17))
        fun checkHeader()=case TextIO.inputLine input of
             SOME text=>if stripLF text=namesHeader labels then()else raise Fail "incorrect result: reference labels differ"
           |NONE=>raise Fail "incorrect result: missing trace header"
        fun loop source count points=case L.force source of S.Nil=>(count,points)
          |S.Cons(row,rest)=>
            let val(time,output)=L.force row
                val wanted=case TextIO.inputLine input of NONE=>raise Fail "incorrect result: extra simulation row"
                  |SOME text=>split text
                val numbers=case wanted of n::d::values=>
                  if Q.equal(time,Q.make(integer n,integer d))then values else raise Fail "incorrect result: event time differs"
                  |_=>raise Fail "incorrect result: invalid simulation row"
                val values=L.force output
                val _=if M.size values=List.length labels andalso List.length numbers=List.length labels then()
                      else raise Fail "incorrect result: simulation dimension differs"
                val _=consume(format(Q.real time)^"\t[")
                fun check [] [] _=()
                  |check(name::names)(expected::expectedTail)i=
                    let val observed=M.sub values i val expected=real expected
                        val _=if close name(observed,expected)then()else raise Fail "incorrect result: simulation value differs"
                        val _=if i=1 then()else consume ","
                        val _=consume(format observed)
                    in check names expectedTail(i+1)end
                  |check _ _ _=raise Fail "incorrect result: inconsistent simulation row"
                val _=check labels numbers 1
                val _=consume "]\n"
            in loop rest(count+1)(points+List.length labels)end
        val result=(checkHeader();loop(K.simulateWith strict circuit seed dt ending temperature rbc)0 0)
          handle ex=>(TextIO.closeIn input;raise ex)
        val extra=TextIO.inputLine input val _=TextIO.closeIn input
        val _=if Option.isSome extra then raise Fail "incorrect result: short simulation trace"else()
        val(rows,points)=result
        val _=if !formatted>points then()else raise Fail "incorrect result: missing formatted output"
    in {rows=rows,points=points,formatted= !formatted}end
    |runStats _ _=raise Fail "SCS expects circuit, seed, dt, end time, temperature, background charge and reference"
  fun run strict args=let val{rows,points,...}=runStats strict args
    in Int.toString rows^":"^Int.toString points^":checked"end
end
