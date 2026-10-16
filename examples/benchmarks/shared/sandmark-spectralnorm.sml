(* Sandmark spectralnorm2: preserve all forty matrix-vector passes. *)
structure BenchSpectralNorm =
struct
 fun for first last f=let fun loop i=if i>last then()else(f i;loop(i+1))in loop first end
 fun eval_A i j=1.0/Real.fromInt((i+j)*(i+j+1)div 2+i+1)
 fun timesA u v=
   let val last=Array.length v-1
   in for 0 last(fn i=>
     let val vi=ref 0.0
         val _=for 0 last(fn j=>vi:= !vi+eval_A i j*Array.sub(u,j))
     in Array.update(v,i,!vi)end)end
 fun timesAt u v=
   let val last=Array.length v-1
   in for 0 last(fn i=>
     let val vi=ref 0.0
         val _=for 0 last(fn j=>vi:= !vi+eval_A j i*Array.sub(u,j))
     in Array.update(v,i,!vi)end)end
 fun ata u v=
   let val w=Array.array(Array.length u,0.0)
   in timesA u w;timesAt w v end
 fun run n=
   let val u=Array.array(n,1.0)
       val v=Array.array(n,0.0)
       val _=for 0 9(fn _=>(ata u v;ata v u))
       val vv=ref 0.0
       val vBv=ref 0.0
       val _=for 0(n-1)(fn i=>(vv:= !vv+Array.sub(v,i)*Array.sub(v,i);
         vBv:= !vBv+Array.sub(u,i)*Array.sub(v,i)))
   in Math.sqrt(!vBv/ !vv)end
end
