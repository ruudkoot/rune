
 fun replaceList value index values=L.delay(fn()=>
   let fun loop prefix index values=case force values of F.Nil=>Bad(text" Match")
         |F.Cons(current,rest)=>if equalInt index(int 0)then Ok(F.append prefix(F.cons(value,rest)))
           else loop(F.append prefix(singleton current))(subtract index(int 1))rest
   in loop(F.empty())index values end)
 fun treeComplete tree=case force tree of Tree(_,_,done,_,_)=>case force done of NoValue=>false|SomeValue _=>true
 fun incompleteTree tree=D.delay(fn()=>case force tree of Tree(goal,children,_,verify,old)=>
    Tree(goal,children,cell NoValue,verify,old))
 fun undoTree tree=D.delay(fn()=>case force tree of Tree(_,_,_,_,old)=>
    (case force old of SomeValue previous=>force previous|NoValue=>force tree))
 fun downTree index state=D.delay(fn()=>case force state of TreeState(tree,spine,global)=>
    let val Tree(_,children,_,_,_)=force tree
    in TreeState(nth children index,F.cons(pair index tree,spine),global)end)
 fun upTree state=L.delay(fn()=>case force state of TreeState(tree,spine,global)=>
    case force spine of F.Nil=>Ok state|F.Cons(entry,rest)=>
      let val(index,parent)=force entry
          val Tree(goal,children,done,verify,old)=force parent
          val replacement=replaceList tree index children
      in case L.force replacement of Bad message=>Bad message|Ok children=>
         let val changed=cell(Tree(goal,children,done,verify,old))
             val completed=treeComplete changed
             val result=D.delay(fn()=>force(if completed andalso not(treeComplete tree)then
                 if treeComplete tree then changed else incompleteTree changed
               else verify global changed))
         in Ok(cell(TreeState(result,rest,global)))end end)
 fun topTree state=L.delay(fn()=>case force state of TreeState(_,spine,_)=>
    if null spine then Ok state else case L.force(upTree state)of Bad message=>Bad message
      |Ok next=>L.force(topTree next))
 fun searchTree predicate includeChildren tree=
   let fun search tree path=F.defer(fn()=>case force tree of Tree(_,children,_,_,_)=>
         if predicate tree then
            F.append(if includeChildren then sub children(int 0)path else F.empty())(singleton(pair path tree))
         else sub children(int 0)path)
       and sub children index path=F.defer(fn()=>case force children of F.Nil=>F.empty()
         |F.Cons(tree,rest)=>F.append(search tree(F.cons(index,path)))(sub rest(add index(int 1))path))
   in search tree(F.empty())end
 fun gotoTree path state=D.delay(fn()=>case force path of F.Nil=>force state|F.Cons(index,rest)=>force(gotoTree rest(downTree index state)))
 fun failedTree state message=bindAction(errorMessage message)(fn _=>returnAction(fn()=>state))
 fun liftPureTree function state=
   let val TreeState(tree,spine,global)=force state
       fun action xin=L.delay(fn()=>case L.force(function tree)of Bad message=>L.force(errorAction message xin)
          |Ok changed=>L.force(returnAction(fn()=>cell(TreeState(changed,spine,global)))xin))
   in handleAction action(failedTree state)end
 fun liftIOTree function state=
   let val TreeState(tree,spine,global)=force state
       val action=bindAction(function tree)(fn changed=>returnAction(fn()=>cell(TreeState(L.force changed,spine,global))))
   in handleAction action(failedTree state)end
 fun liftPureTreeState function state=
   let fun action xin=L.delay(fn()=>case L.force(function state)of Bad message=>L.force(errorAction message xin)
          |Ok changed=>L.force(returnAction(fn()=>changed)xin))
   in handleAction action(failedTree state)end
 fun liftIOTreeState function state=handleAction(function state)(fn _=>returnAction(fn()=>state))
 fun treeUndo state=liftPureTree(fn tree=>L.delay(fn()=>Ok(undoTree tree)))state
 fun treeTop state=liftPureTreeState topTree state
 fun treeUp state=liftPureTreeState upTree state
 fun treeDown index state=liftPureTreeState(fn state=>L.delay(fn()=>Ok(downTree index state)))state
 val initialGlobal:globalState D.t=cell(int ~1,F.empty(),defaultTags)
 fun getPrintDepth state=let val(depth,_,_)=force state in depth end
 fun getGlobalAttributes state=let val(_,attributes,_)=force state in attributes end
 fun getGlobalTags state=let val(_,_,tags)=force state in tags end
 fun setPrintDepth depth state=D.delay(fn()=>let val(_,attrs,tags)=force state in(depth,attrs,tags)end)
 fun setGlobalAttributes attrs state=D.delay(fn()=>let val(depth,_,tags)=force state in(depth,attrs,tags)end)
 fun setGlobalTags tags state=D.delay(fn()=>let val(depth,attrs,_)=force state in(depth,attrs,tags)end)
