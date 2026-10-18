 type 'a pattern=tokenStream->('a*tokenStream)control
 fun pure value input=cOne(value,input)
 fun patMatch predicate convert input=L.delay(fn()=>case L.force input of CEmpty=>CEmpty
   |CNext(value,rest)=>let val token=L.force value
       in if predicate token then CNext(L.delay(fn()=>(D.delay(fn()=>D.force(convert token)),rest)),cEmpty())else CEmpty end)
 fun patAlt first last input=cAppend(cDefer(fn()=>first input))(cDefer(fn()=>last input))
 fun patFirst first last input=cTake 1(patAlt first last input)
 fun patSeq join first last input=
   cBind(fn(a,rest)=>cMap(fn(b,tail)=>(D.delay(fn()=>D.force(join a b)),tail))(last rest))(cDefer(fn()=>first input))
 fun patApp convert parser input=cMap(fn(value,rest)=>(D.delay(fn()=>D.force(convert value)),rest))(cDefer(fn()=>parser input))
 fun semanticCons first last=F.cons(D.delay(fn()=>first),last)
 fun patRepeat(parser:'a D.t pattern)=
   let val cache:('a D.t F.seq pattern)option ref=ref NONE
       fun loop input=(case !cache of SOME pattern=>pattern
          |NONE=>let val pattern=patFirst(patSeq semanticCons parser loop)(pure(empty()))
                 in cache:=SOME pattern;pattern end)input
   in loop end
 fun patPlus parser=patSeq semanticCons parser(patRepeat parser)
 fun patAlts []=(fn _=>cEmpty())
   |patAlts(first::rest)=patFirst first(patAlts rest)
 fun patSeqs []=pure(empty())
   |patSeqs(first::rest)=patSeq semanticCons first(patSeqs rest)
 fun literalToken token=case token of NUMB name=>lit name|NAME name=>lit name|SYMB name=>lit name
   |_=>raise Match
 fun variableToken token=case token of NAME name=>var name|SYMB name=>var name|_=>raise Match
 fun literal kind name=patMatch(fn token=>tokenCompare token(kind(text name))=0)literalToken
 val pClose:expr pattern=literal SYMB")"
 val pComma:expr pattern=literal SYMB","
 val pEq:expr pattern=literal SYMB"="
 val pCons:expr pattern=literal NAME"(:)"
 val pTail:expr pattern=literal NAME"tl"
 val pMap:expr pattern=literal NAME"map"
 val pMaps:expr pattern=literal NAME"maps"
 val pOpen:expr pattern=literal SYMB"("
 val pSemi:expr pattern=literal SYMB";"
 val pIdent:expr pattern=patMatch(fn NAME _=>true|_=>false)variableToken
 val pNumber:expr pattern=patMatch(fn NUMB _=>true|_=>false)literalToken
 fun item fields index=F.nth fields index
 fun fieldsCount size fields=if F.length fields=size then()else raise Match
 fun varName value=case D.force value of Var name=>name|_=>raise Match
 fun tupleValues value=case D.force value of Tuple values=>values|_=>raise Match
 val cacheProgram:program pattern option ref=ref NONE
 val cacheCaf:def pattern option ref=ref NONE
 val cacheDef:def pattern option ref=ref NONE
 val cacheExpr:expr pattern option ref=ref NONE
 val cacheSimpleList:expr pattern option ref=ref NONE
 val cacheIdentList:expr pattern option ref=ref NONE
 val cacheTail:expr pattern option ref=ref NONE
 val cacheCons:expr pattern option ref=ref NONE
 val cacheMap:expr pattern option ref=ref NONE
 val cacheMaps:expr pattern option ref=ref NONE
 val cacheAp:expr pattern option ref=ref NONE
 val cacheSimple:expr pattern option ref=ref NONE
 val cachePack:expr pattern option ref=ref NONE
 val cacheTuple:expr pattern option ref=ref NONE
 val cacheTupleComma:expr F.seq pattern option ref=ref NONE
 fun cached cache build input=(case !cache of SOME parser=>parser
   |NONE=>let val parser=build()in cache:=SOME parser;parser end)input
 fun pProgram input=cached cacheProgram(fn()=>patPlus(patAlts[pCaf,pDef]))input
 and pCaf input=cached cacheCaf(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 4 fields;
        Caf(one(varName(item fields 0)),item fields 2)))
   in patApp build(patSeqs[pIdent,pEq,pExpr,pSemi])end)input
 and pDef input=cached cacheDef(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 5 fields;
        Def(varName(item fields 0),
          choose(fn e=>case D.force e of Var name=>SOME name|_=>NONE)(tupleValues(item fields 1)),item fields 3,noWhere())))
   in patApp build(patSeqs[pIdent,pIdentList,pEq,pExpr,pSemi])end)input
 and pExpr input=cached cacheExpr(fn()=>patAlts[pTailExpr,pConsExpr,pMapExpr,pMapsExpr,pApExpr,pSimple])input
 and pSimpleList input=cached cacheSimpleList(fn()=>patApp tuple(patPlus pSimple))input
 and pIdentList input=cached cacheIdentList(fn()=>patApp tuple(patPlus pIdent))input
 and pTailExpr input=cached cacheTail(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 2 fields;Tail(fromInt 1,item fields 1)))
   in patApp build(patSeqs[pTail,pExpr])end)input
 and pConsExpr input=cached cacheCons(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 3 fields;Cons(fromInt 1,item fields 1,item fields 2)))
   in patApp build(patSeqs[pCons,pSimple,pExpr])end)input
 and pMapExpr input=cached cacheMap(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 3 fields;
        Map(fromInt 1,varName(item fields 1),tupleValues(item fields 2))))
   in patApp build(patSeqs[pMap,pIdent,pSimpleList])end)input
 and pMapsExpr input=cached cacheMaps(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 5 fields;
        Maps(fromInt 1,varName(item fields 1),varName(item fields 2),item fields 3,tupleValues(item fields 4))))
   in patApp build(patSeqs[pMaps,pIdent,pIdent,pSimple,pSimpleList])end)input
 and pApExpr input=cached cacheAp(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 2 fields;
        Ap(varName(item fields 0),tupleValues(item fields 1))))
   in patApp build(patSeqs[pIdent,pSimpleList])end)input
 and pSimple input=cached cacheSimple(fn()=>patAlts[pIdent,pNumber,pPack])input
 and pPack input=cached cachePack(fn()=>
    patApp(fn fields=>D.delay(fn()=>D.force(item fields 1)))(patSeqs[pOpen,patAlts[pTuple,pExpr],pClose]))input
 and pTuple input=cached cacheTuple(fn()=>
   patSeq(fn first=>fn last=>tuple(append first(one last)))pTupleComma pExpr)input
 and pTupleComma input=cached cacheTupleComma(fn()=>
    patPlus(patApp(fn fields=>D.delay(fn()=>(fieldsCount 2 fields;D.force(item fields 0))))(patSeqs[pExpr,pComma])))input
 fun parse tokens=D.delay(fn()=>let val(result,_)=cHead(pProgram tokens)in D.force result end)
