structure NeedCompr=BenchHartelComprFn(BenchNeed)
structure StrictCompr=BenchHartelComprFn(BenchStrict)
structure ComprTests =
struct
  structure N=NeedCompr
  structure R=StrictCompr
  structure L=BenchLazy
  structure S=BenchStream
  fun read path=let val input=TextIO.openIn path val text=TextIO.inputAll input val _=TextIO.closeIn input in text end
  fun matches source path=
    let val expected=read path val position=ref 0
        fun loop source=case L.force source of S.Nil=>()
          |S.Cons(value,rest)=>if !position<String.size expected andalso L.force value=String.sub(expected,!position)
             then(position:= !position+1;loop rest)else raise Fail "incorrect result: transformed byte differs"
        val _=loop source
    in if !position=String.size expected then true else raise Fail "incorrect result: short transformed text"end
  val _=List.app(fn n=>
    (T.check("compr/lazy-full-"^Int.toString n,fn()=>matches(N.output false n)(Int.toString n^".program"));
     T.check("copy/lazy-full-"^Int.toString n,fn()=>matches(N.output true n)(Int.toString n^".program"));
     T.check("compr/strict-full-"^Int.toString n,fn()=>matches(R.output false n)(Int.toString n^".program"));
     T.check("copy/strict-full-"^Int.toString n,fn()=>matches(R.output true n)(Int.toString n^".program"))))[0,1,2]
  val _=T.check("compr/input-program-rendering",fn()=>matches(N.showProgram N.program)"input.program")
  val _=T.check("compr/strict-input-program-rendering",fn()=>matches(R.showProgram R.program)"input.program")
  val _=T.check("compr/length-does-not-force-character",fn()=>
    N.length(S.cons(L.delay(fn()=>raise Fail "unused character"),S.empty()))=1)
  val _=T.check("copy/length-does-not-force-character",fn()=>
    N.length(N.copy(S.cons(L.delay(fn()=>raise Fail "unused character"),S.empty())))=1)
  val _=T.check("copy/reuses-character-cell",fn()=>
    let val value=L.delay(fn()=> #"x")val original=S.cons(value,S.empty())
    in case L.force(N.copy original)of S.Cons(c,_)=>c=value|_=>false end)
  val _=T.check("copy/allocates-fresh-spine",fn()=>
    let val original=S.fromList [#"x",#"y"] val copied=N.copy original
    in copied<>original andalso
      (case (L.force original,L.force copied)of
         (S.Cons(_,a),S.Cons(_,b))=>a<>b|_=>false)end)
  val _=T.check("compr/transforms-each-repetition",fn()=>
    let val translated=N.translated 2
    in N.nth translated 0<>N.nth translated(List.length N.Data.program)end)
  val _=T.check("compr/infix-ignores-extra-argument",fn()=>
    let val expr=N.app(N.text "+")(fn()=>[N.variable(N.text "x"),N.variable(N.text "y"),BenchNeed.delay(fn()=>raise Fail "unused argument")])
    in String.implode(S.take 5(N.showExpr expr))="(x+y)"end)
  val _=T.check("compr/empty-let-erased",fn()=>
    N.length(N.showExpr(N.letExpr(fn()=>[])(fn()=>N.constant(N.text "z"))))=1)
  val _=T.check("compr/strict-empty-let-erased",fn()=>
    R.length(R.showExpr(R.letExpr(fn()=>[])(fn()=>R.constant(R.text "z"))))=1)
  val _=T.check("compr/empty-qualifier-render-is-partial",fn()=>
    ((ignore(N.length(N.showExpr(BenchNeed.delay(fn()=>N.Cmp(N.variable(N.text "x"),N.empty()))))));false)handle Empty=>true)
  val _=List.app(fn n=>
    (T.check("compr/lazy-spine-length-"^Int.toString n,fn()=>N.length(N.output false n)=626*n);
     T.check("copy/lazy-spine-length-"^Int.toString n,fn()=>N.length(N.output true n)=626*n);
     T.check("compr/strict-spine-length-"^Int.toString n,fn()=>R.length(R.output false n)=626*n);
     T.check("copy/strict-spine-length-"^Int.toString n,fn()=>R.length(R.output true n)=626*n)))[0,1,2,5]
  val _=List.app(fn name=>T.check("compr/reject-"^name,fn()=>
    ((matches(N.output false 1)(name^".program");false)handle Fail message=>String.isPrefix "incorrect result:" message)))
    ["wrong","truncated","extra"]
end
