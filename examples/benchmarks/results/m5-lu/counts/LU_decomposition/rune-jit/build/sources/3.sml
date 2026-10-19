(* Sandmark's flat row-major, unpivoted LU elimination. *)
structure BenchSandmarkLU =
struct
 fun for first last f=let fun loop i=if i>last then()else(f i;loop(i+1))in loop first end
 fun get n a row col=Array.sub(a,row*n+col)
 fun set n a row col value=Array.update(a,row*n+col,value)
 fun create n f=Array.tabulate(n*n,fn i=>f(i div n)(i mod n))
 fun lup n a0=
   let val a=Array.tabulate(Array.length a0,fn i=>Array.sub(a0,i))
       val _=for 0(n-2)(fn k=>for(k+1)(n-1)(fn row=>
         let val factor=get n a row k / get n a k k
             val _=for(k+1)(n-1)(fn col=>set n a row col(get n a row col-factor*get n a k col))
         in set n a row k factor end))
   in a end
 fun split n lu=
   let val lower=create n(fn i=>fn j=>if i>j then get n lu i j else if i=j then 1.0 else 0.0)
       val upper=create n(fn i=>fn j=>if i<=j then get n lu i j else 0.0)
   in(lower,upper)end
end
