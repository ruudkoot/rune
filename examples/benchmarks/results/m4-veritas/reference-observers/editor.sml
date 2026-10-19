 fun commandAction commands state name=
   let fun find commands=case force commands of F.Nil=>NONE|F.Cons(entry,rest)=>let val(key,action)=force entry
         in if equalText name key then SOME action else find rest end
   in case find commands of SOME action=>action state|NONE=>
        bindAction(errorMessage(F.append(text"Bad command: ")name))(fn _=>returnAction(fn()=>state))end
 fun processCommands commands previous state=
   handleAction(outputThenAction(updateState previous state)
      (bindAction getCommand(fn delayed=>
         let val command=L.force delayed
         in if equalText command(text"Quit")then returnAction(fn()=>state)
            else bindAction(commandAction commands state command)(fn changed=>processCommands commands state(L.force changed))end)))
     (fn message=>bindAction(errorMessage message)(fn _=>processCommands commands previous state))
 fun editor commands=
   bindAction(initialize(cell NoValue)(cell NoValue)(cell NoValue)(cell NoValue)(cell NoValue))
    (fn initial=>
      let val state=L.force initial
      in bindAction(pairActions(processCommands commands state state)finish)
          (fn delayed=>let val(state,_)=L.force delayed in returnAction(fn()=>L.force state)end)end)
 fun proofEdit commands xin=handleAction(editor commands)(fn message=>
      bindAction(errorMessage message)(fn _=>proofEdit commands))xin
