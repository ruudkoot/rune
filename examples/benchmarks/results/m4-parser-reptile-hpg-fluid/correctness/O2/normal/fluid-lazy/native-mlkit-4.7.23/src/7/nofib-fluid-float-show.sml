(* GHC 9.4.7 base 4.17.2.0 GHC.Float:
   floatToDigits base 10 and formatRealFloat FFGeneric Nothing, binary32.
   Original source pin and full base licence accompany the imported support. *)
structure BenchFluidFloatShow=struct
 fun pow base exponent=IntInf.pow(base,exponent)
 fun digits x=if Real.==(x,0.0)then([0],0)else
   let val{man,exp}=Real.toManExp x
       val f0=IntInf.fromInt(Real.round(man*16777216.0))
       val e0=exp-24
       val minimum= ~149
       val adjustment=minimum-e0
       val(f,e)=if adjustment>0 then(IntInf.quot(f0,pow 2 adjustment),e0+adjustment)else(f0,e0)
       val(r,s,up,down)=if e>=0 then
           let val be=pow 2 e in if f=8388608 then(f*be*4,4,be*2,be)else(f*be*2,2,be,be)end
         else if e>minimum andalso f=8388608 then(f*4,pow 2(~e+1)*2,2,1)
         else(f*2,pow 2(~e)*2,1,1)
       val lx=23+e0 val estimate=Int.quot(lx*8651,28738)
       val estimate=if lx>=0 then estimate+1 else estimate
       fun fix n=if n>=0 then if r+up<=pow 10 n*s then n else fix(n+1)
           else if pow 10(~n)*(r+up)<=s then n else fix(n+1)
       val k=fix estimate
       fun gen acc rn sn up down=
         let val(digit,remainder)=IntInf.quotRem(rn*10,sn)
             val up=up*10 val down=down*10
             val digit=IntInf.toInt digit
         in case(remainder<down,remainder+up>sn)of
            (true,false)=>List.rev(digit::acc)
           |(false,true)=>List.rev((digit+1)::acc)
           |(true,true)=>List.rev((if remainder*2<sn then digit else digit+1)::acc)
           |(false,false)=>gen(digit::acc)remainder sn up down end
       val values=if k>=0 then gen[]r(s*pow 10 k)up down else
         let val bk=pow 10(~k)in gen[](r*bk)s(up*bk)(down*bk)end
   in(values,k)end
 fun signed n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun format(values,exponent)=
   let val chars=List.map(fn n=>Char.chr(n+48))values
       val string=String.implode chars
       fun zeros n=String.implode(List.tabulate(n,fn _=> #"0"))
   in if exponent<0 orelse exponent>7 then
       case chars of []=>raise Fail"formatRealFloat: no digits"
        |[d]=>String.str d^".0e"^signed(exponent-1)
        |d::rest=>String.str d^"."^String.implode rest^"e"^signed(exponent-1)
     else if exponent<=0 then"0."^zeros(~exponent)^string
     else if String.size string<=exponent then string^zeros(exponent-String.size string)^".0"
     else String.substring(string,0,exponent)^"."^String.extract(string,exponent,NONE)end
 fun show x=if Real.isNan x then"NaN"else if not(Real.isFinite x)then
      if x<0.0 then"-Infinity"else"Infinity"
   else if Real.signBit x then"-"^format(digits(Real.abs x))else format(digits x)
end
