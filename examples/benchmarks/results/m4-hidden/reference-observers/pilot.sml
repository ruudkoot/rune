structure NeedHidden=BenchHiddenFn(BenchNeed)
structure NeedParse=BenchHiddenParseFn(NeedHidden)
structure NeedProbe=struct
structure K=NeedHidden
structure Parser=NeedParse
structure D=BenchNeed

  structure S=BenchStream
  fun read path=let val f=TextIO.openIn path val value=TextIO.inputAll f val _=TextIO.closeIn f in value end
  fun words text=List.map(fn s=>Word32.fromLargeInt(valOf(IntInf.fromString s)))
    (String.tokens Char.isSpace text)
  fun point value=List.map(fn n=>K.N.bits(D.force n))[K.x value,K.y value,K.z value]
  fun row edge=point(K.support edge)@point(K.terminal edge)
  fun check(profile,file)=
    let val scene=Parser.scene(read("tests/out/benchmarks/hidden-originals/source/runtime_files/"^file))
        val result=K.prepare(K.vec(List.map K.N.literal[2.0,10.0,3.0]))scene
        val expected=List.map words(String.tokens(fn c=>c= #"\n")(read("tests/out/benchmarks/hidden-originals/"^profile^".edges")))
        fun loop(values,[])=(case BenchLazy.force values of S.Nil=>()|_=>raise Fail "extra hidden edge")
          |loop(values,wanted::rest)=case BenchLazy.force values of S.Nil=>raise Fail "missing hidden edge"
            |S.Cons(value,tail)=>
              if row(BenchLazy.force value)=wanted then loop(tail,rest)
              else raise Fail "incorrect hidden edge coordinate bits"
        val _=loop(result,expected)
    in print("Hidden "^profile^" "^Int.toString(List.length expected)^" OK\n")end
  val _=check("smoke","houses.plate")
end
structure StrictHidden=BenchHiddenFn(BenchStrict)
structure StrictParse=BenchHiddenParseFn(StrictHidden)
structure StrictProbe=struct
structure K=StrictHidden
structure Parser=StrictParse
structure D=BenchStrict

  structure S=BenchStream
  fun read path=let val f=TextIO.openIn path val value=TextIO.inputAll f val _=TextIO.closeIn f in value end
  fun words text=List.map(fn s=>Word32.fromLargeInt(valOf(IntInf.fromString s)))
    (String.tokens Char.isSpace text)
  fun point value=List.map(fn n=>K.N.bits(D.force n))[K.x value,K.y value,K.z value]
  fun row edge=point(K.support edge)@point(K.terminal edge)
  fun check(profile,file)=
    let val scene=Parser.scene(read("tests/out/benchmarks/hidden-originals/source/runtime_files/"^file))
        val result=K.prepare(K.vec(List.map K.N.literal[2.0,10.0,3.0]))scene
        val expected=List.map words(String.tokens(fn c=>c= #"\n")(read("tests/out/benchmarks/hidden-originals/"^profile^".edges")))
        fun loop(values,[])=(case BenchLazy.force values of S.Nil=>()|_=>raise Fail "extra hidden edge")
          |loop(values,wanted::rest)=case BenchLazy.force values of S.Nil=>raise Fail "missing hidden edge"
            |S.Cons(value,tail)=>
              if row(BenchLazy.force value)=wanted then loop(tail,rest)
              else raise Fail "incorrect hidden edge coordinate bits"
        val _=loop(result,expected)
    in print("Hidden "^profile^" "^Int.toString(List.length expected)^" OK\n")end
  val _=check("smoke","houses.plate")
end
