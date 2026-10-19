
 fun objectTitle object=case force object of TheoremSpec _=>text"Thm Goal No: "|TermSpec _=>text"Trm Goal No: "
   |SignatureSpec _=>text"Sgn Goal No: "|DeclarationSpec _=>text"Dec Goal No: "
 fun displayTree state tree=
   let val TreeState(_,_,global)=force state
       val Tree(goal,_,_,_,_)=force tree
       val Goal(_,_,_,uid,object,_,signatureValue,_)=force goal
   in outputThenAction(display(F.append(objectTitle object)uid)(objectText signatureValue object))(returnAction(fn()=>state))end
 fun showGoalCommand state=let val TreeState(tree,_,_)=force state in displayTree state tree end
 fun showSubgoalCommand index state=
   let val TreeState(tree,_,_)=force state val Tree(_,children,_,_,_)=force tree
   in displayTree state(nth children index)end
 val theoryForm:formInputNode F.seq=F.fromList[FormComment(text"     Show Theory"),
      Radio(text"Display Theory",int 1,F.fromList(List.map(fn s=>force(text s))["Strcutured","Unstructered","Just Names"]))]
 fun showTheory state=bindAction(form true theoryForm)(fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>state)
   |SOME values=>case List.map force(controlItems values)of[OutRadio choice]=>
      let val TreeState(tree,_,_)=force state
          val Tree(goal,_,_,_,_)=force tree
          val Goal(_,_,_,uid,_,editable,signatureValue,_)=force goal
      in if not(force editable)then outputThenAction(setStatus(text"Theory not yet defined"))(returnAction(fn()=>state))
         else if equalText choice(text"Strcutured")then
            outputThenAction(display(F.append(text"Signature of Node No. ")uid)(unparseSignature(internalSignature signatureValue)))
               (returnAction(fn()=>state))
         else if equalText choice(text"Unstructered")orelse equalText choice(text"Just Names")then
            raise Fail"unimplemented in display"
         else returnAction(fn()=>state)end
     |_=>returnAction(fn()=>state))
 fun showObject state=
   let val TreeState(tree,_,global)=force state
       val Tree(goal,_,_,_,_)=force tree
       val Goal(_,_,_,_,_,editable,signatureValue,_)=force goal
       val descriptor=F.fromList[FormComment(text"         Parse Object"),Radio(text"Type of Object",int 0,objectTypes),
          FormComment(text""),MultiText(text"Specification",text""),
          Radio(text"Display Window",int 0,F.fromList(List.map(fn s=>force(text s))["Own","Scratch"]))]
       val action=bindAction(form true descriptor)(fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>state)
          |SOME values=>case List.map force(controlItems values)of[OutRadio kind,OutText specification,OutRadio window]=>
             let val content=F.defer(fn()=>if equalText kind(text"Trm")then
                    let val term=parseWrappedTerm(defaultTags,signatureValue)specification
                    in case force term of TM(body,_,sg)=>unparseITerm sg body|_=>raise Match end
                  else text"Bad Object")
                 val show=if equalText window(text"Scratch")then scratch(textConcat[text"\n\n",kind,text"\n\n",content])
                    else display kind content
             in outputThenAction show(returnAction(fn()=>state))end|_=>raise Match)
   in if force editable then action else outputThenAction(setStatus(text"Theory not yet defined"))(returnAction(fn()=>state))end
 fun treeComment tree=F.defer(fn()=>case force tree of Tree(goal,_,_,_,_)=>
    let val Goal(_,_,comment,_,_,_,_,_)=force goal
    in case force comment of NoValue=>F.empty()|SomeValue value=>value end)
 fun setTreeComment chars tree:proofTree=D.delay(fn()=>case force tree of Tree(goal,children,done,verify,old)=>
    let val Goal(tactic,args,_,uid,object,editable,signatureValue,lookup)=force goal
        val comment=if null chars then cell NoValue else cell(SomeValue chars)
        val changed=cell(Goal(tactic,args,comment,uid,object,editable,signatureValue,lookup))
    in Tree(changed,children,done,verify,old)end)
 fun showComment state=
   let val TreeState(tree,_,_)=force state val Tree(goal,_,_,_,_)=force tree
       val Goal(_,_,comment,uid,_,_,_,_)=force goal
       val output=case force comment of NoValue=>setStatus(text"No Comment defined")
          |SomeValue chars=>display(F.append(text"Comment for Node No: ")uid)chars
   in outputThenAction output(returnAction(fn()=>state))end
 fun editComment state=
   let val TreeState(tree,spine,global)=force state
       val descriptor=F.fromList[FormComment(text"Edit Comment"),MultiText(text"Comment:",treeComment tree)]
   in bindAction(form true descriptor)(fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>state)
      |SOME values=>case List.map force(controlItems values)of[OutText chars]=>
          returnAction(fn()=>cell(TreeState(setTreeComment chars tree,spine,global)))|_=>returnAction(fn()=>state))end
 fun showArguments state=
   let val TreeState(tree,_,_)=force state val Tree(goal,_,_,_,_)=force tree
       val Goal(tactic,args,_,uid,_,_,_,_)=force goal
       val output=case force tactic of NoValue=>setStatus(text"No tactic applied!")|SomeValue tactic=>
          let val content=F.defer(fn()=>case force args of NoValue=>text"NONE"|SomeValue args=>
                flatMap(fn arg=>F.append arg(text"\n\n"))args)
              val title=textConcat[text"Node: ",uid,text"\nTactic: ",tactic,text"\nArguments:"]
          in display title content end
   in outputThenAction output(returnAction(fn()=>state))end
 fun showTacticsCommand state=outputThenAction showTactics(returnAction(fn()=>state))
 fun incompleteCandidate tree=case force tree of Tree(_,children,done,_,_)=>case force done of SomeValue _=>false|NoValue=>all treeComplete children
 fun gotoNext state=bindAction(treeTop state)(fn delayed=>
   let val top=L.force delayed val TreeState(original,_,_)=force state val TreeState(root,_,_)=force top
       val first=searchTree incompleteCandidate false original
       val second=F.defer(fn()=>searchTree incompleteCandidate false root)
   in if not(null first)then let val(path,_)=force(head first)in returnAction(fn()=>gotoTree path state)end
      else if not(null second)then let val(path,_)=force(head second)in returnAction(fn()=>gotoTree path top)end
      else returnAction(fn()=>state)end)
 val namedForm:formInputNode F.seq=F.fromList[FormComment(text"Goto Node"),FormComment(text""),FormComment(text"Uid of Node"),SingleText(text"",text"")]
 fun gotoNamed state=bindAction(pairActions(form true namedForm)(treeTop state))(fn delayed=>
   let val(response,top)=L.force delayed val top=L.force top val TreeState(root,_,_)=force top
   in case L.force response of NONE=>returnAction(fn()=>state)|SOME values=>
        case List.map force(controlItems values)of[OutText uid]=>
          let fun named tree=case force tree of Tree(goal,_,_,_,_)=>let val Goal(_,_,_,current,_,_,_,_)=force goal in equalText uid current end
              val matches=searchTree named true root
          in if null matches then outputThenAction(setStatus(text"No such node"))(returnAction(fn()=>state))
             else let val(path,_)=force(head matches)in returnAction(fn()=>gotoTree path top)end end
         |_=>returnAction(fn()=>state)end)
