
 fun shortText count chars=F.defer(fn()=>case force chars of F.Nil=>F.empty()
   |F.Cons(c,rest)=>if equalInt count(int 0)then text"..."
      else if force c= #"\n"then F.cons(cell #" ",removeSpaces(subtract count(int 1))rest)
      else F.cons(c,shortText(subtract count(int 1))rest))
 and removeSpaces count chars=F.defer(fn()=>case force chars of F.Nil=>shortText count chars
   |F.Cons(c,rest)=>if force c= #" "orelse force c= #"\n"then removeSpaces count rest else shortText count chars)
 fun completionText value=F.defer(fn()=>case force value of NoValue=>F.empty()|SomeValue _=>text"Done")
 fun objectText signatureValue object=F.defer(fn()=>case force object of
    TermSpec term=>unparseITerm(internalSignature signatureValue)term
   |TheoremSpec term=>unparseITerm(internalSignature signatureValue)term
   |SignatureSpec sg=>unparseSignature sg|DeclarationSpec dec=>unparseDeclaration(internalSignature signatureValue)dec)
 fun goalSummary attrs tree=
   let val Tree(goal,_,done,_,_)=force tree
       val Goal(_,_,_,_,object,_,sg,_)=force goal
   in pair(completionText done)(shortText(int 50)(objectText sg object))end
 fun showOption function render option=case force option of NoValue=>function(text"None")|SomeValue value=>function(render value)
 fun showNode uid object=
   let val prefix=case force object of TermSpec _=>"Trm Node: "|TheoremSpec _=>"Thm Node: "|SignatureSpec _=>"Sgn Node: "|DeclarationSpec _=>"Dec Node: "
   in setNode(F.append(text prefix)uid)end
 fun showGoal global tree=
   let val Tree(goal,_,_,_,_)=force tree
       val Goal(tactic,args,comment,uid,object,editable,_,_)=force goal
       val summary=goalSummary(getGlobalAttributes global)tree
       val(done,value)=force summary
   in composeOutputs[showNode uid object,showOption setTactic(fn value=>value)tactic,
       showOption setArgument head args,showOption setComment(shortText(int 50))comment,
       setReadWrite(text(if force editable then"Editable"else"Read Only")),setGoal done value]end
 fun showSubgoals global children=setSubgoals(map(goalSummary(getGlobalAttributes global))children)
 fun showDone done=setDone(text(case force done of NoValue=>"Incomplete"|SomeValue _=>"Complete"))
 val objectTypes:textNode F.seq=F.fromList(List.map(fn s=>force(text s))["Thm","Trm","Sgn","Dec"])
 fun myIndex value values:integer=D.delay(fn()=>case force values of F.Nil=>0
   |F.Cons(current,rest)=>if equalText value current then 0 else 1+force(myIndex value rest))
 fun optionText fallback option=F.defer(fn()=>case force option of SomeValue value=>value|NoValue=>text fallback)
 fun inputForm dataset theory kind specification error=
   let val selected=D.delay(fn()=>case force kind of SomeValue value=>force(myIndex value objectTypes)|NoValue=>0)
       val first=F.fromList[FormComment(text"XVTSEDIT VERSION 1.1"),
          SingleText(text"Dataset",optionText"default_ds not passed in yet"dataset),
          SingleText(text"Theory ",optionText"empty"theory),
          MultiText(text"Spec   ",optionText""specification),
          Radio(text"Type   ",selected,objectTypes)]
       val error=F.defer(fn()=>case force error of SomeValue error=>singleton(cell(FormComment error))|NoValue=>F.empty())
   in F.append first error end
 fun controlItems values=
   let fun collect values=case L.force values of C.Nil=>[]|C.Cons(x,rest)=>L.force x::collect rest
   in collect values end
 fun getTree dataset theory kind specification error=bindAction(form true(inputForm dataset theory kind specification error))
   (fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>NONE)|SOME values=>
      case List.map force(controlItems values)of[OutText ds,OutText ty,OutText spec,OutRadio kind]=>
        let val sg=emptySignature
            fun parse xin=L.delay(fn()=>case parseTermSpec sg defaultTags spec of
                Ok term=>
                  let val object=if equalText kind(text"Thm")then cell(TheoremSpec term)
                     else if equalText kind(text"Trm")then cell(TermSpec term)else raise Match
                  in L.force(returnAction(fn()=>object)xin)end
               |Bad message=>L.force(errorAction message xin))
            val action=pairActions parse generateUid
        in bindAction action(fn delayed=>
              let val(object,uid)=L.force delayed
              in returnAction(fn()=>
                let val global=cell(int 0,F.empty(),defaultTags)
                    val goal=cell(Goal(cell NoValue,cell NoValue,cell NoValue,L.force uid,L.force object,cell true,sg,F.empty()))
                    val tree=cell(Tree(goal,F.empty(),cell NoValue,fn _=>fn tree=>tree,cell NoValue))
                in SOME(cell(TreeState(tree,F.empty(),global)))end)end)end
      |_=>raise Fail"unimplemented in get_tree")
 fun initialize dataset theory kind specification error=bindAction(getTree dataset theory kind specification error)
   (fn delayed=>case L.force delayed of NONE=>outputThenAction endX(errorAction(text"no state"))
      |SOME state=>
        let val TreeState(tree,_,global)=force state val Tree(_,children,_,_,_)=force tree
        in outputThenAction(composeOutputs[showGoal global tree,showSubgoals global children])(returnAction(fn()=>state))end)
 fun updateState previous state=
   let val TreeState(tree,_,global)=force state val Tree(_,children,_,_,_)=force tree
   in composeOutputs[showGoal global tree,showSubgoals global children]end
 fun finish xin=outputThenAction endX(returnAction(fn()=>raise Fail"Finish state evaluated"))xin
