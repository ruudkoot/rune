(* Sequential many-body variant; unlike the five-planet kernel, update each
   ordered i,j velocity pair independently. Shared record helpers retain the
   common source energy/momentum loops. *)
structure BenchManyBody =
struct
  structure N=BenchRecordNBody
  type body=N.body
  fun initial count =
    let val random=BenchOCamlRandom.default ()
    in Array.tabulate (count,fn _ =>
      let
        (* Observed OCaml 4.14.1 record evaluation order is right to left. *)
        val mass=BenchOCamlRandom.real random 10.0*N.solarMass
        val vz=BenchOCamlRandom.real random 5.0*N.daysPerYear
        val vy=BenchOCamlRandom.real random 4.0*N.daysPerYear
        val vx=BenchOCamlRandom.real random 5.0*N.daysPerYear
        val z=BenchOCamlRandom.real random 10.0
        val y=BenchOCamlRandom.real random 10.0
        val x=BenchOCamlRandom.real random 10.0
      in {x=ref x,y=ref y,z=ref z,vx=ref vx,vy=ref vy,vz=ref vz,mass=mass}:body end)
    end
  fun advance (bodies:body array) dt =
    (N.for 0 (Array.length bodies-1) (fn i =>
      let val b=Array.sub (bodies,i)
      in N.for 0 (Array.length bodies-1) (fn j =>
        let val other=Array.sub (bodies,j)
        in if i=j then () else
          let val dx= !(#x b)- !(#x other)
              val dy= !(#y b)- !(#y other)
              val dz= !(#z b)- !(#z other)
              val distance2=dx*dx+dy*dy+dz*dz
              val magnitude=dt/(distance2*Math.sqrt distance2)
          in #vx b:= !(#vx b)-dx* #mass other*magnitude;
             #vy b:= !(#vy b)-dy* #mass other*magnitude;
             #vz b:= !(#vz b)-dz* #mass other*magnitude end
        end)end);
     N.for 0 (Array.length bodies-1) (fn i =>
       let val b=Array.sub (bodies,i)
       in #x b:= !(#x b)+dt* !(#vx b);
          #y b:= !(#y b)+dt* !(#vy b);
          #z b:= !(#z b)+dt* !(#vz b)end))
  val offset=N.offset
  val energy=N.energy
  val state=N.state
  fun compute steps count =
    let val bodies=initial count val _=offset bodies val first=energy bodies
        val _=N.for 1 steps(fn _=>advance bodies 0.01)
    in first::energy bodies::state bodies end
end
