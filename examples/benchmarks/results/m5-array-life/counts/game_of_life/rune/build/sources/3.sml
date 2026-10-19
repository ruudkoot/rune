(* Sandmark's double-buffered, exception-bounded sequential Life. *)
structure BenchArrayLife =
struct
 fun for first last f=let fun loop i=if i>last then()else(f i;loop(i+1))in loop first end
 fun get board x y=(Array.sub(Array.sub(board,x),y)handle _=>0)
 fun neighbourhood board x y=
   get board(x-1)(y-1)+get board(x-1)y+get board(x-1)(y+1)+
   get board x(y-1)+get board x(y+1)+get board(x+1)(y-1)+get board(x+1)y+get board(x+1)(y+1)
 fun cell board x y=
   let val neighbours=neighbourhood board x y
   in case(Array.sub(Array.sub(board,x),y),neighbours)of
      (1,0)=>0 |(1,1)=>0 |(1,4)=>0 |(1,5)=>0 |(1,6)=>0 |(1,7)=>0 |(1,8)=>0
     |(1,2)=>1 |(1,3)=>1 |(0,3)=>1 |_=>0 end
 fun step board target=
   let val last=Array.length board-1
   in for 0 last(fn x=>for 0 last(fn y=>Array.update(Array.sub(target,x),y,cell board x y)))end
 fun runBuffers generations board=
   let val n=Array.length board
       val source=ref board
       val target=ref(Array.tabulate(n,fn _=>Array.array(n,0)))
       fun loop 0=(!source,!target)
         | loop count=let val old= !source
                         val fresh= !target
                         val _=step old fresh
                         val _=source:=fresh
                         val _=target:=old
                     in loop(count-1)end
   in loop generations end
 fun run generations board= #1(runBuffers generations board)
 fun initial n=
   let val state=BenchOCamlRandom.default()
   in Array.tabulate(n,fn _=>Array.tabulate(n,fn _=>BenchOCamlRandom.integer state 2))end
end
