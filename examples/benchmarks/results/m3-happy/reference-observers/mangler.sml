 val errorText=X.text"error"
 val dummyText=X.text"%dummy"
 val eofText=X.text"%eof"
 val startPrefix=X.text"%start_"
 val defaultParser=X.text"happyParse"
 val noCode=X.text"no code"
 val defaultStart=singleton(D.delay(fn()=>TokenName(defaultParser,D.delay(fn()=>NONE),D.delay(fn()=>false))))
 fun checkRules names above found=
   case D.force names of F.Nil=>Succeeded(L.delay(fn()=>reverse found))
    |F.Cons(value,rest)=>
      let val name=D.force value
      in if sameText name above then checkRules rest name found
         else if memberText name found then reject("Multiple rules for "^String.str(Char.chr 96)^X.string name^"'")
         else checkRules rest name(F.cons(value,found))end
 fun zipNames low values=
   F.defer(fn()=>case D.force values of F.Nil=>F.empty()
    |F.Cons(value,rest)=>F.cons(D.delay(fn()=>(D.delay(fn()=>low),D.force value)),zipNames(low+1)rest))
 fun codeWithAttributes arity lhs nonterms code attrs=
   case D.force attrs of F.Nil=>doCheckCode arity code
    |_=>rewriteAttributeGrammar arity lhs nonterms code attrs
 fun mangler file ast=
   let val AbsSyn(_,dirs,rules,_)=D.force ast
       fun prefix text=F.append(X.text(file^": "))text
       fun linePrefix line text=F.append(X.text(Int.toString(D.force line)^": "))text
       val names=F.map(fn(name,_,_)=>name)rules
       fun main nontermsRoot=
         let val nontermStrings=F.defer(fn()=>L.force nontermsRoot)
             val terminalStrings=F.append(flatMap(fn TokenSpec specs=>F.map(fn(name,_)=>name)specs
                                                   |_=>F.empty())dirs)(singleton(D.delay(fn()=>eofText)))
             val givenStarts=getParserNames dirs
             val startDirs=case D.force givenStarts of F.Nil=>defaultStart|_=>givenStarts
             val nStarts=length startDirs val nNonterms=length nontermStrings
             val nTerms=length terminalStrings
             val firstNt=3+nStarts val firstT=firstNt+nNonterms val lastT=firstT+nTerms-1
             val startNames=range 3(firstNt-1)
             val nontermNames=range firstNt(firstT-1)
             val terminalNames=range firstT lastT
             val startStrings=F.map(fn TokenName(name,_,_)=>F.append startPrefix name|_=>internal())startDirs
             val nameEnv=F.append(F.fromList[(D.delay(fn()=>1),errorText),(D.delay(fn()=>2),dummyText)])
               (F.append(zipNames 3 startStrings)
                (F.append(zipNames firstNt nontermStrings)(zipNames firstT terminalStrings)))
             fun lookupName value=
               F.map(fn(id,_)=>D.force id)(F.filter(fn(_,name)=>sameText name value)nameEnv)
             fun mapToName value=
               case D.force(lookupName value)of F.Nil=>
                   reject("unknown identifier "^String.str(Char.chr 96)^X.string value^"'")
                |F.Cons(id,rest)=>(case D.force rest of F.Nil=>Succeeded(L.delay(fn()=>D.force id))
                    |_=>reject("multiple use of "^String.str(Char.chr 96)^X.string value^"'"))
             fun startToken dir=case dir of TokenName(_,name,_)=>
                   (case D.force name of NONE=>succeeded firstNt|SOME value=>mapToName value)
                |_=>internal()
             fun afterStarts startTokensRoot=
               let val startTokens=F.defer(fn()=>L.force startTokensRoot)
                   val parserNames=F.map(fn TokenName(name,_,_)=>name|_=>internal())startDirs
                   val partials=F.map(fn TokenName(_,_,partial)=>D.force partial|_=>internal())startDirs
                   fun zip4 names ns tokens flags=F.defer(fn()=>
                     case(D.force names,D.force ns,D.force tokens,D.force flags)of
                       (F.Nil,F.Nil,F.Nil,F.Nil)=>F.empty()
                      |(F.Cons(a,aa),F.Cons(b,bb),F.Cons(c,cc),F.Cons(d,dd))=>
                          F.cons(D.delay(fn()=>(D.force a,b,c,d)),zip4 aa bb cc dd)
                      |_=>internal())
                   val startInfo=zip4 parserNames startNames startTokens partials
                   fun initialProds names tokens=F.defer(fn()=>
                     case(D.force names,D.force tokens)of(F.Nil,F.Nil)=>F.empty()
                      |(F.Cons(name,ns),F.Cons(token,ts))=>
                        F.cons(D.delay(fn()=>(name,singleton token,
                          D.delay(fn()=>(noCode,F.empty())),noPriority)),initialProds ns ts)
                      |_=>internal())
                   val startProds=initialProds startNames startTokens
                   val prioDirs=enumerate 1(getPrios dirs)
                   val prios=flatMap(fn(level,dir)=>flatMap(fn name=>
                       F.map(fn id=>(D.delay(fn()=>id),priorityOf(D.force level)(D.force dir)))(lookupName name))
                      (getPrioNames(D.force dir)))prioDirs
                   val prioStrings=flatMap(fn(level,dir)=>
                     F.map(fn name=>(name,priorityOf(D.force level)(D.force dir)))
                       (getPrioNames(D.force dir)))prioDirs
                   val attrs=getAttributes dirs
                   val attrType=case D.force(getAttributetype dirs)of NONE=>X.text"HappyAttrs"|SOME value=>value
                   fun convertNt(name,prods,ty)=thenE(mapToName name)(fn id=>
                      succeeded(D.delay(fn()=>L.force id),prods,ty))
                   fun mkPrec lhs prec=
                     case D.force prec of NONE=>
                       let val ts=F.filter(fn id=>memberInt id terminalNames)lhs
                           fun last values=case D.force values of F.Nil=>NONE
                             |F.Cons(value,rest)=>(case D.force rest of F.Nil=>SOME(D.force value)|_=>last rest)
                       in case last ts of NONE=>succeeded noPriority
                         |SOME name=>succeeded(case lookupInt name prios of NONE=>noPriority|SOME p=>p)end
                      |SOME name=>(case lookupText name prioStrings of NONE=>reject("Undeclared precedence token: "^X.string name)
                                  |SOME p=>succeeded p)
                   fun finishRule nt(lhs,code,line,prec)=
                     failMap(linePrefix line)
                       (parE(parEs(List.map mapToName(F.toList lhs)))(fn lhsRoot=>
                         let val numericLhs=F.defer(fn()=>L.force lhsRoot)
                         in thenE(codeWithAttributes(length lhs)numericLhs nontermNames code attrs)(fn codeRoot=>
                             thenE(mkPrec numericLhs prec)(fn p=>
                               succeeded(nt,numericLhs,D.delay(fn()=>L.force codeRoot),L.force p)))
                         end))
                   fun translateNt(nt,prods,_) =parEs(List.map(finishRule nt)(F.toList prods))
                   fun afterRules1 rules1Root=
                     let val rules1=F.defer(fn()=>L.force rules1Root)
                     in thenE(parEs(List.map translateNt(F.toList rules1)))(fn rules2Root=>
                       let val ruleGroups=F.defer(fn()=>L.force rules2Root)
                           val prods=F.append startProds(appendMany ruleGroups)
                           val prodArray=A.fromFinite(0,length prods-1)prods
                           val typed=flatMap(fn(nt,_,ty)=>
                              case D.force ty of NONE=>F.empty()
                               |SOME text=>singleton(D.delay(fn()=>(D.force nt,L.delay(fn()=>D.delay(fn()=>SOME text))))))rules1
                           val typeArray=A.accum(fn _=>fn value=>value)(L.delay(fn()=>D.delay(fn()=>NONE)))
                                  (firstNt,firstT-1)(fn()=>F.toList typed)
                           val envArray=A.array(1,lastT)(fn()=>List.map(fn(id,name)=>(D.force id,L.delay(fn()=>name)))(F.toList nameEnv))
                           fun fixSpec(name,code)=thenE(mapToName name)(fn id=>succeeded(D.delay(fn()=>L.force id),code))
                           fun finishSpecs tokenSpecsRoot=
                             let val specs=F.defer(fn()=>L.force tokenSpecsRoot)
                                 val pairs=F.map(fn(index,prod)=>
                                   let val(lhs,_,_,_)=D.force prod in(lhs,index)end)(enumerate 0 prods)
                                 val sorted=sortFinite(fn((a,_),(b,_))=>Int.compare(D.force a,D.force b))pairs
                                 fun combine values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
                                   |F.Cons(pair,rest)=>
                                     let val(key,value)=D.force pair
                                         fun gather collected rest=case D.force rest of
                                           F.Nil=>(collected,rest)
                                          |F.Cons(next,tail)=>let val(k,v)=D.force next
                                             in if D.force k=D.force key then gather(F.append collected(singleton v))tail
                                                else(collected,rest)end
                                         val(ids,tail)=gather(singleton value)rest
                                     in F.cons(D.delay(fn()=>(key,ids)),combine tail)end)
                                 val ass=combine sorted
                                 val lookupArray=A.array(3,length ass+2)(fn()=>List.map(fn(id,ids)=>
                                      (D.force id,L.delay(fn()=>ids)))(F.toList ass))
                                 fun lookupProds id=
                                   if id>=3 andalso id<firstT then A.sub lookupArray id else raise Fail"lookup_prods"
                             in succeeded(Grammar{
                               productions=prods,lookupProdNo=A.sub prodArray,lookupProdsOfName=lookupProds,
                               tokenSpecs=specs,terminals=F.cons(D.delay(fn()=>1),terminalNames),
                               nonterminals=F.append startNames nontermNames,starts=startInfo,
                               types=typeArray,tokenNames=envArray,firstNonterm=D.delay(fn()=>firstNt),
                               firstTerm=D.delay(fn()=>firstT),eof=D.delay(fn()=>lastT),priorities=prios,
                               tokenType=F.defer(fn()=>getTokenType dirs),importedIdentity=D.delay(fn()=>getImportedIdentity dirs),
                               monad=L.delay(fn()=>getMonad dirs),expect=getExpect dirs,attributes=attrs,
                               attributeType=attrType,lexer=getLexer dirs,errorHandler=getError dirs})end
                       in thenE(parEs(List.map fixSpec(F.toList(getTokenSpec dirs))))finishSpecs end)
                     end
               in thenE(parEs(List.map convertNt(F.toList rules)))afterRules1 end
         in thenE(parEs(List.map startToken(F.toList startDirs)))afterStarts end
   in failMap prefix(thenE(checkRules names emptyText(F.empty()))main)end
