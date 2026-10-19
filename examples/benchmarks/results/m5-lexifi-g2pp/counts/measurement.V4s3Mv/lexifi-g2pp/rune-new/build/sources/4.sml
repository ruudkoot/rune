(* LexiFi SAS, copyright 2000-2013. GPL version 3 or later.
 * Direct SML97 translation of the pinned benchmark math.ml. *)
structure BenchG2Math=
struct
 fun erf(x:real)=
   let val t=1.0/(1.0+0.3275911*x)
       val t2=t*t val t3=t*t2 val t4=t*t3 val t5=t*t4
   in 1.0-(0.254829592*t+ ~0.284496736*t2+1.421413741*t3+
        ~1.453152027*t4+1.061405429*t5)*Math.exp(~x*x)end
 fun gaussianP x=
   let val u=x/Math.sqrt 2.0
       val error=if u<0.0 then ~(erf(~u))else erf u
   in 0.5*(1.0+error)end
 datatype error=NotBracketedBelow|NotBracketedAbove
 exception Rootfinder of error
 fun brent a b eval eps=
   let val _=if a>b then raise Fail"root interval reversed"else()
       (* Preserve the observed OCaml tuple evaluation order. *)
       val fb=eval b val fa=eval a
       val _=if 0.0<fa*fb then raise Rootfinder(if fa<0.0 then NotBracketedBelow else NotBracketedAbove)else()
       val _=if eps>=0.0 then()else raise Fail"negative root tolerance"
       val(a,fa,b,fb)=if Real.abs fa<Real.abs fb then(b,fb,a,fa)else(a,fa,b,fb)
       fun iter i a b c d fa fb fc mflag=
         if Real.abs(b-a)<eps orelse Real.==(fb,0.0)orelse 10000<i then b
         else
           let val s=if not(Real.==(fa,fc))andalso not(Real.==(fb,fc))then
                 a*fb*fc/((fa-fb)*(fa-fc))+b*fa*fc/((fb-fa)*(fb-fc))+
                   c*fa*fb/((fc-fa)*(fc-fb))
                 else b-fb*(b-a)/(fb-fa)
               val(s,mflag)=if
                 (4.0*s<3.0*a+b orelse b<s)orelse
                 (mflag andalso 2.0*Real.abs(s-b)>=Real.abs(b-c))orelse
                 (not mflag andalso 2.0*Real.abs(s-b)>=Real.abs(c-d))orelse
                 (mflag andalso Real.abs(b-c)<eps)orelse
                 (not mflag andalso Real.abs(c-d)<eps)
                 then(0.5*(a+b),true)else(s,false)
               val fs=eval s
           in if fa*fs<0.0 then
                if Real.abs fa<Real.abs fs then iter(i+1)s a b c fs fa fb mflag
                else iter(i+1)a s b c fa fs fb mflag
              else if Real.abs fs<Real.abs fb then iter(i+1)b s b c fb fs fb mflag
                else iter(i+1)s b b c fs fb fb mflag
           end
   in iter 0 a b a(Real.posInf-Real.posInf)fa fb fa true end
 val hermiteNodes=Vector.fromList[
   0.0,0.6568095668820999044613,~0.6568095668820997934390,~1.3265570844949334805563,
   1.3265570844949330364670,2.0259480158257567872226,~2.0259480158257558990442,
   ~2.7832900997816496513337,2.7832900997816474308877,3.6684708465595856630159,
   ~3.6684708465595838866591]
 val hermiteWeights=Vector.fromList[
   0.6547592869145917315876,0.6609604194409607336169,0.6609604194409606225946,
   0.6812118810666693002887,0.6812118810666689672217,0.7219536247283847574252,
   0.7219536247283852015144,0.8025168688510405656800,0.8025168688510396775015,
   1.0065267861723647957461,1.0065267861723774522886]
end
