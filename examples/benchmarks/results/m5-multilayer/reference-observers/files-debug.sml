structure BenchMultilayerFiles =
struct
  structure K=BenchMultilayer
  type snapshot={weight:K.matrix,bias:K.vector}
  type reference={layers:snapshot list,predictions:K.vector array,error:real}
  fun tokens path=let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;String.tokens Char.isSpace text end
  fun real text=case Real.fromString text of SOME x=>
      if Real.isFinite x then x else raise Fail "nonfinite network reference"
    | NONE=>raise Fail "invalid network reference real"
  fun numbers count fields=
    let fun loop 0 rest acc=(RealArray.fromList(List.rev acc),rest)
          | loop n(x::xs)acc=loop(n-1)xs(real x::acc)
          | loop _ [] _=raise Fail "short network data"
    in loop count fields []end
  fun data path=case tokens path of count::width::classes::rest=>
    let val n=BenchInput.between(1,351)(BenchInput.integer count)
        val w=BenchInput.between(1,34)(BenchInput.integer width)
        val _=if classes="2"then()else raise Fail "network class count differs"
        val good=RealArray.fromList[1.0,0.0]val bad=RealArray.fromList[0.0,1.0]
        fun rows 0 [] acc=Array.fromList(List.rev acc)
          | rows 0 _ _=raise Fail "extra network samples"
          | rows left fields acc=
            let val(input,tail)=numbers w fields
            in case tail of label::rest=>
              let val target=if label="g"then good else if label="b"then bad else raise Fail "unknown sample class"
              in rows(left-1)rest((input,target)::acc)end
              | _=>raise Fail "missing sample class"end
    in rows n rest []end
    | _=>raise Fail "missing sample dimensions"
  fun reference path=
    let fun layers index fields acc=case fields of
          "layer"::id::height::width::rest=>
            let val _=if BenchInput.integer id=index then()else raise Fail "network layer order differs"
                val m=BenchInput.between(1,10)(BenchInput.integer height)
                val n=BenchInput.between(1,34)(BenchInput.integer width)
                val(flat,tail)=numbers(m*n)rest
                val(bias,tail)=numbers m tail
                val weight=K.initMatrix m n(fn i=>fn j=>RealArray.sub(flat,i*n+j))
            in layers(index+1)tail({weight=weight,bias=bias}::acc)end
        | "predictions"::size::rest=>
            let val _=if index=3 then()else raise Fail "network layer count differs"
                val n=BenchInput.between(1,351)(BenchInput.integer size)
                val(flat,tail)=numbers(2*n)rest
                val predictions=Array.tabulate(n,fn i=>RealArray.fromList[RealArray.sub(flat,2*i),RealArray.sub(flat,2*i+1)])
            in case tail of["error",value]=>{layers=List.rev acc,predictions=predictions,error=real value}
              | _=>raise Fail "network reference trailer differs"end
        | _=>raise Fail "invalid network reference header"
    in layers 0(tokens path)[]end
  fun checkVector absolute relative expected actual=
    let val n=RealArray.length expected
        val _=if RealArray.length actual=n then()else raise Fail "network vector dimensions differ"
    in K.for 0(n-1)(fn i=>
      if BenchInput.closeReal(RealArray.sub(actual,i),RealArray.sub(expected,i),absolute,relative)
      then()else (TextIO.print("DIFF index="^Int.toString i^
        " actual="^Real.fmt(StringCvt.GEN(SOME 17))(RealArray.sub(actual,i))^
        " expected="^Real.fmt(StringCvt.GEN(SOME 17))(RealArray.sub(expected,i))^
        " absolute="^Real.toString absolute^" relative="^Real.toString relative^"\n");
        raise Fail "network value differs"))end
  fun checkParameters expected actual=
    let fun loop [] []=()
          | loop(({weight=ew,bias=eb}:snapshot)::es)(K.Layer{weight,bias,...}::layers)=
            let val _=if Array.length ew=Array.length weight then()else raise Fail "network weight dimensions differ"
                val _=K.for 0(Array.length ew-1)(fn i=>checkVector 2.0E~8 2.0E~7(Array.sub(ew,i))(Array.sub(weight,i)))
                val _=checkVector 2.0E~8 2.0E~7 eb bias
            in loop es layers end
          | loop _ _=raise Fail "network layer count differs"
    in loop expected actual end
  fun check({layers=expected,predictions,error}:reference)network samples=
    let val _=checkParameters expected network
        val _=if Array.length predictions=Array.length samples then()else raise Fail "prediction count differs"
        val _=K.for 0(Array.length samples-1)(fn i=>
          let val(input,_)=Array.sub(samples,i)val actual=K.forward network input
              val _=checkVector 2.0E~8 2.0E~7(Array.sub(predictions,i))actual
              val sum=K.mapSum(fn x=>x)actual
              val inRange=RealArray.foldl(fn(value,ok)=>ok andalso value>=0.0 andalso value<=1.0)true actual
          in if inRange andalso BenchInput.closeReal(sum,1.0,1.0E~12,0.0)then()
             else raise Fail "invalid probability vector"end)
        val actualError=K.evaluate network samples
    in if BenchInput.closeReal(actualError,error,1.0E~7,1.0E~7)then()
       else raise Fail "network error differs"end
end
