functor BenchFulsomCheckFn(K:sig val picture:int->int BenchStream.stream end)=
struct
 structure L=BenchLazy
 structure S=BenchStream
 structure W=Word64
 val modulus=valOf(IntInf.fromString"18446744073709551616")
 fun signed h=
   let val value=W.toLargeInt h
   in if W.andb(h,0wx8000000000000000)=0w0 then value else IntInf.-(value,modulus)end
 fun read path=
   let val stream=TextIO.openIn path
       val text=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
   in text end
 fun digit c=
   if c>= #"0"andalso c<= #"9"then Char.ord c-Char.ord #"0"
   else if c>= #"a"andalso c<= #"f"then Char.ord c-Char.ord #"a"+10
   else raise Fail"incorrect result: invalid raster reference hex"
 fun reference path=
   let val text=read path val n=String.size text
       val _=if n>0 andalso String.sub(text,n-1)= #"\n"andalso(n-1)mod 2=0 then()
             else raise Fail"incorrect result: invalid raster reference length"
       val _=List.app(fn c=>ignore(digit c))(String.explode(String.substring(text,0,n-1)))
   in String.substring(text,0,n-1)end
 fun consumeWith step initial depth expected=
   let val bytes=String.size expected div 2
       fun loop stream index hash=case L.force stream of
         S.Nil=>if index=bytes then(index,hash)else raise Fail"incorrect result: truncated Fulsom raster"
        |S.Cons(value,rest)=>
          let val actual=L.force value
              val _=if index<bytes then()else raise Fail"incorrect result: extra Fulsom raster"
              val wanted=digit(String.sub(expected,index*2))*16+digit(String.sub(expected,index*2+1))
              val _=if actual=wanted then()else raise Fail"incorrect result: Fulsom raster byte"
          in loop rest(index+1)(step actual hash)end
   in loop(K.picture depth)0 initial end
 fun consume depth expected=let val(bytes,hash)=consumeWith(fn byte=>fn hash=>W.+(W.fromInt byte,W.*(hash,0w31)))0w0 depth expected in(bytes,signed hash)end
 fun runHashed[repetitionsText,depthText,path,hashText]=
   let val repetitions=BenchInput.between(0,1000)(BenchInput.integer repetitionsText)
       val depth=BenchInput.between(0,9)(BenchInput.integer depthText)
       val wanted=case IntInf.fromString hashText of SOME n=>n|NONE=>raise Fail"invalid signed64 reference hash"
       val expected=reference path
       fun loop 0 count total=Int.toString count^":"^IntInf.toString total
         |loop n count total=
           let val(bytes,hash)=consume depth expected
               val _=if hash=wanted then()else raise Fail"incorrect result: Fulsom signed64 hash"
           in loop(n-1)(count+1)(IntInf.+(total,IntInf.fromInt bytes))end
   in loop repetitions 0(IntInf.fromInt 0)end
 |runHashed _=raise Fail"expected repetitions, octree depth, complete raster reference and signed64 hash"
 fun runRaw[depthText,path]=
   let val depth=BenchInput.between(0,9)(BenchInput.integer depthText)
       val expected=reference path
       val(bytes,())=consumeWith(fn _=>fn()=>())()depth expected
   in Int.toString bytes end
 |runRaw _=raise Fail"expected octree depth and complete raster reference"
 val run=runHashed

end
