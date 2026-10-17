
structure KernelNeed=BenchGamtebFn(BenchNeed)
structure PilotNeed=struct
  structure K=KernelNeed
  structure D=BenchNeed
  structure S=BenchStream
  structure L=BenchLazy
  val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/gamteb-originals/"
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun real text=valOf(Real.fromString text)
  fun rows text=List.map(String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")text)
  fun check n=
    let val task=K.run n
        val wantedR=rows(read(base^Int.toString n^".results"))
        val wantedS=rows(read(base^Int.toString n^".stats"))
        fun close(a,b)=BenchInput.closeReal(a,b,1.0E~12,1.0E~12)
        fun results values expected=case(L.force values,expected)of
            (S.Nil,[])=>true
          |(S.Cons(head,tail),[kind,index,weight]::rest)=>
            let val((a,b),w)=L.force head
            in a=valOf(Int.fromString kind)andalso L.force b=valOf(Int.fromString index)
              andalso close(D.force w,real weight)andalso results tail rest end
          |_=>false
        fun stats values expected=case(L.force values,expected)of
            (S.Nil,[])=>true
          |(S.Cons(head,tail),[id,value]::rest)=>
            let val(i,v)=L.force head
            in i=valOf(Int.fromString id)andalso close(D.force v,real value)andalso stats tail rest end
          |_=>false
        val _=if results(K.first task)wantedR then()else raise Fail "incorrect GAMTEB result"
        val _=if stats(K.second task)wantedS then()else raise Fail "incorrect GAMTEB statistics"
    in print("Need "^Int.toString n^" "^Int.toString(List.length wantedR)^" "^Int.toString(List.length wantedS)^" OK\n")end
  val _=List.app check[1,2,3,10,100,1000,5000]
end

structure KernelStrict=BenchGamtebFn(BenchStrict)
structure PilotStrict=struct
  structure K=KernelStrict
  structure D=BenchStrict
  structure S=BenchStream
  structure L=BenchLazy
  val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/gamteb-originals/"
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun real text=valOf(Real.fromString text)
  fun rows text=List.map(String.tokens Char.isSpace)(String.tokens(fn c=>c= #"\n")text)
  fun check n=
    let val task=K.run n
        val wantedR=rows(read(base^Int.toString n^".results"))
        val wantedS=rows(read(base^Int.toString n^".stats"))
        fun close(a,b)=BenchInput.closeReal(a,b,1.0E~12,1.0E~12)
        fun results values expected=case(L.force values,expected)of
            (S.Nil,[])=>true
          |(S.Cons(head,tail),[kind,index,weight]::rest)=>
            let val((a,b),w)=L.force head
            in a=valOf(Int.fromString kind)andalso L.force b=valOf(Int.fromString index)
              andalso close(D.force w,real weight)andalso results tail rest end
          |_=>false
        fun stats values expected=case(L.force values,expected)of
            (S.Nil,[])=>true
          |(S.Cons(head,tail),[id,value]::rest)=>
            let val(i,v)=L.force head
            in i=valOf(Int.fromString id)andalso close(D.force v,real value)andalso stats tail rest end
          |_=>false
        val _=if results(K.first task)wantedR then()else raise Fail "incorrect GAMTEB result"
        val _=if stats(K.second task)wantedS then()else raise Fail "incorrect GAMTEB statistics"
    in print("Strict "^Int.toString n^" "^Int.toString(List.length wantedR)^" "^Int.toString(List.length wantedS)^" OK\n")end
  val _=List.app check[1,2,3,10,100,1000,5000]
end
