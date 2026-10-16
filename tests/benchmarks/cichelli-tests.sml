structure CichelliNeed = BenchCichelliFn (struct structure Eval=BenchNeed val strictCandidates=false end)
structure CichelliStrict = BenchCichelliFn (struct structure Eval=BenchStrict val strictCandidates=true end)
structure CichelliTests =
struct
  structure N = CichelliNeed
  structure R = CichelliStrict
  structure S = BenchStream
  structure L = BenchLazy
  fun read path = let val input=TextIO.openIn path val text=TextIO.inputAll input
                      val _=TextIO.closeIn input in text end
  fun output render status = let val chunks=ref []
    val _=render (fn text => chunks:=text:: !chunks) status
    in String.concat (List.rev (!chunks)) end
  val _=List.app (fn n =>
    (T.check ("cichelli/lazy-prefix-" ^ Int.toString n, fn () =>
       output N.emitFeedback (N.solve (N.attribute (List.take (BenchCichelliData.keys,n))))=read ("prefix-"^Int.toString n^".feedback"));
     T.check ("cichelli/strict-prefix-" ^ Int.toString n, fn () =>
       output R.emitFeedback (R.solve (R.attribute (List.take (BenchCichelliData.keys,n))))=read ("prefix-"^Int.toString n^".feedback")))) CichelliPrefixes.values
  val _=List.app (fn (n,name) =>
    (T.check ("cichelli/lazy-"^name, fn () => output N.emitFeedback (N.cichelli n)=read (name^".feedback"));
     T.check ("cichelli/strict-"^name, fn () => output R.emitFeedback (R.cichelli n)=read (name^".feedback")))) [(1,"odd"),(2,"even")]
  fun join []="" | join [x]=x | join (x::xs)=x^" "^join xs
  val _=T.check ("cichelli/original-frequency-order", fn () =>
    join (List.map (fn(c,n)=>String.str c^":"^Int.toString n) N.frequency)=read "frequency.feedback")
  val _=T.check ("cichelli/original-blocked-key-order", fn () =>
    join (List.map (fn N.K(word,_,_,_)=>word) (N.blocked N.attributed))=read "key-order.feedback")
  val _=T.check ("cichelli/union-tests-original-left-list", fn () => N.union [] [#"a",#"a"]=[#"a",#"a"])
  val _=T.check ("cichelli/histogram-right-fold-order", fn () =>
    List.foldr (fn(x,xs)=>N.histInsert x xs) [] [#"a",#"b",#"a"]=[(#"a",2),(#"b",1)])
  val _=T.check ("cichelli/duplicate-hash-rejected", fn () =>
    not (Option.isSome (N.insert 4 (N.H(SOME 4,SOME 4,[4])))))
  val _=T.check ("cichelli/range-width-rejected", fn () =>
    not (Option.isSome (N.insert 22 (N.H(SOME 0,SOME 0,[0])))))
  val _=T.check ("cichelli/gaps-allowed-within-range", fn () =>
    Option.isSome (N.insert 21 (N.H(SOME 0,SOME 0,[0]))))
  val _=T.check ("cichelli/lazy-first-success-short-circuits", fn () =>
    let fun attempt 0=N.YesIts(BenchNeed.delay(fn()=>1),[])
          | attempt _=raise Fail "unused candidate"
    in case N.firstSuccess attempt (S.fromList [0,1]) of N.YesIts(n,_)=>BenchNeed.force n=1|_=>false end)
  val _=T.check ("cichelli/strict-first-success-short-circuits", fn () =>
    let fun attempt 0=R.YesIts(1,[])|attempt _=raise Fail "unused candidate"
    in case R.firstSuccess attempt (S.fromList [0,1]) of R.YesIts(n,_)=>n=1|_=>false end)
  val _=T.check ("cichelli/status-does-not-force-count", fn () =>
    let fun attempt 0=N.NotEver(BenchNeed.delay(fn()=>raise Fail "unused count"))
          | attempt _=N.YesIts(BenchNeed.delay(fn()=>1),[])
    in case N.firstSuccess attempt (S.fromList [0,1]) of N.YesIts _=>true|_=>false end)
  val _=T.check ("cichelli/count-sharing", fn () =>
    let val calls=ref 0
        val leaf=BenchNeed.delay(fn()=>(calls:= !calls+1;3))
        val result=N.firstSuccess (fn _=>N.YesIts(leaf,[])) (S.fromList [0])
    in case result of N.YesIts(n,_)=>BenchNeed.force n=3 andalso BenchNeed.force n=3 andalso !calls=1|_=>false end)
  val _=T.check ("cichelli/lazy-empty-candidates", fn () =>
    case N.firstSuccess (fn _=>raise Fail "no candidate") (S.empty()) of N.NotEver n=>BenchNeed.force n=0|_=>false)
  val _=T.check ("cichelli/strict-empty-candidates", fn () =>
    case R.firstSuccess (fn _=>raise Fail "no candidate") (S.empty()) of R.NotEver n=>n=0|_=>false)
  fun unique xs=case xs of []=>true|x::rest=>not(List.exists(fn y=>x=y)rest) andalso unique rest
  val _=T.check ("cichelli/lazy-full-perfect-hash-witness", fn () =>
    case N.cichelli 2 of N.YesIts(_,assignments)=>
      let val values=List.map (N.hash assignments) N.attributed
      in unique values andalso List.foldl Int.min 100 values=4 andalso List.foldl Int.max 0 values=25 end|_=>false)
  val _=T.check ("cichelli/strict-full-perfect-hash-witness", fn () =>
    case R.cichelli 2 of R.YesIts(_,assignments)=>
      let val values=List.map (R.hash assignments) R.attributed
      in unique values andalso List.foldl Int.min 100 values=4 andalso List.foldl Int.max 0 values=25 end|_=>false)
  fun rejects path =
    let val input=BinIO.openIn path
        fun emit text=List.app (fn c=>case BinIO.input1 input of SOME value=>
          if Word8.toInt value=Char.ord c then()else raise Fail "incorrect result: changed byte"
          |NONE=>raise Fail "incorrect result: extra text") (String.explode text)
        val result=(N.emitFeedback emit (N.cichelli 2);
          if Option.isSome(BinIO.input1 input)then raise Fail "incorrect result: short text"else false)
          handle Fail text=>String.isPrefix "incorrect result:" text
        val _=BinIO.closeIn input
    in result end
  val _=T.check("cichelli/wrong-output-rejected",fn()=>rejects "wrong.feedback")
  val _=T.check("cichelli/truncated-output-rejected",fn()=>rejects "truncated.feedback")
  val _=T.check("cichelli/extra-output-rejected",fn()=>rejects "extra.feedback")
end
