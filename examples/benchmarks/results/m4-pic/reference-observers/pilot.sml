structure NeedPic=BenchPicFn(BenchNeed)
structure NeedProbe=struct
structure K=NeedPic
structure D=BenchNeed

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
    let val rows=read("tests/out/benchmarks/pic-originals/"^Int.toString count^".trace")
        val samples=expected(List.drop(rows,2))
        fun loop(_,[])=()
          |loop(k,wanted::rest)=
            let val actual=values(K.runState count k)
                val _=if ListPair.allEq close(actual,wanted)then()
                  else raise Fail("PIC mismatch at "^Int.toString count^" step "^Int.toString k)
            in loop(k+1,rest)end
        val _=loop(0,samples)
        val wanted=hd(numbers(hd rows))
        val actual=K.run count
    in if close(actual,wanted)then print("PIC "^Int.toString count^" "^Real.toString actual^" OK\n")
       else raise Fail "PIC scalar differs"end
  val _=List.app check[1,2,3,18,80,300]
end
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
    let val rows=read("tests/out/benchmarks/pic-originals/"^Int.toString count^".trace")
        val samples=expected(List.drop(rows,2))
        fun loop(_,[])=()
          |loop(k,wanted::rest)=
            let val actual=values(K.runState count k)
                val _=if ListPair.allEq close(actual,wanted)then()
                  else raise Fail("PIC mismatch at "^Int.toString count^" step "^Int.toString k)
            in loop(k+1,rest)end
        val _=loop(0,samples)
        val wanted=hd(numbers(hd rows))
        val actual=K.run count
    in if close(actual,wanted)then print("PIC "^Int.toString count^" "^Real.toString actual^" OK\n")
       else raise Fail "PIC scalar differs"end
  val _=List.app check[1,2,3,18,80,300]
end
