(* Ported from the pinned Sandmark/Benchmark Game source.
   Original attribution and BSD notices are retained in fannkuchredux/upstream. *)
(* Ribeca's sequential 32-chunk permutation code, with a checked terminal carry.
   Keep the original zero-first count convention and middle-only flip loop. *)
structure BenchFannkuchRedux =
struct
  val workers=32
  type permutation={p:int Array.array,pp:int Array.array,c:int Array.array}
  fun for lo hi f=
    let fun loop i=if i>hi then ()else(f i;loop(i+1))in loop lo end
  val facts=Array.array(21,IntInf.fromInt 1)
  val _=for 1 20(fn i=>Array.update(facts,i,IntInf.*(IntInf.fromInt i,Array.sub(facts,i-1))))
  fun fact n=IntInf.toInt(Array.sub(facts,n))
  fun setup n ordinal : permutation=
    let val index=ref ordinal
        val c=Array.array(n,1)
        val pp=Array.array(n,1)
        val p=Array.tabulate(n,fn i=>i)
        val result={p=p,pp=pp,c=c}
        fun position i=if i<0 then ()else
          let val f=fact i val d= !index div f
              val _=Array.update(c,i,d)
              val _=index:= !index mod f
              val _=for 0 i(fn j=>Array.update(pp,j,Array.sub(p,j)))
              val _=for 0 i(fn j=>Array.update(p,j,Array.sub(pp,if j+d<=i then j+d else j+d-i-1)))
          in position(i-1)end
        val _=position(n-1)
    in result end
  fun next({p,c,...}:permutation)=
    let val length=Array.length p
        val f=ref(Array.sub(p,1))
        val _=Array.update(p,1,Array.sub(p,0))
        val _=Array.update(p,0,!f)
        val i=ref 1
        val augmented=ref(Array.sub(c,!i)+1)
        val _=Array.update(c,!i,!augmented)
        fun carry()=if !augmented<= !i then ()else
          (Array.update(c,!i,0);i:= !i+1;
           let val first=Array.sub(p,1)
               val _=Array.update(p,0,first)
               val reduced= !i-1
               val _=for 1 reduced(fn j=>if length>j+1 then Array.update(p,j,Array.sub(p,j+1))else())
               val _=if length> !i then(Array.update(p,!i,!f);f:=first)else()
               (* The pinned -unsafe source reads/writes c[length] here.
                  Its last transition has no successor and is never consumed. *)
               val _=if !i<length then
                 (augmented:=Array.sub(c,!i)+1;Array.update(c,!i,!augmented))
                 else augmented:=0
           in carry()end)
    in carry()end
  fun count({p,pp,...}:permutation)=
    let val result=ref 1 val f=ref(Array.sub(p,0))
        val _=if Array.sub(p,!f)<>0 then
          let val _=for 0(Array.length p-1)(fn i=>Array.update(pp,i,Array.sub(p,i)))
              fun flips()=if Array.sub(pp,!f)=0 then ()else
                (result:= !result+1;
                 let val high=ref(!f-1) val low=ref 1
                     fun reverse()=if !low>= !high then ()else
                       let val old=Array.sub(pp,!low)
                       in Array.update(pp,!low,Array.sub(pp,!high));Array.update(pp,!high,old);
                          low:= !low+1;high:= !high-1;reverse()end
                     val _=reverse()
                     val previous= !f
                     val value=Array.sub(pp,previous)
                     val _=Array.update(pp,previous,previous)
                     val _=f:=value
                 in flips()end)
          in flips()end else()
    in !result end
  fun chunk n lo hi=
    let val maximum=ref 0 val checksum=ref 0 val permutation=setup n lo
        val _=for lo(hi-1)(fn i=>
          let val flips=count permutation
              val sign=1-2*Word.toInt(Word.andb(Word.fromInt i,0w1))
          in checksum:= !checksum+flips*sign;
             if flips> !maximum then maximum:=flips else();next permutation end)
    in(!checksum,!maximum)end
  fun run n emit=
    let val total=fact n val width=total div workers val remainder=total mod workers
        val results=ref(Array.tabulate(workers,fn _=>(0,0)))
        val _=for 0(workers-1)(fn i=>
          let val _=emit(Int.toString i)
              val lo=i*width+Int.min(i,remainder)
              val hi=lo+width+(if i<remainder then 1 else 0)
          in Array.update(!results,i,chunk n lo hi)end)
        val maximum=ref 0 val checksum=ref(IntInf.fromInt 0)
        val _=Array.app(fn(c,m)=>(checksum:=IntInf.+(!checksum,IntInf.fromInt c);
                                  maximum:=Int.max(!maximum,m)))(!results)
    in emit(IntInf.toString(!checksum)^"\nPfannkuchen("^Int.toString n^") = "^Int.toString(!maximum)^"\n")end
  fun checkOutput n expected=
    let val position=ref 0
        fun emit text=let val size=String.size text
          in if !position+size<=String.size expected andalso String.substring(expected,!position,size)=text
             then position:= !position+size else raise Fail "fannkuch output differs"end
        val _=run n emit
    in if !position=String.size expected then ()else raise Fail "fannkuch output incomplete"end
end
