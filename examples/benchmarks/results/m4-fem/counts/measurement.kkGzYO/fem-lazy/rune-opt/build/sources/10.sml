functor BenchFemCheckFn(K:sig
 structure A:sig type 'a vec val vecsub:'a vec->int->'a val elements:'a vec->'a list end
 type database
 val nnode:database->int val nelem:database->int val nmats:database->int val nplds:database->int
 val nodeXY:database->int->real*real
 val nodeBC:database->int->int
 val material:database->int->real*real
 val elementNodes:database->int->int*int
 val elementMaterial:database->int->int
 val pointLoad:database->int->int*real*real*real
 val nodeDisplacement:real A.vec->int->real*real*real
 val database:string->database
 val displacement:database->real A.vec
 val forces:database->real A.vec->real A.vec

end)=
struct
 structure P=BenchFemReportFn(K)
 structure W=Word64
 fun read file=
   let val stream=TextIO.openIn file
   in(TextIO.inputAll stream before TextIO.closeIn stream)
     handle ex=>(TextIO.closeIn stream;raise ex)end
 fun integer text=case Int.fromString text of SOME n=>n|NONE=>raise Fail"invalid FEM reference integer"
 fun word32 text=case Word32.fromString("0wx"^text)of SOME n=>n|NONE=>raise Fail"invalid FEM reference bits"
 fun word64 text=case Word64.fromString("0wx"^text)of SOME n=>n|NONE=>raise Fail"invalid FEM reference hash"
 fun hash text=List.foldl(fn(c,value)=>W.+(W.fromInt(Char.ord c),W.*(value,0w31)))0w0(String.explode text)
 fun reference file=
   let val tokens=String.tokens Char.isSpace(read file)
       fun vector("u"::count::rest)=
             let val size=integer count
             in(List.map word32(List.take(rest,size)),List.drop(rest,size))end
         |vector _=raise Fail"invalid FEM displacement reference"
       fun forces("f"::count::rest)=
             let val size=integer count
             in(List.map word32(List.take(rest,size)),List.drop(rest,size))end
         |forces _=raise Fail"invalid FEM force reference"
   in case tokens of"FEM32"::nodes::elements::rest=>
        let val(u,rest)=vector rest val(f,rest)=forces rest
            val expectedHash=case rest of["hash",text]=>word64 text|_=>raise Fail"invalid FEM hash reference"
        in(integer nodes,integer elements,u,f,expectedHash)end
      |_=>raise Fail"invalid FEM reference header"end
 fun same expected actual=
   case(expected,actual)of([],[])=>true
    |(bits::rest,value::tail)=>Real.isFinite value andalso bits=BenchFemFloat.bits value andalso same rest tail
    |_=>false
 fun run[repetitionsText,inputPath,reportPath,referencePath]=
   let val repetitions=BenchInput.between(0,2000)(BenchInput.integer repetitionsText)
       val input=read inputPath val expectedReport=read reportPath
       val(nodes,elements,wantedU,wantedF,wantedHash)=reference referencePath
       fun loop 0 count bytes values=Int.toString count^":"^Int.toString bytes^":"^Int.toString values
         |loop n count bytes values=
           let val db=K.database input
               val u=K.displacement db
               val f=K.forces db u
               val report=P.render db u f
               val _=if K.nnode db=nodes andalso K.nelem db=elements andalso
                   same wantedU(K.A.elements u)andalso same wantedF(K.A.elements f)andalso
                   report=expectedReport andalso hash report=wantedHash then()
                 else raise Fail"incorrect result: FEM binary32 result, complete report or hash"
           in loop(n-1)(count+1)(bytes+String.size report)(values+List.length wantedU+List.length wantedF)end
   in loop repetitions 0 0 0 end
 |run _=raise Fail"expected repetitions, source input, complete report and binary32 references"
end
