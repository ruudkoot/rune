structure BenchRecordNBody =
struct
  type body={x:real ref,y:real ref,z:real ref,vx:real ref,vy:real ref,vz:real ref,mass:real}
  val pi=3.141592653589793
  val solarMass=4.0*pi*pi
  val daysPerYear=365.24
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun planet(x,y,z,vx,vy,vz,mass):body=
    {x=ref x,y=ref y,z=ref z,vx=ref(vx*daysPerYear),vy=ref(vy*daysPerYear),vz=ref(vz*daysPerYear),mass=mass*solarMass}
  fun initial()=Array.fromList[
    planet(0.0,0.0,0.0,0.0,0.0,0.0,1.0),
    planet(4.84143144246472090,~1.16032004402742839,~1.03622044471123109E~1,
      1.66007664274403694E~3,7.69901118419740425E~3,~6.90460016972063023E~5,9.54791938424326609E~4),
    planet(8.34336671824457987,4.12479856412430479,~4.03523417114321381E~1,
      ~2.76742510726862411E~3,4.99852801234917238E~3,2.30417297573763929E~5,2.85885980666130812E~4),
    planet(1.28943695621391310E1,~1.51111514016986312E1,~2.23307578892655734E~1,
      2.96460137564761618E~3,2.37847173959480950E~3,~2.96589568540237556E~5,4.36624404335156298E~5),
    planet(1.53796971148509165E1,~2.59193146099879641E1,1.79258772950371181E~1,
      2.68067772490389322E~3,1.62824170038242295E~3,~9.51592254519715870E~5,5.15138902046611451E~5)]
  fun advance(bodies:body array)dt=
    (for 0(Array.length bodies-1)(fn i=>
      let val b=Array.sub(bodies,i)
      in for(i+1)(Array.length bodies-1)(fn j=>
        let val other=Array.sub(bodies,j)
            val dx= !(#x b)- !(#x other)
            val dy= !(#y b)- !(#y other)
            val dz= !(#z b)- !(#z other)
            val dist2=dx*dx+dy*dy+dz*dz
            val mag=dt/(dist2*Math.sqrt dist2)
        in #vx b:= !(#vx b)-dx* #mass other*mag;
           #vy b:= !(#vy b)-dy* #mass other*mag;
           #vz b:= !(#vz b)-dz* #mass other*mag;
           #vx other:= !(#vx other)+dx* #mass b*mag;
           #vy other:= !(#vy other)+dy* #mass b*mag;
           #vz other:= !(#vz other)+dz* #mass b*mag end)end);
     for 0(Array.length bodies-1)(fn i=>let val b=Array.sub(bodies,i)
       in #x b:= !(#x b)+dt* !(#vx b);
          #y b:= !(#y b)+dt* !(#vy b);
          #z b:= !(#z b)+dt* !(#vz b)end))
  fun energy(bodies:body array)=
    let val total=ref 0.0
        val _=for 0(Array.length bodies-1)(fn i=>
          let val b=Array.sub(bodies,i)
              val _=total:= !total+0.5* #mass b*
                (!(#vx b)* !(#vx b)+ !(#vy b)* !(#vy b)+ !(#vz b)* !(#vz b))
          in for(i+1)(Array.length bodies-1)(fn j=>
            let val other=Array.sub(bodies,j)
                val dx= !(#x b)- !(#x other)
                val dy= !(#y b)- !(#y other)
                val dz= !(#z b)- !(#z other)
                val distance=Math.sqrt(dx*dx+dy*dy+dz*dz)
            in total:= !total-(#mass b* #mass other)/distance end)end)
    in !total end
  fun offset(bodies:body array)=
    let val px=ref 0.0 val py=ref 0.0 val pz=ref 0.0
        val _=for 0(Array.length bodies-1)(fn i=>let val b=Array.sub(bodies,i)
          in px:= !px+ !(#vx b)* #mass b;py:= !py+ !(#vy b)* #mass b;pz:= !pz+ !(#vz b)* #mass b end)
        val sun=Array.sub(bodies,0)
    in #vx sun:= ~(!px)/solarMass;#vy sun:= ~(!py)/solarMass;#vz sun:= ~(!pz)/solarMass end
  fun state(bodies:body array)=List.concat(List.tabulate(Array.length bodies,fn i=>
    let val b=Array.sub(bodies,i)
    in[!(#x b),!(#y b),!(#z b),!(#vx b),!(#vy b),!(#vz b),#mass b]end))
end
