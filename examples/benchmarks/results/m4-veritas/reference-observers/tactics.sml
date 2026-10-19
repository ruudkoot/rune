
 type tacticArguments=textNode F.node optionNode D.t
 type completion=doneNode optionNode D.t
 type completions=doneNode optionNode F.seq
 type validator=completions->completion
 type orderedValidator=completions->bool F.seq->(bool F.seq*signatureNode F.seq*completion)L.delay
 type lookupTables=lookupEntry F.node F.node F.seq
 type tacticInfo=objectNode F.seq*validator
 type orderedTacticInfo=objectNode F.seq*lookupTables*bool F.seq*orderedValidator
 datatype tactic=Tactic of text*
    (globalState D.t->lookupTable->objectNode D.t->tacticArguments action)*
    (globalState D.t->signatureValue->lookupTable->tacticArguments->objectNode D.t->(tacticInfo,textNode)replyNode L.delay)
 datatype orderedTactic=OrderedTactic of text*
    (globalState D.t->lookupTable->objectNode D.t->tacticArguments action)*
    (globalState D.t->signatureValue->lookupTable->tacticArguments->objectNode D.t->(orderedTacticInfo,textNode)replyNode L.delay)
 fun nullArguments global lookup object=returnAction(fn()=>cell NoValue:tacticArguments)
 fun getDone tree:completion=D.delay(fn()=>case force tree of Tree(_,_,done,_,_)=>force done)
 fun getEditable tree=D.delay(fn()=>case force tree of Tree(goal,_,_,_,_)=>
    let val Goal(_,_,_,_,_,editable,_,_)=force goal in force editable end)
 fun setTreeInformation tree editable signatureValue:proofTree=D.delay(fn()=>case force tree of Tree(goal,children,done,verify,old)=>
    let val Goal(tactic,args,comment,uid,object,_,_,lookup)=force goal
        val goal=cell(Goal(tactic,args,comment,uid,object,editable,signatureValue,lookup))
    in Tree(goal,children,done,verify,old)end)
 fun liftValidation validate global tree:proofTree=D.delay(fn()=>case force tree of Tree(goal,children,done,verify,old)=>
    case force done of SomeValue _=>force tree|NoValue=>
      Tree(goal,children,validate(map getDone children),verify,old))
 fun liftOrderedValidation validate global tree:proofTree=D.delay(fn()=>case force tree of Tree(goal,children,done,verify,old)=>
    case force done of SomeValue _=>force tree|NoValue=>
      let val values=map getDone children val editables=map getEditable children
          val result=validate values editables
          val changed=F.defer(fn()=>let val(editables,signatures,_)=L.force result
              in zip(fn tree=>fn info=>let val(editable,currentSignature)=force info
                   in setTreeInformation tree editable currentSignature end)children(zip pair editables signatures)end)
          val done=D.delay(fn()=>let val(_,_,done)=L.force result in force done end)
      in Tree(goal,changed,done,verify,old)end)
 fun makeGoal signatureValue lookup editable object=bindAction generateUid(fn delayed=>returnAction(fn()=>
   let val goal=cell(Goal(cell NoValue,cell NoValue,cell NoValue,L.force delayed,object,editable,signatureValue,lookup))
   in cell(Tree(goal,F.empty(),cell NoValue,fn _=>fn tree=>tree,cell NoValue)):proofTree end))
 fun makeGoals signatureValue lookup objects result input=
   case force objects of F.Nil=>returnAction(fn()=>result)input
    |F.Cons(object,rest)=>bindAction(makeGoal signatureValue lookup(cell true)object)
       (fn delayed=>makeGoals signatureValue lookup rest(F.append result(singleton(L.force delayed))))input
 fun makeOrderedGoals signatureValue entries result input=
   case force entries of F.Nil=>returnAction(fn()=>result)input
    |F.Cons(entry,rest)=>let val(lookup,info)=force entry val(editable,object)=force info
      in bindAction(makeGoal signatureValue lookup editable object)
          (fn delayed=>makeOrderedGoals signatureValue rest(F.append result(singleton(L.force delayed))))input end
 fun liftTactic(Tactic(name,arguments,subgoals))=
   let fun run(state:proofState)=
      let val TreeState(tree,spine,global)=force state
          val Tree(goal,children,_,_,_)=force tree
          val Goal(previous,args,comment,uid,object,editable,signatureValue,lookup)=force goal
      in if not(null children)then errorAction(text"cannot apply tactic")
         else case(force previous,force args)of(NoValue,NoValue)=>
           bindAction(arguments global lookup object)(fn delayed=>
             let val args=L.force delayed
                 fun next input=L.delay(fn()=>case L.force(subgoals global signatureValue lookup args object)of
                    Bad message=>L.force(errorAction message input)
                   |Ok info=>let val(objects,validate)=force info
                     in L.force(bindAction(makeGoals signatureValue lookup objects(F.empty()))(fn delayed=>
                          returnAction(fn()=>
                            let val verify=liftValidation validate
                                val goal=cell(Goal(cell(SomeValue name),args,comment,uid,object,editable,signatureValue,lookup))
                                val current=cell(Tree(goal,L.force delayed,cell NoValue,verify,cell(SomeValue tree)))
                            in cell(TreeState(verify global current,spine,global))end))input)end)
             in next end)
          |_=>raise Match end
   in(name,run)end
 fun liftOrderedTactic(OrderedTactic(name,arguments,subgoals))=
   let fun run(state:proofState)=
      let val TreeState(tree,spine,global)=force state
          val Tree(goal,children,_,_,_)=force tree
          val Goal(previous,args,comment,uid,object,editable,signatureValue,lookup)=force goal
      in if not(null children)then errorAction(text"cannot apply tactic")
         else case(force previous,force args)of(NoValue,NoValue)=>
           bindAction(arguments global lookup object)(fn delayed=>
             let val args=L.force delayed
                 fun next input=L.delay(fn()=>case L.force(subgoals global signatureValue lookup args object)of
                    Bad message=>L.force(errorAction message input)
                   |Ok info=>let val(objects,lookups,editables,validate)=force info
                         val entries=zip pair lookups(zip pair editables objects)
                     in L.force(bindAction(makeOrderedGoals signatureValue entries(F.empty()))(fn delayed=>
                          returnAction(fn()=>
                            let val verify=liftOrderedValidation validate
                                val goal=cell(Goal(cell(SomeValue name),args,comment,uid,object,editable,signatureValue,lookup))
                                val current=cell(Tree(goal,L.force delayed,cell NoValue,verify,cell(SomeValue tree)))
                            in cell(TreeState(verify global current,spine,global))end))input)end)
             in next end)
          |_=>raise Match end
   in(name,run)end
 fun tacticOrElse first second state=handleAction(first state)(fn _=>second state)
 fun tacticSubtrees function state=
   let val TreeState(tree,_,_)=force state val Tree(_,children,_,_,_)=force tree
       val count=length children
       fun loop index state=if leq count index then returnAction(fn()=>state)
         else bindAction(treeDown index state)(fn down=>
                bindAction(function(L.force down))(fn result=>
                 bindAction(treeUp(L.force result))(fn up=>loop(add index(int 1))(L.force up))))
   in loop(int 0)state end
 fun tacticAndThen first second state=bindAction(first state)(fn result=>tacticSubtrees second(L.force result))
 fun repeatTactic function state=bindAction(function state)(fn changed=>
    handleAction(tacticSubtrees(repeatTactic function)(L.force changed))(fn _=>returnAction(fn()=>state)))
 fun forTactic count function state=if equalInt count(int 0)then returnAction(fn()=>state)
   else bindAction(function state)(fn changed=>tacticSubtrees(forTactic(subtract count(int 1))function)(L.force changed))
