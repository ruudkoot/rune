
structure NeedKernel=BenchPrologFn(BenchNeed)
structure NeedDriver=BenchPrologDriverFn(NeedKernel)
structure NeedTests=struct
  structure K=NeedKernel
  structure D=BenchNeed
  structure S=BenchStream
  structure L=BenchLazy
  structure P=BenchPrologParse
  structure Driver=NeedDriver
  val base=""
  fun label s="prolog/Need/"^s
  fun read path=Driver.read(base^path)
  val db=K.setup(read"stdlib")
  fun text chars=String.implode(List.rev(S.foldl(fn(c,cs)=>c::cs)[]chars))
  fun check(engine,tree,profile,inputPath,referencePath)=
    T.check(label(engine^"-"^profile),fn()=>
      text(K.runText tree db(read inputPath))=read referencePath)
  val _=List.app(fn(engine,tree)=>List.app(fn(profile,input)=>
    check(engine,tree,profile,input,engine^"-"^profile^".text"))
    [("smoke","smoke.input"),("normal","normal.input"),("large","large.input")])
    [("stack",false),("pure",true)]
  val _=check("stack",false,"extra-empty-query","empty-query.input","empty-query-stack.text")
  val _=check("stack",false,"extra-parse-empty-name","parse-empty-name.input","parse-empty-name-stack.text")
  val _=check("stack",false,"extra-backspaces","backspaces.input","backspaces-stack.text")
  val _=check("stack",false,"extra-no-answer","no-answer.input","no-answer-stack.text")
  val _=check("stack",false,"extra-aliasing","aliasing.input","aliasing-stack.text")
  val _=check("stack",false,"extra-append-order","append-order.input","append-order-stack.text")
  val _=check("stack",false,"extra-cut-source","cut-source.input","cut-source-stack.text")
  val _=check("stack",false,"extra-unknown-and-blank","unknown-and-blank.input","unknown-and-blank-stack.text")
  val _=check("stack",false,"extra-arity","arity.input","arity-stack.text")
  val _=check("stack",false,"extra-numbered-variables","numbered-variables.input","numbered-variables-stack.text")
  val _=check("stack",false,"extra-quit-tail","quit-tail.input","quit-tail-stack.text")
  val _=check("pure",true,"extra-empty-query","empty-query.input","empty-query-pure.text")
  val _=check("pure",true,"extra-parse-empty-name","parse-empty-name.input","parse-empty-name-pure.text")
  val _=check("pure",true,"extra-backspaces","backspaces.input","backspaces-pure.text")
  val _=check("pure",true,"extra-no-answer","no-answer.input","no-answer-pure.text")
  val _=check("pure",true,"extra-aliasing","aliasing.input","aliasing-pure.text")
  val _=check("pure",true,"extra-append-order","append-order.input","append-order-pure.text")
  val _=check("pure",true,"extra-cut-source","cut-source.input","cut-source-pure.text")
  val _=check("pure",true,"extra-unknown-and-blank","unknown-and-blank.input","unknown-and-blank-pure.text")
  val _=check("pure",true,"extra-arity","arity.input","arity-pure.text")
  val _=check("pure",true,"extra-numbered-variables","numbered-variables.input","numbered-variables-pure.text")
  val _=check("pure",true,"extra-quit-tail","quit-tail.input","quit-tail-pure.text")
  val _=T.check(label"parser-keeps-ambiguous-successes",fn()=>
    S.foldl(fn(_,n)=>n+1)0(P.alternative(P.token "a")(P.token "a")(String.explode "ab"))=2)
  val _=T.check(label"parser-many-prefers-longest-then-backtracks",fn()=>
    List.rev(S.foldl(fn((chars,_),xs)=>String.implode chars::xs)[]
      (P.many(P.satisfy Char.isAlpha)(String.explode "ab")))=["ab","a",""])
  val _=T.check(label"parser-just-strips-spaces-only",fn()=>
    not(List.null(S.take 1(P.just(P.token "a")(String.explode "a "))))
    andalso List.null(S.take 1(P.just(P.token "a")(String.explode "a\n"))))
  val _=T.check(label"empty-database-show",fn()=>K.showDb K.emptyDb="-- Empty Database --\n")
  val _=T.check(label"library-has-eight-clauses",fn()=>
    List.length(K.readLibrary(read"stdlib"))=8)
  val x=K.variable(0,"X")
  val y=K.variable(0,"Y")
  val a=K.structureTerm "a"(S.empty())
  fun structureTerm name values=K.structureTerm name(S.fromList values)
  val _=T.check(label"self-unification",fn()=>
    K.equal(S.head(K.unify x x)(0,"X"),x))
  val _=T.check(label"occurs-check-rejects-cycle",fn()=>
    List.null(S.take 1(K.unify x(structureTerm "f"[x]))))
  val _=T.check(label"reverse-occurs-check-rejects-cycle",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x])x)))
  val _=T.check(label"arity-mismatch-rejected",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x])(structureTerm "f"[x,y]))))
  val _=T.check(label"atom-mismatch-rejected",fn()=>
    List.null(S.take 1(K.unify a(structureTerm "b"[]))))
  val _=T.check(label"unifier-composition-order",fn()=>
    let val first=K.bind(0,"X")y val second=K.bind(0,"Y")a
        val substitution=K.compose second first
    in K.equal(substitution(0,"X"),a)andalso K.equal(substitution(0,"Y"),a)end)
  val _=T.check(label"unification-applies-earlier-argument-substitution",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x,x])
      (structureTerm "f"[a,structureTerm "b"[]]))))
  val _=T.check(label"variables-are-first-occurrence-ordered",fn()=>
    S.take 10(K.varsIn(structureTerm "f"[y,x,y]))=[(0,"Y"),(0,"X")])
  val _=T.check(label"rename-resets-every-variable-level",fn()=>
    S.take 10(K.varsIn(K.rename 7(structureTerm "f"[x,K.variable(99,"Y")])))=[(7,"X"),(7,"Y")])
  val _=T.check(label"source-cut-discards-only-second-frame-alternatives",fn()=>
    case K.cut[(1,1,S.singleton 11),(2,2,S.singleton 22),(3,3,S.singleton 33)]of
      [(1,1,first),(2,2,middle),(3,3,last)]=>S.head first=11
        andalso List.null(S.take 1 middle)andalso S.head last=33
      |_=>false)
  val _=T.check(label"source-cut-one-frame-is-unchanged",fn()=>
    case K.cut[(1,1,S.singleton 11)]of[(1,1,options)]=>S.head options=11|_=>false)
  val _=T.check(label"backspaces-erase-prior-characters",fn()=>
    String.implode(K.noBackSpaces(String.explode "ab\bcd"))="acd")
  val _=T.check(label"delete-at-start-does-not-erase-later-characters",fn()=>
    String.implode(K.noBackSpaces[Char.chr 127,#"a"])="a")
  val _=T.check(label"line-out-retains-terminal-erase-sequence",fn()=>
    String.implode(K.lineOut(String.explode "ab\bcd"))="ab\b \bcd")
  val _=T.check(label"driver-rejects-perturbed-transcript",fn()=>
    ((Driver.consume(K.runText false db(read"smoke.input"))"wrong";false)handle Fail _=>true))
  val _=T.check(label"driver-rejects-truncated-transcript",fn()=>
    let val wanted=read"stack-smoke.text"
    in ((Driver.consume(K.runText false db(read"smoke.input"))
      (String.substring(wanted,0,String.size wanted-1));false)handle Fail _=>true)end)
  val _=T.check(label"driver-rejects-extra-transcript",fn()=>
    ((Driver.consume(K.runText false db(read"smoke.input"))(read"stack-smoke.text"^"x");false)handle Fail _=>true))
  val _=T.check(label"empty-input-fails-without-looping",fn()=>
    ((text(K.runText false db"");false)handle Empty=>true))
  val _=List.app(fn(value,wanted)=>T.check(label("hash-"^value),fn()=>
    Driver.reverseHash value=Word64.fromInt wanted))[("",0),("a",97),("abc",96354)]
end


structure StrictKernel=BenchPrologFn(BenchStrict)
structure StrictDriver=BenchPrologDriverFn(StrictKernel)
structure StrictTests=struct
  structure K=StrictKernel
  structure D=BenchStrict
  structure S=BenchStream
  structure L=BenchLazy
  structure P=BenchPrologParse
  structure Driver=StrictDriver
  val base=""
  fun label s="prolog/Strict/"^s
  fun read path=Driver.read(base^path)
  val db=K.setup(read"stdlib")
  fun text chars=String.implode(List.rev(S.foldl(fn(c,cs)=>c::cs)[]chars))
  fun check(engine,tree,profile,inputPath,referencePath)=
    T.check(label(engine^"-"^profile),fn()=>
      text(K.runText tree db(read inputPath))=read referencePath)
  val _=List.app(fn(engine,tree)=>List.app(fn(profile,input)=>
    check(engine,tree,profile,input,engine^"-"^profile^".text"))
    [("smoke","smoke.input"),("normal","normal.input"),("large","large.input")])
    [("stack",false),("pure",true)]
  val _=check("stack",false,"extra-empty-query","empty-query.input","empty-query-stack.text")
  val _=check("stack",false,"extra-parse-empty-name","parse-empty-name.input","parse-empty-name-stack.text")
  val _=check("stack",false,"extra-backspaces","backspaces.input","backspaces-stack.text")
  val _=check("stack",false,"extra-no-answer","no-answer.input","no-answer-stack.text")
  val _=check("stack",false,"extra-aliasing","aliasing.input","aliasing-stack.text")
  val _=check("stack",false,"extra-append-order","append-order.input","append-order-stack.text")
  val _=check("stack",false,"extra-cut-source","cut-source.input","cut-source-stack.text")
  val _=check("stack",false,"extra-unknown-and-blank","unknown-and-blank.input","unknown-and-blank-stack.text")
  val _=check("stack",false,"extra-arity","arity.input","arity-stack.text")
  val _=check("stack",false,"extra-numbered-variables","numbered-variables.input","numbered-variables-stack.text")
  val _=check("stack",false,"extra-quit-tail","quit-tail.input","quit-tail-stack.text")
  val _=check("pure",true,"extra-empty-query","empty-query.input","empty-query-pure.text")
  val _=check("pure",true,"extra-parse-empty-name","parse-empty-name.input","parse-empty-name-pure.text")
  val _=check("pure",true,"extra-backspaces","backspaces.input","backspaces-pure.text")
  val _=check("pure",true,"extra-no-answer","no-answer.input","no-answer-pure.text")
  val _=check("pure",true,"extra-aliasing","aliasing.input","aliasing-pure.text")
  val _=check("pure",true,"extra-append-order","append-order.input","append-order-pure.text")
  val _=check("pure",true,"extra-cut-source","cut-source.input","cut-source-pure.text")
  val _=check("pure",true,"extra-unknown-and-blank","unknown-and-blank.input","unknown-and-blank-pure.text")
  val _=check("pure",true,"extra-arity","arity.input","arity-pure.text")
  val _=check("pure",true,"extra-numbered-variables","numbered-variables.input","numbered-variables-pure.text")
  val _=check("pure",true,"extra-quit-tail","quit-tail.input","quit-tail-pure.text")
  val _=T.check(label"parser-keeps-ambiguous-successes",fn()=>
    S.foldl(fn(_,n)=>n+1)0(P.alternative(P.token "a")(P.token "a")(String.explode "ab"))=2)
  val _=T.check(label"parser-many-prefers-longest-then-backtracks",fn()=>
    List.rev(S.foldl(fn((chars,_),xs)=>String.implode chars::xs)[]
      (P.many(P.satisfy Char.isAlpha)(String.explode "ab")))=["ab","a",""])
  val _=T.check(label"parser-just-strips-spaces-only",fn()=>
    not(List.null(S.take 1(P.just(P.token "a")(String.explode "a "))))
    andalso List.null(S.take 1(P.just(P.token "a")(String.explode "a\n"))))
  val _=T.check(label"empty-database-show",fn()=>K.showDb K.emptyDb="-- Empty Database --\n")
  val _=T.check(label"library-has-eight-clauses",fn()=>
    List.length(K.readLibrary(read"stdlib"))=8)
  val x=K.variable(0,"X")
  val y=K.variable(0,"Y")
  val a=K.structureTerm "a"(S.empty())
  fun structureTerm name values=K.structureTerm name(S.fromList values)
  val _=T.check(label"self-unification",fn()=>
    K.equal(S.head(K.unify x x)(0,"X"),x))
  val _=T.check(label"occurs-check-rejects-cycle",fn()=>
    List.null(S.take 1(K.unify x(structureTerm "f"[x]))))
  val _=T.check(label"reverse-occurs-check-rejects-cycle",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x])x)))
  val _=T.check(label"arity-mismatch-rejected",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x])(structureTerm "f"[x,y]))))
  val _=T.check(label"atom-mismatch-rejected",fn()=>
    List.null(S.take 1(K.unify a(structureTerm "b"[]))))
  val _=T.check(label"unifier-composition-order",fn()=>
    let val first=K.bind(0,"X")y val second=K.bind(0,"Y")a
        val substitution=K.compose second first
    in K.equal(substitution(0,"X"),a)andalso K.equal(substitution(0,"Y"),a)end)
  val _=T.check(label"unification-applies-earlier-argument-substitution",fn()=>
    List.null(S.take 1(K.unify(structureTerm "f"[x,x])
      (structureTerm "f"[a,structureTerm "b"[]]))))
  val _=T.check(label"variables-are-first-occurrence-ordered",fn()=>
    S.take 10(K.varsIn(structureTerm "f"[y,x,y]))=[(0,"Y"),(0,"X")])
  val _=T.check(label"rename-resets-every-variable-level",fn()=>
    S.take 10(K.varsIn(K.rename 7(structureTerm "f"[x,K.variable(99,"Y")])))=[(7,"X"),(7,"Y")])
  val _=T.check(label"source-cut-discards-only-second-frame-alternatives",fn()=>
    case K.cut[(1,1,S.singleton 11),(2,2,S.singleton 22),(3,3,S.singleton 33)]of
      [(1,1,first),(2,2,middle),(3,3,last)]=>S.head first=11
        andalso List.null(S.take 1 middle)andalso S.head last=33
      |_=>false)
  val _=T.check(label"source-cut-one-frame-is-unchanged",fn()=>
    case K.cut[(1,1,S.singleton 11)]of[(1,1,options)]=>S.head options=11|_=>false)
  val _=T.check(label"backspaces-erase-prior-characters",fn()=>
    String.implode(K.noBackSpaces(String.explode "ab\bcd"))="acd")
  val _=T.check(label"delete-at-start-does-not-erase-later-characters",fn()=>
    String.implode(K.noBackSpaces[Char.chr 127,#"a"])="a")
  val _=T.check(label"line-out-retains-terminal-erase-sequence",fn()=>
    String.implode(K.lineOut(String.explode "ab\bcd"))="ab\b \bcd")
  val _=T.check(label"driver-rejects-perturbed-transcript",fn()=>
    ((Driver.consume(K.runText false db(read"smoke.input"))"wrong";false)handle Fail _=>true))
  val _=T.check(label"driver-rejects-truncated-transcript",fn()=>
    let val wanted=read"stack-smoke.text"
    in ((Driver.consume(K.runText false db(read"smoke.input"))
      (String.substring(wanted,0,String.size wanted-1));false)handle Fail _=>true)end)
  val _=T.check(label"driver-rejects-extra-transcript",fn()=>
    ((Driver.consume(K.runText false db(read"smoke.input"))(read"stack-smoke.text"^"x");false)handle Fail _=>true))
  val _=T.check(label"empty-input-fails-without-looping",fn()=>
    ((text(K.runText false db"");false)handle Empty=>true))
  val _=List.app(fn(value,wanted)=>T.check(label("hash-"^value),fn()=>
    Driver.reverseHash value=Word64.fromInt wanted))[("",0),("a",97),("abc",96354)]
end

structure PrologDemand=struct
  structure K=NeedKernel
  structure Q=StrictKernel
  structure S=BenchStream
  val _=T.check("prolog/lazy-structure-skips-unused-child",fn()=>
    let val calls=ref 0
        val children=S.map(fn()=>(calls:= !calls+1;K.variable(0,"X")))(S.singleton())
        val term=K.structureTerm "f" children
        val _=BenchNeed.force term
    in !calls=0 end)
  val _=T.check("prolog/strict-structure-forces-finite-children",fn()=>
    let val calls=ref 0
        val children=S.map(fn()=>(calls:= !calls+1;Q.variable(0,"X")))(S.singleton())
        val term=Q.structureTerm "f" children
        val _=BenchStrict.force term
    in !calls=1 end)
  val _=T.check("prolog/lazy-composed-substitution-delays-and-shares-result",fn()=>
    let val calls=ref 0
        fun observed id=(calls:= !calls+1;K.variable id)
        val term=K.compose K.nullSubst observed(0,"X")
        val delayed= !calls=0
        val _=BenchNeed.force term val _=BenchNeed.force term
    in delayed andalso !calls=1 end)
end
