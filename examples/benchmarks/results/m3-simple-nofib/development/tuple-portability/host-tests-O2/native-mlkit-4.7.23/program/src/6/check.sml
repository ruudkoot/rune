(* Numerical checks are independent of host decimal formatting. *)
structure BenchSimpleReference=
struct
 val absolute=0.000000000001
 val relative=0.00000000001
 fun close expected actual=Real.isFinite expected andalso Real.isFinite actual
   andalso Real.abs(expected-actual)<=absolute+relative*Real.abs expected
 fun decode text=
   if String.size text<>16 orelse not(List.all Char.isHexDigit(String.explode text))then raise Fail"invalid SIMPLE binary64 field"
   else PackReal64Big.fromBytes(Word8Vector.tabulate(8,fn i=>
      case Word8.fromString("0wx"^String.substring(text,2*i,2))of
        SOME w=>w|NONE=>raise Fail"invalid SIMPLE binary64 digits"))
 fun read file=
   let val stream=TextIO.openIn file
       val text=TextIO.inputAll stream before TextIO.closeIn stream
   in String.tokens Char.isSpace text end
 fun scalar expected actual=
   if close expected actual then()else raise Fail"incorrect result: SIMPLE binary64 value"
 fun totals expected values=
   case(expected,values)of([],[])=>()
    |(x::xs,y::ys)=>(scalar(decode x)(BenchLazy.force y);totals xs ys)
    |_=>raise Fail"incorrect SIMPLE totals count"
end
functor BenchSimpleCheckFn(val strict:bool val report:bool val gridMax:int)=
struct
 structure K=BenchSimpleNofibFn(val strict=strict val gridMax=gridMax)
 structure R=BenchSimpleReference
 fun integer s=case Int.fromString s of SOME n=>n|NONE=>raise Fail"invalid SIMPLE integer"
 fun parseHeader kind count tokens=
   case tokens of tag::grid::steps::n::rest=>
     if tag=kind andalso integer grid=gridMax andalso integer n=count
     then(integer steps,rest)else raise Fail"incorrect SIMPLE reference header"
   |_=>raise Fail"missing SIMPLE reference header"
 fun verifyState steps state tokens=
   let val(expectedStep,tokens)=parseHeader"SIMPLE-STATE"11 tokens
       val _=if steps=expectedStep then()else raise Fail"incorrect SIMPLE step reference"
       val pieces=ref([]:string list)
       fun emit text=pieces:=text:: !pieces
       fun real expected actual=
         let val _=R.scalar(R.decode expected)actual
             val raw=Real.fmt(StringCvt.GEN(SOME 17))actual
             val parsed=case Real.fromString raw of SOME v=>v|NONE=>raise Fail"invalid SIMPLE decimal output"
             val _=R.scalar actual parsed
         in String.map(fn #"~"=> #"-"| #"E"=> #"e"|c=>c)raw end
       fun index(i,j)="("^Int.toString i^","^Int.toString j^")"
       fun array(name,a)(tokens,count)=
         case tokens of label::loI::loJ::hiI::hiJ::n::rest=>
           let val b=((integer loI,integer loJ),(integer hiI,integer hiJ))
               val positions=K.A.positions b
               val _=if name=label andalso b=K.A.bounds a andalso List.length positions=integer n
                     then()else raise Fail"incorrect SIMPLE array shape"
               val _=emit((if name="theta"then"theta"else"\""^
                 (case name of"u"=>"U"|"v"=>"V"|"r"=>"R"|"z"=>"Z"|"alpha"=>"Alpha"|"rho"=>"Rho"|"s"=>"S"|"p"=>"P"|"q"=>"Q"|other=>other)^"\"")^"\n")
               val _=emit("array ("^index(#1 b)^","^index(#2 b)^") [")
               fun cells [] rest count=(emit"]\n";(rest,count))
                 |cells(z::zs)(i::j::value::rest)count=
                   if z=(integer i,integer j)then
                     (emit("("^index z^","^real value(K.A.sub a z)^")"^(if null zs then""else","));
                      cells zs rest(count+1))
                   else raise Fail"incorrect SIMPLE reference coordinate"
                 |cells _ _ _=raise Fail"truncated SIMPLE state"
           in cells positions rest count end
         |_=>raise Fail"truncated SIMPLE array header"
       val _=emit"\"RESULT \"\n"
       val(tokens,count)=List.foldl(fn(item,acc)=>array item acc)(tokens,0)(K.arrays state)
       val(_,_,_,_,_,_,_,_,_,dt,err)=state
       val _=case tokens of["deltat",d,"error",e]=>
          (emit(real d(BenchLazy.force dt)^"\n");emit(real e(BenchLazy.force err)^"\ndone\n"))
         |_=>raise Fail"incorrect SIMPLE scalar tail"
       val rendered=String.concat(List.rev(!pieces))
       val _=TextIO.output(TextIO.stdOut,rendered)
   in count end
 fun run[stepsText,path]=
   let val steps=BenchInput.between(0,100)(BenchInput.integer stepsText)
       val reference=R.read path
       val(totals,state)=K.compute steps
   in if report then
        Int.toString steps^":"^Int.toString(verifyState steps state reference)
      else let val(expectedStep,values)=parseHeader"SIMPLE-TOTALS"13 reference
               val _=if steps=expectedStep then()else raise Fail"incorrect SIMPLE step reference"
               val _=R.totals values totals
           in Int.toString steps^":13"end
   end
 |run _=raise Fail"expected SIMPLE steps and numerical reference"
end
