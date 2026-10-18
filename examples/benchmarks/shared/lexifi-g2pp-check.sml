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
