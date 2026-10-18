structure BenchG2Check=
struct
 type expected={limit:int,parameters:real vector,rms:real,prices:real vector,quoted:real vector}
 fun close(observed,expected,absolute,relative)=
   Real.isFinite observed andalso Real.isFinite expected andalso
   Real.abs(observed-expected)<=absolute+relative*Real.abs expected
 type result={parameters:BenchG2Calibration.parameters,rms:real,
  quoted:real array,calibrated:real array}
 fun valid (result:result)({parameters,rms,prices,quoted,...}:expected)=
   let val{g_a,g_b,g_sigma,g_nu,g_rho}= #parameters result
       val observed=Vector.fromList[g_a,g_b,g_sigma,g_nu,g_rho]
       fun vectors n expected get absolute relative=
         Vector.length expected=n andalso
         let fun loop i=i=n orelse(close(get i,Vector.sub(expected,i),absolute,relative)andalso loop(i+1))
         in loop 0 end
   in vectors 5 parameters(fn i=>Vector.sub(observed,i))1.0E~8 1.0E~8 andalso
      close(#rms result,rms,1.0E~7,1.0E~8)andalso
      vectors(Array.length(#calibrated result))prices(fn i=>Array.sub(#calibrated result,i))1.0E~9 1.0E~8 andalso
      vectors(Array.length(#quoted result))quoted(fn i=>Array.sub(#quoted result,i))1.0E~9 1.0E~8
   end
 fun verify result expected=if valid result expected then()else raise Fail"incorrect result: G2++ calibration"
end
structure BenchG2Driver=
struct
 fun read path=
   let val stream=TextIO.openIn path
       val contents=(TextIO.inputAll stream before TextIO.closeIn stream)
         handle ex=>(TextIO.closeIn stream;raise ex)
       fun integer text=case Int.fromString text of SOME n=>n|NONE=>raise Fail"invalid G2++ reference integer"
       fun real text=case Real.fromString text of SOME n=>n|NONE=>raise Fail"invalid G2++ reference real"
       fun pairs 0 [] prices quoted=(Vector.fromList(rev prices),Vector.fromList(rev quoted))
         |pairs n(price::quote::rest)prices quoted=
            if n<=0 then raise Fail"extra G2++ reference prices"
            else pairs(n-1)rest(real price::prices)(real quote::quoted)
         |pairs _ _ _ _=raise Fail"invalid G2++ reference length"
   in case String.tokens Char.isSpace contents of
     limit::count::a::b::sigma::nu::rho::rms::rest=>
       let val count=integer count
           val _=if count=196 then()else raise Fail"wrong G2++ quote count"
           val(prices,quoted)=pairs count rest[][]
       in {limit=integer limit,parameters=Vector.fromList(List.map real[a,b,sigma,nu,rho]),
           rms=real rms,prices=prices,quoted=quoted}:BenchG2Check.expected end
     |_=>raise Fail"invalid G2++ reference header"
   end
 fun calculate limit=BenchG2Calibration.calibrate NONE limit
   BenchG2Input.today BenchG2Input.quotes BenchG2Input.variables BenchG2Input.zc
 fun run limit path=
   let val expected=read path
       val _=if #limit expected=limit then()else raise Fail"reference limit mismatch"
       val result=calculate limit
       val _=BenchG2Check.verify result expected
   in Int.toString limit^":196"end
end
