structure StrictPic=BenchPicFn(BenchStrict)
structure StrictProbe=struct
structure K=StrictPic
structure D=BenchStrict

  fun read path=let val input=TextIO.openIn path val data=TextIO.inputAll input
    val _=TextIO.closeIn input in String.tokens(fn c=>c= #"\n")data end
  fun numbers line=List.map(fn s=>valOf(Real.fromString s))(tl(String.tokens Char.isSpace line))
  fun expected rows=case rows of []=>[]
    |step::dt::phi::positions::velocities::rest=>(numbers dt@numbers phi@numbers positions@numbers velocities)::expected rest
    |_=>raise Fail "invalid PIC trace"
  fun points xs=case D.force xs of K.Nil=>[]
    |K.Cons(p,rest)=>let val K.Point(x,y)=D.force p in D.force x::D.force y::points rest end
  fun values(K.State(dt,phi,heap))=
    let val K.Mesh(n,cells)=D.force phi
        val(pos,vel)=D.force heap
    in D.force dt::(List.tabulate(n*n,fn i=>D.force(Array.sub(cells,i)))@points pos@points vel)end
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~10,1.0E~10)
  fun check count=
    let val rows=read(Int.toString count^".trace")
        val wanted=hd(expected(List.drop(rows,2)))
        val actual=values(K.runState count 0)
        fun loop(_,[],[])=()
          |loop(i,a::xs,b::ys)=
            (if close(a,b)then()else print("DETAIL "^Int.toString i^" actual="^Real.toString a^" expected="^Real.toString b^"\n");loop(i+1,xs,ys))
          |loop _=raise Fail "length differs"
    in loop(0,actual,wanted)end
  val _=List.app check[1]
end
