(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained.
 * RealArray preserves the source's three-element floating array representation. *)
structure BenchMiniVector=
struct
 type t=RealArray.array
 fun create x y z=RealArray.fromList[x,y,z]
 fun sub value i=RealArray.sub(value,i)
 val zero=RealArray.array(3,0.0)
 val one=RealArray.array(3,1.0)
 val maximum=RealArray.array(3,Real.maxFinite)
 val oneX=create 1.0 0.0 0.0
 val oneY=create 0.0 1.0 0.0
 val oneZ=create 0.0 0.0 1.0
 fun fold f value=f(f(sub value 0)(sub value 1))(sub value 2)
 fun zip f a b=
   let val z=f(sub a 2)(sub b 2)
       val y=f(sub a 1)(sub b 1)
       val x=f(sub a 0)(sub b 0)
   in create x y z end
 fun add a b=zip(fn x=>fn y=>x+y)a b
 fun subtract a b=zip(fn x=>fn y=>x-y)a b
 fun multiply a b=zip(fn x=>fn y=>x*y)a b
 fun divide a b=zip(fn x=>fn y=>x/y)a b
 fun scale value factor=create(sub value 0*factor)(sub value 1*factor)(sub value 2*factor)
 fun divideScalar value divisor=scale value(1.0/divisor)
 fun dot a b=sub a 0*sub b 0+sub a 1*sub b 1+sub a 2*sub b 2
 fun length value=Math.sqrt(dot value value)
 fun negative value=create(~(sub value 0))(~(sub value 1))(~(sub value 2))
 fun unitize value=if not(Real.==(length value,0.0))then divideScalar value(length value)else zero
 fun cross a b=create
   (sub a 1*sub b 2-sub a 2*sub b 1)
   (sub a 2*sub b 0-sub a 0*sub b 2)
   (sub a 0*sub b 1-sub a 1*sub b 0)
 fun clamp lower upper value=zip(fn a=>fn b=>Real.min(a,b))upper
   (zip(fn a=>fn b=>Real.max(a,b))lower value)
 fun scaleFrame frame scaleValue=
   add(add(scale(Array.sub(frame,0))(sub scaleValue 0))
          (scale(Array.sub(frame,1))(sub scaleValue 1)))
      (scale(Array.sub(frame,2))(sub scaleValue 2))
 fun equal a b=Real.==(sub a 0,sub b 0)andalso Real.==(sub a 1,sub b 1)andalso Real.==(sub a 2,sub b 2)
end
