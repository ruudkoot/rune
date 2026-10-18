 (* ProduceCode's TargetHaskell, coerce=False, ghc=False, strict=False
  * configuration selected by the pinned nofib Makefile. *)
 fun produceParser grammar action goto header trailer=F.defer(fn()=>
  let
   val ntTypes=types grammar
   val startsCount=L.delay(fn()=>length(starts grammar))
   val typeIndex=L.delay(fn()=>
     let val assocs=A.assocs ntTypes
         val named=F.defer(fn()=>F.map(fn(n,ty)=>case D.force ty of SOME t=>(t,n)|NONE=>internal())
                          (F.filter(fn(_,ty)=>Option.isSome(D.force ty))assocs))
         fun find text values=case D.force values of F.Nil=>raise Fail"cant find an item in list"
           |F.Cons(value,rest)=>let val(t,n)=D.force value
               in if sameText text t then n else find text rest end
     in A.array(A.bounds ntTypes)(fn()=>List.map(fn(n,ty)=>(n,L.delay(fn()=>
          case D.force ty of NONE=>n|SOME t=>find t named)))(F.toList assocs))end)
   fun absCon n=B.delayed(fn()=>B.pieces[B.literal"HappyAbsSyn",B.integer(A.sub(L.force typeIndex)n)])
   val monadInfo=L.delay(fn()=>monad grammar)
   fun usesMonad()=let val(b,_,_,_,_)=L.force monadInfo in b end
   fun context()=let val(_,a,_,_,_)=L.force monadInfo in a end
   fun tycon()=let val(_,_,a,_,_)=L.force monadInfo in a end
   fun bind()=let val(_,_,_,a,_)=L.force monadInfo in a end
   fun ret()=let val(_,_,_,_,a)=L.force monadInfo in a end
   fun fromOption value=case D.force value of NONE=>B.id|SOME t=>B.str t
   fun attrsEmpty()=case D.force(attributes grammar)of F.Nil=>true|_=>false
   val absSynDecl=B.delayed(fn()=>
     let val tyvars=F.map(fn(n,_)=>B.pieces[B.literal"t",B.integer n])
            (F.filter(fn(_,ty)=>not(Option.isSome(D.force ty)))(A.assocs ntTypes))
         val constructors=F.map(fn(n,ty)=>B.pieces[B.literal"\t| ",absCon n,B.literal" ",typeParam n ty])
            (F.filter(fn(n,_)=>A.sub(L.force typeIndex)n=n)(A.assocs ntTypes))
     in B.pieces[B.literal"data HappyAbsSyn ",
        B.delayed(fn()=>case D.force tyvars of F.Nil=>B.id|_=>B.interleave1" "tyvars),
        B.literal"\n\t= HappyTerminal ",B.str(tokenType grammar),B.literal"\n\t| HappyErrorToken Int\n",
        B.interleave"\n"constructors]end)
   val produceTypes=B.delayed(fn()=>
     if List.all(fn(_,ty)=>Option.isSome(D.force ty))(F.toList(A.assocs ntTypes))then
       let val token=B.bracket(B.str(tokenType grammar))
           val tokens=case lexer grammar of NONE=>B.pieces[B.literal"[",token,B.literal"] -> "]|SOME _=>B.id
           val result=B.literal"m HappyAbsSyn"
           val state=B.pieces[B.literal"HappyState ",token,B.literal" (HappyStk HappyAbsSyn -> ",tokens,result,B.literal")"]
           val actionNames=F.map(fn(i,_)=>mkActionName i)(A.assocs action)
           val reductionNames=F.map(fn(i,_)=>mkReduceFun(D.force i+L.force startsCount))(enumerate 0(F.drop(L.force startsCount)(productions grammar)))
           val typeSignature=B.pieces[B.literal" :: ",B.str(context()),B.literal" => Int -> HappyReduction (",B.str(tycon()),B.literal")\n\n"]
           val reductionSignature=B.pieces[B.literal" :: ",B.str(context()),B.literal" => HappyReduction (",B.str(tycon()),B.literal")\n\n"]
       in B.pieces[B.literal"type HappyReduction m = \n\t   Int \n\t-> ",token,B.literal"\n\t-> ",state,
          B.literal"\n\t-> [",state,B.literal"] \n\t-> HappyStk HappyAbsSyn \n\t-> ",tokens,result,B.literal"\n\n",
          B.interleave1",\n "actionNames,typeSignature,B.interleave1",\n "reductionNames,reductionSignature]end
     else B.id)
   fun stateFunction(state,acts)=B.delayed(fn()=>
     let val entries=A.assocs acts
         val default=L.delay(fn()=>getDefault entries)
         fun actionFunction t=B.pieces[mkActionName state,B.literal" (",B.integer t,B.literal") = "]
         fun one(t,a)=B.delayed(fn()=>case D.force a of LRFail=>B.id
           |LRReduce _=>if sameAction a(L.force default)then B.id
             else B.pieces[actionFunction t,mkAction a,B.literal"\n"]
           |_=>B.pieces[actionFunction t,mkAction a,B.literal"\n"])
         fun oneGoto(t,value)=B.delayed(fn()=>case D.force value of NoGoto=>B.id
           |Goto n=>B.pieces[actionFunction t,B.literal"happyGoto ",mkActionName(D.force n),B.literal"\n"])
     in B.pieces[B.many(F.map one entries),B.many(F.map oneGoto(A.assocs(A.sub goto state))),
          mkActionName state,B.literal" _ = ",B.delayed(fn()=>mkAction(L.force default)),B.literal"\n\n"]end)
   val produceActionTable=B.delayed(fn()=>B.many(F.map stateFunction(A.assocs action)))
   fun terminalVar n token=B.delayed(fn()=>
     case lookupInt token(tokenSpecs grammar)of NONE=>mkHappyVar n
       |SOME pattern=>(case mapDollarDollar pattern of NONE=>mkHappyVar n
          |SOME replace=>B.bracket(B.str(replace(B.output(mkHappyVar n))))))
   fun reduction(index,(nt,toks,codeCell,_))=B.delayed(fn()=>
     let val(code,used)=D.force codeCell
         val lt=length toks
         val(code',isMonad,passesToken,monadReduce)=
           case uncons code of SOME(#"%",rest)=>(case uncons rest of
              SOME(#"%",after)=>(after,true,true,"happyMonad2Reduce")
             |SOME(#"^",after)=>(after,true,true,"happyMonadReduce")
             |_ =>(rest,true,false,"happyMonadReduce"))
             |_ =>(code,false,false,"")
         val reductionFun=B.pieces[B.literal"happyReduction_",B.integer index]
         fun hdr size name=B.pieces[mkReduceFun index,B.literal" = ",B.literal name,B.literal" ",size,
             B.literal" ",B.integer(D.force nt),B.literal" ",reductionFun,B.literal"\n",reductionFun,B.literal" "]
         fun pattern(n,t)=B.delayed(fn()=>if not(memberInt n used)then B.literal"_"
            else if t>=3 andalso t<firstTerm grammar then
               B.bracket(B.pieces[absCon t,B.literal"  ",mkHappyVar n])
            else B.pieces[B.literal"(HappyTerminal ",terminalVar n t,B.literal")"])
         val patterns=reverse(F.map(fn(n,t)=>pattern(D.force n+1,D.force t))(enumerate 0 toks))
         val thisCon=absCon(D.force nt)
         val tick=String.str(Char.chr 96)
     in if isMonad andalso(usesMonad()orelse importedIdentity grammar)then
          B.pieces[hdr(B.integer lt)monadReduce,B.literal"(",B.interleave(" "^tick^"HappyStk"^tick^"\n\t")patterns,
            B.literal"happyRest) tk\n\t = happyThen (",B.bracket(B.str code'),
            if passesToken then B.literal" tk"else B.id,
            B.literal"\n\t) (\\r -> happyReturn (",thisCon,B.literal" r))"]
        else if lt<=3 then
          B.pieces[hdr B.id("happySpecReduce_"^Int.toString lt),B.interleave"\n\t"patterns,
            B.literal" =  ",thisCon,B.literal"\n\t\t (",B.str code',B.literal"\n\t)",
            if lt=0 orelse length used=0 then B.id else
             B.pieces[B.literal"\n",reductionFun,B.literal" ",
               B.interleave" "(F.map(fn _=>B.literal"_")(range 1 lt)),B.literal" = notHappyAtAll "]]
        else B.pieces[hdr(B.integer lt)"happyReduce",B.literal"(",
            B.interleave(" "^tick^"HappyStk"^tick^"\n\t")patterns,B.literal"happyRest)\n\t = ",
            thisCon,B.literal"\n\t\t (",B.str code',B.literal("\n\t) "^tick^"HappyStk"^tick^" happyRest")]
     end)
   val produceReductions=B.delayed(fn()=>B.interleave"\n\n"
      (F.map(fn(i,p)=>reduction(D.force i+L.force startsCount,D.force p))(enumerate 0(F.drop(L.force startsCount)(productions grammar)))))
   val produceTokenConverter=B.delayed(fn()=>
     let val eofTok=B.integer(eof grammar)
         fun eofAction tk=B.pieces[B.literal"action ",eofTok,B.literal" ",eofTok,B.literal(" "^tk^" (HappyState action) sts stk")]
         val doAction=B.literal"action i i tk (HappyState action)"
         fun doToken(i,pattern)=B.delayed(fn()=>
           let val p=case mapDollarDollar pattern of NONE=>pattern|SOME replace=>replace(X.text"happy_dollar_dollar")
           in B.pieces[B.str p,B.literal" -> cont ",B.integer(D.force i)]end)
         val tokens=B.interleave";\n\t"(F.map doToken(tokenSpecs grammar))
     in case lexer grammar of NONE=>B.pieces[
          B.literal"happyNewToken action sts stk [] =\n\t",eofAction"notHappyAtAll",B.literal" []\n\n",
          B.literal"happyNewToken action sts stk (tk:tks) =\n\tlet cont i = ",doAction,
          B.literal" sts stk tks in\n\tcase tk of {\n\t",tokens,
          B.literal"_ -> happyError' (tk:tks)\n\t}\n\nhappyError_ tk tks = happyError' (tk:tks)\n"]
       |SOME(lex,endToken)=>B.pieces[B.literal"happyNewToken action sts stk\n\t= ",B.str lex,
          B.literal"(\\tk -> \n\tlet cont i = ",doAction,B.literal" sts stk in\n\tcase tk of {\n\t",
          B.str endToken,B.literal" -> ",eofAction"tk",B.literal";\n\t",tokens,
          B.literal"_ -> happyError' tk\n\t})\n\nhappyError_ tk = happyError' tk\n"]end)
   val identityStuff=B.delayed(fn()=>if usesMonad()then B.id
     else if importedIdentity grammar then B.literal"type HappyIdentity = Identity\nhappyIdentity = Identity\nhappyRunIdentity = runIdentity\n\n"
     else B.literal"newtype HappyIdentity a = HappyIdentity a\nhappyIdentity = HappyIdentity\nhappyRunIdentity (HappyIdentity a) = a\n\ninstance Monad HappyIdentity where\n    return = HappyIdentity\n    (HappyIdentity p) >>= q = q p\n\n")
   val monadStuff=B.delayed(fn()=>
     let val ctx=B.str(context())val ty=B.str(tycon())
         val handler=case errorHandler grammar of SOME h=>B.str h
           |NONE=>(case lexer grammar of NONE=>B.literal"happyError"|SOME _=>B.literal"(\\token -> happyError)")
     in B.pieces[B.literal"happyThen :: ",ctx,B.literal" => ",ty,B.literal" a -> (a -> ",ty,B.literal" b) -> ",ty,
        B.literal" b\nhappyThen = ",B.bracket(B.str(bind())),B.literal"\nhappyReturn :: ",ctx,B.literal" => a -> ",ty,
        B.literal" a\nhappyReturn = ",B.bracket(B.str(ret())),B.literal"\n",
        case lexer grammar of NONE=>B.pieces[
          B.literal"happyThen1 m k tks = (",B.str(bind()),B.literal") m (\\a -> k a tks)\nhappyReturn1 :: ",ctx,
          B.literal" => a -> b -> ",ty,B.literal" a\nhappyReturn1 = \\a tks -> ",B.bracket(B.str(ret())),
          B.literal" a\nhappyError' :: ",ctx,B.literal" => [",B.str(tokenType grammar),B.literal"] -> ",ty,
          B.literal" a\nhappyError' = ",if usesMonad()then B.id else B.literal"HappyIdentity . ",handler,B.literal"\n\n"]
        |SOME _=>B.pieces[B.literal"happyThen1 = happyThen\nhappyReturn1 :: ",ctx,B.literal" => a -> ",ty,
          B.literal" a\nhappyReturn1 = happyReturn\nhappyError' :: ",ctx,B.literal" => ",B.str(tokenType grammar),
          B.literal" -> ",ty,B.literal" a\nhappyError' tk = ",if usesMonad()then B.id else B.literal"HappyIdentity ",
          handler,B.literal" tk\n\n"]]end)
   fun entry(no,(name,_,acceptNt,_))=B.delayed(fn()=>
     let val tks=case lexer grammar of NONE=>B.literal" tks"|SOME _=>B.id
     in B.pieces[if attrsEmpty()then B.str name else B.pieces[B.literal"do_",B.str name],tks,
        B.literal" = ",if usesMonad()then B.id else B.literal"happyRunIdentity ",
        B.literal"happySomeParser where\n  happySomeParser = happyThen (happyParse ",mkActionName no,tks,
        B.literal") ",B.bracket(B.pieces[B.literal"\\x -> case x of {HappyAbsSyn",
          B.integer(A.sub(L.force typeIndex)(D.force acceptNt)),B.literal" z -> happyReturn z; _other -> notHappyAtAll }"])]end)
   val attrEntries=B.delayed(fn()=>if attrsEmpty()then B.id else
     let val(default,_) =F.nth(attributes grammar)0
         fun one(name,_,_,_)=B.delayed(fn()=>
           if usesMonad()then B.pieces[B.str name,
             (case lexer grammar of NONE=>B.literal" toks = do { f <- do_"|SOME _=>B.literal" = do { f <- do_"),
             B.str name,(case lexer grammar of NONE=>B.literal" toks; "|SOME _=>B.literal"; "),
             B.literal"let { (conds,attrs) = f happyEmptyAttrs } in do { sequence_ conds; return (",
             B.str default,B.literal" attrs) }}"]
           else case lexer grammar of SOME _=>raise Fail"attribute grammars not supported for non-monadic parsers with %lexer"
             |NONE=>B.pieces[B.str name,B.literal" toks = let { f = do_",B.str name,
               B.literal" toks; (conds,attrs) = f happyEmptyAttrs; x = foldr seq attrs conds; } in (",B.str default,B.literal" x)"])
     in B.interleave"\n\n"(F.map one(starts grammar))end)
   val produceEntries=B.pieces[B.delayed(fn()=>B.interleave"\n\n"(F.map(fn(i,value)=>entry(D.force i,D.force value))(enumerate 0(starts grammar)))),attrEntries]
   val produceAttributes=B.delayed(fn()=>if attrsEmpty()then B.id else
     let val attrs=attributes grammar
         val attrType=case D.force(attributeType grammar)of F.Nil=>X.text"HappyAttributes"|_=>attributeType grammar
         fun field(name,ty)=B.pieces[B.str name,B.literal" :: ",B.str ty]
         fun bad(name,_)=B.pieces[B.str name,B.literal" = error \"invalid reference to attribute '",B.str name,B.literal"'\""]
     in B.pieces[B.literal"data ",B.str attrType,B.literal" = HappyAttributes {",B.interleave1", "(F.map field attrs),
          B.literal"}\nhappyEmptyAttrs = HappyAttributes {",B.interleave1", "(F.map bad attrs),B.literal"}\n"]end)
  in B.output(B.pieces[fromOption header,B.literal"\n-- parser produced by Happy Version 1.16\n\n",
      absSynDecl,B.literal"\n",produceTypes,produceActionTable,produceReductions,produceTokenConverter,B.literal"\n",
      identityStuff,monadStuff,produceEntries,B.literal"happySeq = happyDontSeq\n\n",produceAttributes,
      B.literal"\n",fromOption trailer,B.literal"\n"])
  end)
