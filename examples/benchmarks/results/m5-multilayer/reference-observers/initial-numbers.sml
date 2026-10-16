structure InitialNumbers =
struct
 structure K=BenchMultilayer structure F=BenchMultilayerFiles
 val random=BenchOCamlRandom.default()
 val network=K.initialize(fn()=>BenchOCamlRandom.real random 2.0-1.0)34 2
 fun values(K.Layer{weight,bias,...})=List.concat(Array.foldr(fn(row,rest)=>RealArray.foldr(op ::)[]row::rest)[]weight)@RealArray.foldr(op ::)[]bias
 val actual=List.concat(List.map values network)
 val decimal=List.map F.real(F.tokens "initial-parameters.txt")
 val fields=List.map BenchInput.integer(F.tokens "initial-dyadics.txt")
 fun decode []=[]
   | decode(sign::high::low::exponent::rest)=
     (Real.fromInt sign*(Real.fromManExp{man=Real.fromInt high,exp=exponent+26}+
       Real.fromManExp{man=Real.fromInt low,exp=exponent}))::decode rest
   | decode _=raise Fail "dyadic reference fields"
 val exact=decode fields
 val randomMismatch=ref 0 val decimalMismatch=ref 0
 fun loop [] [] [] _=()
   | loop(a::aa)(d::dd)(e::ee)i=
     (if Real.==(a,e)then()else randomMismatch:= !randomMismatch+1;
      if Real.==(d,e)then()else
        (decimalMismatch:= !decimalMismatch+1;
         if !decimalMismatch<=3 then print("DECIMAL "^Int.toString i^" actual="^
          Real.fmt(StringCvt.GEN(SOME 17))a^" parsed="^Real.fmt(StringCvt.GEN(SOME 17))d^
          " exact="^Real.fmt(StringCvt.GEN(SOME 17))e^"\n")else());
      loop aa dd ee(i+1))
   | loop _ _ _ _=raise Fail "initial reference counts"
 val _=loop actual decimal exact 0
 val _=print("RNG_EXACT_MISMATCH "^Int.toString(!randomMismatch)^"\nDECIMAL_MISMATCH "^Int.toString(!decimalMismatch)^"\nSUMMARY 1 checks, 0 failed\n")
end
