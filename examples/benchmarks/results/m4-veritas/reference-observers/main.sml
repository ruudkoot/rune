
 val commands:(text*(proofState->proofState action))F.seq=
   fromNative(List.map(fn(name,action)=>pair name action)[
      (text"Top",treeTop),(text"P",treeUp),(text"PExpand",showGoalCommand),
      (text"1Expand",showSubgoalCommand(int 0)),(text"2Expand",showSubgoalCommand(int 1)),
      (text"3Expand",showSubgoalCommand(int 2)),(text"4Expand",showSubgoalCommand(int 3)),
      (text"Theory",showTheory),(text"Object",showObject),(text"Comment",showComment),(text"Arguments",showArguments),
      (text"1",treeDown(int 0)),(text"2",treeDown(int 1)),(text"3",treeDown(int 2)),(text"4",treeDown(int 3)),
      (text"Next",gotoNext),(text"Named",gotoNamed),(text"Undo",treeUndo),(text"Tactic",showTacticsCommand),
      (text"Strip",stripTactic),(text"Triv",trivialTactic),
      liftTactic conjunctionTactic,liftOrderedTactic generalizeTactic,liftTactic autoTactic,liftTactic reflexTactic,
      liftOrderedTactic dischargeTactic,liftTactic disjunctionTactic,liftTactic equalityTactic,liftTactic orTactic,
      liftTactic lemmaTactic,liftTactic notTactic,liftTactic existsEliminationTactic,liftTactic tautologyTactic,
      liftTactic axiomTactic,liftTactic hypothesisTactic,liftTactic inductionTactic,liftTactic completeTactic])
 fun program input=
   let val initial=L.delay(fn()=>(input,controlRange(int 0),controlRange(int 1)))
   in actionOutput(proofEdit commands initial)end
 fun finalState input=
   let val initial=L.delay(fn()=>(input,controlRange(int 0),controlRange(int 1)))
   in L.delay(fn()=>case L.force(actionValue(proofEdit commands initial))of
        Success state=>L.force state|Failure message=>raise Fail(string message))end

 fun editorResult input=
   let val initial=L.delay(fn()=>(input,controlRange(int 0),controlRange(int 1)))
   in actionValue(proofEdit commands initial)end
