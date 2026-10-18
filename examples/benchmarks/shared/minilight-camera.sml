(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniCamera=
struct
 structure V=BenchMiniVector
 datatype t=Camera of{position:V.t,direction:V.t,angle:real,right:V.t,up:V.t}
 fun read input=
   let val position=BenchMiniParse.vector input
       val rawDirection=V.unitize(BenchMiniParse.vector input)
       val direction=if not(V.equal rawDirection V.zero)then rawDirection else V.oneZ
       val rawAngle=BenchMiniParse.real input
       val angle=Real.max(10.0,Real.min(rawAngle,160.0))*(3.141592653589793238512809/180.0)
       val right=V.unitize(V.cross V.oneY direction)
       val(right,up)=if not(V.equal right V.zero)then(right,V.unitize(V.cross direction right))
         else let val up=if V.sub direction 1<0.0 then V.oneZ else V.negative V.oneZ
              in(V.unitize(V.cross up direction),up)end
   in Camera{position=position,direction=direction,angle=angle,right=right,up=up}end
 fun eye(Camera{position,...})=position
 fun frame(Camera{position,direction,angle,right,up})scene image random=
   let val tracer=BenchMiniRay.create scene
       val width=Real.fromInt(BenchMiniImage.width image)
       val height=Real.fromInt(BenchMiniImage.height image)
       fun pixel x y=
         let (* The source coordinate tuple draws y jitter before x. *)
             val yRandom=BenchOCamlRandom.real random 1.0
             val xRandom=BenchOCamlRandom.real random 1.0
             val xF=(Real.fromInt x+xRandom)*2.0/width-1.0
             val yF=(Real.fromInt y+yRandom)*2.0/height-1.0
             val offset=V.add(V.scale right xF)(V.scale up(yF*(height/width)))
             val sample=V.unitize(V.add direction(V.scale offset(Math.tan(angle*0.5))))
             val radiance=BenchMiniRay.radiance tracer position sample NONE random
         in BenchMiniImage.add image x y radiance end
       fun row y=
         let fun column x=if x<0 then()else(pixel x y;column(x-1))
         in column(BenchMiniImage.width image-1)end
       fun rows y=if y<0 then()else(row y;rows(y-1))
       val _=rows(BenchMiniImage.height image-1)
   in image end
end
