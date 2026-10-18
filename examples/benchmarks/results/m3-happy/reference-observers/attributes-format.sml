 fun rewriteAttributeGrammar arity lhs nonterms code attrs=
   case AG.parse code 0 of
     X.Failed message=>Rejected(singleton(D.delay(fn()=>
       F.append(X.text"error in attribute grammar rules: ")message)))
    |X.Ok rules=>
      let fun tokens rule=case rule of AG.SelfAssign(_,ts)=>ts|AG.SubAssign(_,ts)=>ts
                  |AG.RightmostAssign(_,ts)=>ts|AG.Conditional ts=>ts
          val ruleList=F.toList rules
          fun mentioned []=[]
            |mentioned(rule::rest)=
              List.map(fn AG.SubRef(n,_)=>D.force n|_=>internal())
                (List.filter(fn AG.SubRef _=>true|_=>false)(F.toList(tokens rule)))
              @mentioned rest
          fun checkArity value=if value<=arity then succeeded value
                                  else reject(Int.toString value^" out of range")
          fun afterChecks checked=
            Succeeded(L.delay(fn()=>
              let fun partition self sub conditions []=(self,sub,conditions)
                    |partition self sub conditions(rule::rest)=
                       case rule of
                         AG.SelfAssign _=>partition(rule::self)sub conditions rest
                        |AG.SubAssign _=>partition self(rule::sub)conditions rest
                        |AG.RightmostAssign(attr,ts)=>partition self
                            (AG.SubAssign((D.delay(fn()=>arity),attr),ts)::sub)conditions rest
                        |AG.Conditional _=>partition self sub(rule::conditions)rest
                  val(selfRules,subRules,conditions)=partition[][][]ruleList
                  val attributeNames=F.map(fn(name,_)=>name)attrs
                  val defaultAttribute=F.defer(fn()=>F.nth attributeNames 0)
                  val allSubProductions=L.delay(fn()=>
                    let fun loop _ []=[]
                          |loop i(name::rest)=if memberInt name nonterms then i::loop(i+1)rest
                                             else loop(i+1)rest
                    in loop 1(F.toList lhs)end)
                  fun nub values=
                    let fun loop _ []=[]
                          |loop seen(x::xs)=if List.exists(fn y=>x=y)seen then loop seen xs
                                           else x::loop(x::seen)xs
                    in loop[]values end
                  fun render()=
                    let val prods=L.force allSubProductions
                        fun has i=List.exists(fn n=>n=i)prods
                        fun attrName name=
                          case D.force name of F.Nil=>X.string defaultAttribute|_=>X.string name
                        fun formatToken token=case token of
                           AG.LBrace=>"{ "|AG.RBrace=>"} "|AG.Where=>"where "
                          |AG.Semicolon=>"; "|AG.Eq=>"="
                          |AG.SelfRef attr=>"("^attrName attr^" happySelfAttrs) "
                          |AG.RightRef attr=>formatToken(AG.SubRef(D.delay(fn()=>arity),attr))
                          |AG.SubRef(index,attr)=>
                             let val i=D.force index
                             in if has i then"("^attrName attr^" happySubAttrs_"^Int.toString i^") "
                                else(case D.force attr of F.Nil=>happyVar i^" "|_=>raise Fail"lhs ")end
                          |AG.Unknown text=>X.string text^" "
                          |AG.EOF=>internal()
                        fun formatTokens ts=String.concat(List.map formatToken(F.toList ts))
                        fun self(AG.SelfAssign(attr,ts))=attrName attr^" = "^formatTokens ts
                          |self _=internal()
                        val selfText=case selfRules of []=>""
                             |_=>"{ "^String.concatWith", "(List.map self selfRules)^" }"
                        val subMap=L.delay(fn()=>
                          let fun pair(AG.SubAssign((n,a),ts))=(D.force n,(a,ts))|pair _=internal()
                              val sorted=naturalSortBy(fn((a,_),(b,_))=>Int.compare(a,b))(List.map pair subRules)
                              fun groups []=[]
                                |groups((key,first)::rest)=
                                  let fun gather xs((n,value)::rest)=
                                           if n=key then gather(value::xs)rest else(List.rev xs,(n,value)::rest)
                                        |gather xs []=(List.rev xs,[])
                                      val(tail,rest)=gather[]rest
                                  (* Original foldr's initial head rotates first to the end. *)
                                  in(key,tail@[first])::groups rest end
                          in groups sorted end)
                        fun updates i=
                          let fun find []=[]|find((key,values)::rest)=if key=i then values else find rest
                              val values=find(L.force subMap)
                              fun item(attr,ts)=attrName attr^" = "^formatTokens ts
                          in case values of []=>""|_=>"{ "^String.concatWith", "(List.map item values)^" }"end
                        fun sub i="; (happyConditions_"^Int.toString i^",happySubAttrs_"^Int.toString i^") = "^
                             happyVar i^" happyEmptyAttrs"^updates i
                        fun condition(AG.Conditional ts)=formatTokens ts|condition _=internal()
                        val localConditions="["^String.concatWith", "(List.map condition conditions)^"]"
                        val allConditions=String.concatWith"++"(localConditions::
                            List.map(fn i=>"happyConditions_"^Int.toString i)prods)
                    in "\\happyInhAttrs -> let { happySelfAttrs = happyInhAttrs"^selfText^
                       String.concat(List.map sub prods)^"; happyConditions = "^allConditions^
                       " } in (happyConditions,happySelfAttrs)"end
                  val body=F.defer(fn()=>X.text(render()))
                  val used=F.defer(fn()=>F.fromList(nub(L.force allSubProductions@F.toList(L.force checked))))
              in(body,used)end))
      in thenE(parEs(List.map checkArity(mentioned ruleList)))afterChecks end
