functor BenchSphereDiagnosticDriverFn(K:sig
    type vector val ray:int->(int*int*vector)BenchStream.stream
    val components:vector->real*real*real
  end) =
struct
  type pixel=int*int*(real*real*real)*(int*int*int)
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f
    val _=TextIO.closeIn f in text end
  fun real text=case Real.fromString text of SOME x=>if Real.isFinite x then x
    else raise Fail "nonfinite sphere reference"|NONE=>raise Fail "invalid sphere real"
  fun integer text=BenchInput.integer text
  fun reference text=List.map(fn row=>case String.tokens Char.isSpace row of
      [i,j,r,g,b,qr,qg,qb]=>(integer i,integer j,(real r,real g,real b),(integer qr,integer qg,integer qb))
    |_=>raise Fail "sphere reference expects pixel coordinates, reals and quantized values")
    (String.tokens(fn c=>c= #"\n")text)
  fun valid((r,g,b),(er,eg,eb))=
    List.all(fn(a,e)=>BenchInput.closeReal(a,e,1.0E~9,1.0E~9))[(r,er),(g,eg),(b,eb)]
  fun quantize(r,g,b)=(Real.round(255.0*r),Real.round(255.0*g),Real.round(255.0*b))
  fun consume expected pixels=
    let fun loop count hash power rows values=case(BenchLazy.force values,rows)of
          (BenchStream.Nil,[]) => (count,hash)
        |(BenchStream.Cons(value,rest),(ei,ej,wanted,rounded)::rows)=>
          let val(i,j,color)=BenchLazy.force value val rgb=K.components color
              val _=if i=ei andalso j=ej andalso valid(rgb,wanted)andalso quantize rgb=rounded
                then()else
                 let fun triple(a,b,c)=String.concatWith" "
                       (List.map(Real.fmt(StringCvt.GEN(SOME 17)))[a,b,c])
                 in print("DIAGNOSTIC pixel "^Int.toString i^" "^Int.toString j^
                    " actual "^triple rgb^" expected "^triple wanted^"\n");
                    raise Fail "incorrect result: sphere pixel"end
              val(r,g,b)=rounded
              val coefficient=Word64.fromInt(r+g*7+b*23)
          in loop(count+1)(Word64.+(hash,Word64.*(coefficient,power)))
            (Word64.*(power,0w61))rows rest end
        |_=>raise Fail "incorrect result: sphere pixel count"
    in loop 0(0w0:Word64.word)(0w1:Word64.word)expected pixels end
  fun run[repeatsText,sizeText,path]=
    let val repeats=BenchInput.between(0,1000)(integer repeatsText)
        val size=BenchInput.between(1,1024)(integer sizeText)
        val expected=reference(read path)
        val _=if List.length expected=size*size then()else raise Fail "wrong sphere reference size"
        fun loop 0 checked hash=Int.toString repeats^":"^Int.toString checked^" "^Word64.toString hash
          |loop n checked _=
            let val _=print("DIAGNOSTIC remaining "^Int.toString n^"\n")
                val(count,hash)=consume expected(K.ray size)
            in loop(n-1)(checked+count)hash end
    in loop repeats 0(0w0:Word64.word)end
    |run _=raise Fail "sphere expects repetitions, square image size and pixel reference"
end
