structure GameNumericTests =
struct
  structure N=BenchRecordNBody structure M=BenchMandelbrotSix structure C=BenchRecordNBodyCheck
  structure P=BenchPBMCheckFn(M)
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~12,1.0E~12)
  fun body(x,y,z,vx,vy,vz,mass):N.body=
    {x=ref x,y=ref y,z=ref z,vx=ref vx,vy=ref vy,vz=ref vz,mass=mass}
  fun rejects f=(f();false)handle Fail _=>true
  val _=T.check("game-nbody/full-zero-state",fn()=>(C.run 0 "nbody-0.expected" 1.0E~10 1.0E~10;true))
  val _=T.check("game-nbody/full-ten-step-state",fn()=>(C.run 10 "nbody-10.expected" 1.0E~10 1.0E~10;true))
  val _=T.check("game-nbody/fresh-records",fn()=>
    let val first=N.initial()val second=N.initial()val _= #x(Array.sub(first,0)):=2.0
    in close(!(#x(Array.sub(second,0))),0.0)end)
  val _=T.check("game-nbody/offset-momentum",fn()=>
    let val bodies=N.initial()val _=N.offset bodies
        fun sum get=Array.foldl(fn(b,acc)=>acc+get b* #mass b)0.0 bodies
    in Real.abs(sum(fn b=> !(#vx b)))<1.0E~15 andalso
       Real.abs(sum(fn b=> !(#vy b)))<1.0E~15 andalso
       Real.abs(sum(fn b=> !(#vz b)))<1.0E~15 end)
  val _=T.check("game-nbody/two-body-step",fn()=>
    let val bodies=Array.fromList[body(~1.0,0.0,0.0,0.0,0.0,0.0,1.0),body(1.0,0.0,0.0,0.0,0.0,0.0,1.0)]
        val _=N.advance bodies 0.1 val a=Array.sub(bodies,0)val b=Array.sub(bodies,1)
    in close(!(#vx a),0.025)andalso close(!(#vx b),~0.025)andalso
       close(!(#x a),~0.9975)andalso close(!(#x b),0.9975)end)
  val _=T.check("game-nbody/kinetic-and-potential",fn()=>
    close(N.energy(Array.fromList[body(0.0,0.0,0.0,1.0,2.0,3.0,2.0)]),14.0)andalso
    close(N.energy(Array.fromList[body(~1.0,0.0,0.0,0.0,0.0,0.0,1.0),body(1.0,0.0,0.0,0.0,0.0,0.0,1.0)]),~0.5))
  val _=T.check("game-nbody/one-body-drift",fn()=>
    let val bodies=Array.fromList[body(2.0,3.0,4.0,1.0,~2.0,3.0,1.0)]val _=N.advance bodies 0.1
        val b=Array.sub(bodies,0)
    in close(!(#x b),2.1)andalso close(!(#y b),2.8)andalso close(!(#z b),4.3)end)
  val expected=C.values "nbody-10.expected"
  val _=T.check("game-nbody/perturbed-state-rejected",fn()=>case expected of x::xs=>
    not(C.matches 1.0E~10 1.0E~10 (x+0.01::xs)expected)|_=>false)
  val _=T.check("game-nbody/missing-state-rejected",fn()=>not(C.matches 1.0E~10 1.0E~10 []expected))
  val _=T.check("game-nbody/nonfinite-state-rejected",fn()=>case expected of _::xs=>
    not(C.matches 1.0E~10 1.0E~10 (Real.posInf::xs)expected)|_=>false)
  val _=List.app(fn(width,count)=>T.check("game-mandelbrot/full-pbm-"^Int.toString width,fn()=>
    P.run width("mandelbrot-"^Int.toString width^".pbm")=count))
    [(1,8),(7,14),(8,15),(9,25),(16,41),(17,60),(64,521)]
  val _=T.check("game-mandelbrot/perturbation-rejected",fn()=>rejects(fn()=>ignore(P.run 17 "perturbed.pbm")))
  val _=T.check("game-mandelbrot/truncation-rejected",fn()=>rejects(fn()=>ignore(P.run 17 "truncated.pbm")))
  val _=T.check("game-mandelbrot/extra-output-rejected",fn()=>rejects(fn()=>ignore(P.run 17 "extra.pbm")))
end
