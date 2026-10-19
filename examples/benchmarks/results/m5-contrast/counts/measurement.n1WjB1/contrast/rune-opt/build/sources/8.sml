(* Andreas Romeyke, copyright 2009-2012, GPL version 2 or later.
 * Direct translation of the pinned contrast.ml workload. Source window bounds,
 * cached integer arithmetic and threshold formulas are retained. *)
structure BenchSauvola=
struct
 structure I=BenchSauvolaImage
 type window={x0:int,y0:int,x1:int,y1:int}
 type statistics={rMean:real,gMean:real,bMean:real,rStd:real,gStd:real,bStd:real}
 val loop=I.loop
 fun stddev qsum sum n=
   let val mean=sum/n
       val variance=(qsum-sum*mean)/(n-1.0)
   in if variance>=0.0 then Math.sqrt variance else raise Fail"negative image prevariance"end
 fun statistics image:statistics=
   let val rs=ref 0 val gs=ref 0 val bs=ref 0
       val rq=ref(IntInf.fromInt 0)val gq=ref(IntInf.fromInt 0)val bq=ref(IntInf.fromInt 0)
       val _=loop 0(I.width image-1)(fn x=>loop 0(I.height image-1)(fn y=>
         let val{r,g,b}=I.get image x y
         in rs:= !rs+r;gs:= !gs+g;bs:= !bs+b;
            rq:=IntInf.+(!rq,IntInf.fromInt(r*r));
            gq:=IntInf.+(!gq,IntInf.fromInt(g*g));
            bq:=IntInf.+(!bq,IntInf.fromInt(b*b))end))
       val n=Real.fromInt(I.width image*I.height image)
   in {rMean=Real.fromInt(!rs)/n,gMean=Real.fromInt(!gs)/n,bMean=Real.fromInt(!bs)/n,
       rStd=stddev(Real.fromLargeInt(!rq))(Real.fromInt(!rs))n,
       gStd=stddev(Real.fromLargeInt(!gq))(Real.fromInt(!gs))n,
       bStd=stddev(Real.fromLargeInt(!bq))(Real.fromInt(!bs))n}end
 fun window width height x y:window=
   {x0=Int.max(0,x-15),y0=Int.max(0,y-15),
    x1=Int.min(width-1,x+15),y1=Int.min(height-1,y+15)}
 fun requireDimensions image=
   if I.width image>30 andalso I.height image>30 then()else raise Fail"source image must exceed 30 by 30"
 fun localStatistics image x y=
   let val{x0,y0,x1,y1}=window(I.width image)(I.height image)x y
       (* Source RGB statistics exclude the inclusive upper border. *)
   in statistics(I.sub image x0 y0(x1-x0)(y1-y0))end
 fun thresholdColor({r,g,b}:I.rgb)(rt,gt,bt):I.rgb=
   {r=if Real.fromInt r>rt then 255 else 0,
    g=if Real.fromInt g>gt then 255 else 0,
    b=if Real.fromInt b>bt then 255 else 0}
 fun monochrome value:I.rgb={r=value,g=value,b=value}
 fun adaptive image=
   let val _=requireDimensions image
       val result=I.create(I.width image)(I.height image)
       fun norm value mean deviation=
         let val low=mean-3.0*deviation val high=mean+3.0*deviation
             val normalized=255.0*(Real.fromInt value-low)/(high-low)
         in if normalized>127.0 then 255 else 0 end
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val{rMean,gMean,bMean,rStd,gStd,bStd}=localStatistics image x y
             val{r,g,b}=I.get image x y
         in I.set result x y{r=norm r rMean rStd,g=norm g gMean gStd,b=norm b bMean bStd}end))
   in result end
 fun niblackGlobal image=
   let val{rMean,gMean,bMean,rStd,gStd,bStd}=statistics image
       val rt=rMean-0.2*rStd val gt=gMean-0.2*gStd val bt=bMean-0.2*bStd
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         I.set result x y(thresholdColor(I.get image x y)(rt,gt,bt))))
   in result end
 fun niblackLocal image=
   let val _=requireDimensions image
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val{rMean,gMean,bMean,rStd,gStd,bStd}=localStatistics image x y
         in I.set result x y(thresholdColor(I.get image x y)
           (rMean-0.2*rStd,gMean-0.2*gStd,bMean-0.2*bStd))end))
   in result end
 type cache={sum:int ref,qsum:int ref,n:int ref,x:int ref,y:int ref}
 fun cache():cache={sum=ref 0,qsum=ref 0,n=ref 0,x=ref 0,y=ref 0}
 fun windowValues image x y({sum=cs,qsum=cq,n=cn,x=lastX,y=lastY}:cache)=
   let val _=requireDimensions image
       val{x0,y0,x1,y1}=window(I.width image)(I.height image)x y
       val qsum=ref 0 val sum=ref 0 val n=ref 0
       val _=if x0>0 andalso x1<I.width image andalso !cn>0 andalso !lastY=y andalso !lastX+1=x
         then(qsum:= !cq;sum:= !cs;n:= !cn;
           loop y0 y1(fn j=>
             let val old=I.brightness(I.get image(x0-1)j)
                 val next=I.brightness(I.get image x1 j)
             in qsum:= !qsum+next*next-old*old;sum:= !sum+next-old end))
         else(loop y0 y1(fn j=>loop x0 x1(fn i=>
           let val value=I.brightness(I.get image i j)
           in qsum:= !qsum+value*value;sum:= !sum+value end));
           n:=(1+y1-y0)*(1+x1-x0))
       val _=cs:= !sum val _=cq:= !qsum val _=cn:= !n
       val _=lastX:=x val _=lastY:=y
       val mean=Int.quot(!sum,!n)
       val variance=Int.quot(!qsum- !sum*mean,!n-1)
   in(mean,variance)end
 fun niblackMono image=
   let val cache=cache()
       val threshold=BenchSauvolaIntMemo.memo(fn(mean,variance)=>
         Real.fromInt mean-0.2*Math.sqrt(Real.fromInt variance))
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val limit=threshold(windowValues image x y cache)
             val light=I.brightness(I.get image x y)
         in I.set result x y(monochrome(if Real.fromInt light>limit then 255 else 0))end))
   in result end
 fun sauvolaThreshold mean deviation=mean+(1.0+0.6*(deviation/128.0-1.0))
 fun sauvolaGlobal image=
   let val{rMean,gMean,bMean,rStd,gStd,bStd}=statistics image
       val rt=sauvolaThreshold rMean rStd
       val gt=sauvolaThreshold gMean gStd
       val bt=sauvolaThreshold bMean bStd
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         I.set result x y(thresholdColor(I.get image x y)(rt,gt,bt))))
   in result end
 fun sauvolaGlobalMono image=
   let val{rMean,gMean,bMean,rStd,gStd,bStd}=statistics image
       val rt=sauvolaThreshold rMean rStd
       val gt=sauvolaThreshold gMean gStd
       val bt=sauvolaThreshold bMean bStd
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val{r,g,b}=I.get image x y
             val value=if Real.fromInt r>rt orelse Real.fromInt g>gt orelse Real.fromInt b>bt then 255 else 0
         in I.set result x y(monochrome value)end))
   in result end
 fun sauvolaLocal image=
   let val threshold=BenchSauvolaRealMemo.memo(fn(mean,deviation)=>mean*(1.0-0.35*(1.0-deviation/128.0)))
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val color=I.get image x y
         in if I.brightness color>200 then I.set result x y(monochrome 255)
            else let val{rMean,gMean,bMean,rStd,gStd,bStd}=localStatistics image x y
                     val rt=threshold(rMean,rStd)val gt=threshold(gMean,gStd)val bt=threshold(bMean,bStd)
                 in I.set result x y(thresholdColor color(rt,gt,bt))end
         end))
   in result end
 fun sauvolaMono image=
   let val cache=cache()
       val threshold=BenchSauvolaIntMemo.memo(fn(mean,variance)=>
         Real.fromInt mean*(1.0-0.35*(1.0-Math.sqrt(Real.fromInt variance)/128.0)))
       val result=I.create(I.width image)(I.height image)
       val _=loop 0(I.height image-1)(fn y=>loop 0(I.width image-1)(fn x=>
         let val light=I.brightness(I.get image x y)
         in if light>200 then I.set result x y(monochrome 255)
            else let val limit=threshold(windowValues image x y cache)
                 in I.set result x y(monochrome(if Real.fromInt light>limit then 255 else 0))end
         end))
   in result end
end
