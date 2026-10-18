(* LexiFi SAS, copyright 2000-2013. GPL version 3 or later.
 * Direct SML97 translation of the pinned g2pp_calibration.ml. *)
structure BenchG2Calibration=
struct
 structure D=BenchG2Date
 structure M=BenchG2Math
 structure O=BenchG2Optimization
 type parameters={g_a:real,g_b:real,g_sigma:real,g_nu:real,g_rho:real}
 datatype frequency=Quarterly|Semiannual|Annual
 type swaption={maturityYears:int,frequency:frequency,termYears:int}
 type extended={maturity:D.date,strike:real,schedule:(D.date*D.date)list}
 val pi=2.0*Math.asin 1.0
 fun loop first last f=if first>last then()else(f first;loop(first+1)last f)
 fun extended today zc({maturityYears,frequency,termYears}:swaption):extended=
   let val maturity=D.addYears today maturityYears
       val period=case frequency of Quarterly=>3|Semiannual=>6|Annual=>12
       val count=12*termYears div period
       val schedule=List.tabulate(count,fn i=>(D.addMonths maturity(i*period),D.addMonths maturity((i+1)*period)))
       val(level,t0,tn)=List.foldl(fn((first,payment),(level,t0,tn))=>
         (level+zc payment*D.act365 payment first,Int.min(t0,first),Int.max(tn,payment)))
         (0.0,D.maxDate,D.minDate)schedule
   in {maturity=maturity,schedule=schedule,strike=(zc t0-zc tn)/level}end
 fun bFun(z:real)tau=(1.0-Math.exp(~z*tau))/z
 exception Sdomain
 fun bigV({g_a,g_b,g_rho,g_nu,g_sigma}:parameters)tau=
   let fun t sigma x=
         let val exponential=Math.exp(~x*tau)
             val squared=exponential*exponential
         in sigma*sigma/(x*x)*(tau+2.0/x*exponential-1.0/(2.0*x)*squared-3.0/(2.0*x))end
       val first=t g_sigma g_a
       val second=t g_nu g_b
       val ba=bFun g_a tau val bb=bFun g_b tau
       val third=2.0*g_rho*g_nu*g_sigma/(g_a*g_b)*(tau-ba-bb+bFun(g_a+g_b)tau)
   in(first+second+third,ba,bb)end
 fun bigMx({g_a,g_b,g_rho,g_nu,g_sigma}:parameters)today maturity s t=
   let val ts=D.act365 t s val mt=D.act365 maturity t
       val m0=D.act365 maturity today val ms=D.act365 maturity s
       val t0=D.act365 t today val s0=D.act365 s today
   in (g_sigma*g_sigma/(g_a*g_a)+g_sigma*g_rho*g_nu/(g_a*g_b))*(1.0-Math.exp(~g_a*ts))-
      (g_sigma*g_sigma/(2.0*g_a*g_a)*(Math.exp(~g_a*mt)-Math.exp(~g_a*(ms+ts))))-
      g_rho*g_sigma*g_nu/(g_b*(g_a+g_b))*(Math.exp(~g_b*mt)-Math.exp(~g_b*m0-g_a*t0+(g_a+g_b)*s0))end
 fun bigMy({g_a,g_b,g_rho,g_nu,g_sigma}:parameters)today maturity s t=
   let val ts=D.act365 t s val mt=D.act365 maturity t
       val m0=D.act365 maturity today val ms=D.act365 maturity s
       val t0=D.act365 t today val s0=D.act365 s today
   in (g_nu*g_nu/(g_b*g_b)+g_sigma*g_rho*g_nu/(g_a*g_b))*(1.0-Math.exp(~g_b*ts))-
      (g_nu*g_nu/(2.0*g_b*g_b)*(Math.exp(~g_b*mt)-Math.exp(~g_b*(ms+ts))))-
      g_rho*g_sigma*g_nu/(g_a*(g_a+g_b))*(Math.exp(~g_a*mt)-Math.exp(~g_a*m0-g_b*t0+(g_a+g_b)*s0))end
 fun pricer today zc swaption=
   let val{maturity,strike,schedule}=extended today zc swaption
       val time=D.act365 maturity today
       val payments=Vector.fromList schedule
       val last=Vector.length payments-1
       val taus=Vector.map(fn(first,payment)=>D.act365 payment first)payments
       val ci=Vector.mapi(fn(i,tau)=>if i=last then 1.0+tau*strike else tau*strike)taus
       val n=Vector.length payments
       val bai=Array.array(n,0.0)val bbi=Array.array(n,0.0)
       val aici=Array.array(n,0.0)val logAici=Array.array(n,0.0)
       val scales=Array.array(n,0.0)val constants=Array.array(n,0.0)
       val scale=Array.array(n,0.0)
   in fn(params as{g_a,g_b,g_rho,g_nu,g_sigma}:parameters)=>
     let val(v0,_,_)=bigV params(D.act365 maturity today)
         val zcMaturity=zc maturity
         fun aFun payment=
           let val(vEnd,_,_)=bigV params(D.act365 payment today)
               val(vBetween,ba,bb)=bigV params(D.act365 payment maturity)
           in(zc payment/zcMaturity*Math.exp(0.5*(vBetween-vEnd+v0)),ba,bb)end
         val sx=g_sigma*Math.sqrt(bFun(2.0*g_a)time)
         val sy=g_nu*Math.sqrt(bFun(2.0*g_b)time)
         val correlation=g_rho*g_sigma*g_nu/(sx*sy)*bFun(g_a+g_b)time
         val complement=1.0-correlation*correlation
         val rootComplement=Math.sqrt complement
         val t2=correlation/(sx*rootComplement)
         val syComplement=sy*rootComplement
         val t4=correlation*sy/sx
         val mux= ~(bigMx params today maturity today maturity)
         val muy= ~(bigMy params today maturity today maturity)
         val _=loop 0(n-1)(fn i=>
           let val(_,payment)=Vector.sub(payments,i)
               val(a,ba,bb)=aFun payment
               val x=Vector.sub(ci,i)*a
               val logAc=Math.ln x
               val _=Array.update(aici,i,x)val _=Array.update(logAici,i,logAc)
               val _=Array.update(bai,i,ba)val _=Array.update(bbi,i,bb)
               val t3=muy-0.5*complement*sy*sy*bb
               val constant=bb*(mux*t4-t3)
               val _=Array.update(constants,i,x*Math.exp constant)
           in Array.update(scale,i,~(ba+bb*t4))end)
         val k= ~3.71901648545568
         fun exactYhat x=
           let val lo=ref Real.negInf val up=ref 0.0
               val _=loop 0(n-1)(fn i=>
                 let val baix=Array.sub(bai,i)*x
                     val _=lo:=Real.max(!lo,(Array.sub(logAici,i)-baix)/Array.sub(bbi,i))
                 in up:= !up+Array.sub(aici,i)*Math.exp(~baix)end)
               val lo= !lo val sUp= !up
           in if n=1 then lo else
              let val logS=Math.ln sUp
                  val tmp=logS/Array.sub(bbi,n-1)
                  val up=if tmp<=0.0 then tmp
                    else let val tmp=logS/Array.sub(bbi,0)in if 0.0<=tmp then tmp else Real.negInf end
                  val yl=lo-0.00001 val yu=up+0.00001
                  val y0=sy*(correlation*(x-mux)/sx+k*rootComplement)-complement/g_b+muy
                  val y1=sy*(correlation*(x-mux)/sx-k*rootComplement)+muy
              in if y1<=yl then y1+1.0 else if yu<=y0 then y0-1.0 else
                 (let val _=loop 0(n-1)(fn i=>Array.update(scales,i,Array.sub(aici,i)*Math.exp(~(Array.sub(bai,i))*x)))
                      fun solve yhat=
                        let val total=ref ~1.0
                            val _=loop 0(n-1)(fn i=>total:= !total+Array.sub(scales,i)*Math.exp(~(Array.sub(bbi,i))*yhat))
                        in if Real.isNan(!total)then raise Fail"NaN root function"else !total end
                  in M.brent(Real.max(yl,y0))(Real.min(yu,y1))solve 0.0001 end
                  handle M.Rootfinder M.NotBracketedBelow=>y0-1.0|M.Rootfinder M.NotBracketedAbove=>y1+1.0)
              end
           end
         val eps=0.5*sx
         val f=exactYhat mux
         (* OCaml evaluates the subtraction's right argument first. *)
         val lower=exactYhat(mux-eps)
         val upper=exactYhat(mux+eps)
         val df=0.5*(upper-lower)/eps
         fun yhat x=f+df*(x-mux)
         fun integrand x=
           let val t1=Math.exp(~0.5*Math.pow((x-mux)/sx,2.0))
               val yh=yhat x
               val h1=(yh-muy)/syComplement-t2*(x-mux)
               val t2=M.gaussianP(~h1)
               val total=ref 0.0
               val _=loop 0(n-1)(fn i=>
                 let val h2=h1+Array.sub(bbi,i)*syComplement
                 in total:= !total+Array.sub(constants,i)*Math.exp(Array.sub(scale,i)*x)*M.gaussianP(~h2)end)
           in t1*(t2- !total)end
         val sqrt2sx=Math.sqrt 2.0*sx
         val total=ref 0.0
         val _=loop 0(Vector.length M.hermiteNodes-1)(fn i=>
           total:= !total+Vector.sub(M.hermiteWeights,i)*integrand(sqrt2sx*Vector.sub(M.hermiteNodes,i)+mux))
         val integral= !total/Math.sqrt pi
     in zcMaturity*integral end
   end
 fun blackPrice today zc swaption vol=
   let val{schedule,strike,maturity}=extended today zc swaption
       (* Source uses year fraction here, despite its sqrtt variable name. *)
       val time=D.act365 maturity today
       val(level,t0,tn)=List.foldl(fn((first,payment),(level,t0,tn))=>
         (level+zc payment*D.act365 payment first,Int.min(t0,first),Int.max(tn,payment)))
         (0.0,D.maxDate,D.minDate)schedule
       val s0=(zc t0-zc tn)/level
       val d1=Math.ln(s0/strike)/(vol*time)+0.5*vol*time
       val d2=d1-vol*time
   in level*(s0*M.gaussianP d1-strike*M.gaussianP d2)end
 fun calibrate feedback maxGlobal today quotes variables zc=
   let val _=if Array.length variables=5 then()else raise Fail"five model parameters required"
       val market=Array.tabulate(Vector.length quotes,fn i=>
         let val(sw,vol)=Vector.sub(quotes,i)in blackPrice today zc sw vol end)
       fun parametersOfVector x:parameters={g_a=Array.sub(x,0),g_b=Array.sub(x,1),
         g_sigma=Array.sub(x,2),g_nu=Array.sub(x,3),g_rho=Array.sub(x,4)}
       val pricers=Vector.map(fn(sw,_)=>pricer today zc sw)quotes
       fun price params dest=
         loop 0(Vector.length pricers-1)(fn i=>Array.update(dest,i,Vector.sub(pricers,i)params))
         handle Sdomain=>raise O.Infeasible
   in O.leastSquares false feedback maxGlobal parametersOfVector price variables market end
end
