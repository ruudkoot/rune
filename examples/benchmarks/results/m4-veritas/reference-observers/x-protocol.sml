 val escape7=text(String.str(Char.chr 27)^"7")
 val escape0=text(String.str(Char.chr 27)^"0")
 val escape1=text(String.str(Char.chr 27)^"1")
 val escape2=text(String.str(Char.chr 27)^"2")
 val escape4=text(String.str(Char.chr 27)^"4")
 val escape5=text(String.str(Char.chr 27)^"5")
 val escape6=text(String.str(Char.chr 27)^"6")
 val escape8=text(String.str(Char.chr 27)^"8")
 val escape9=text(String.str(Char.chr 27)^"9")
 val escapeA=text(String.str(Char.chr 27)^"A")
 val escapeB=text(String.str(Char.chr 27)^"B")
 val escapeC=text(String.str(Char.chr 27)^"C")
 val escapeD=text(String.str(Char.chr 27)^"D")
 val escapeE=text(String.str(Char.chr 27)^"E")
 val escapeF=text(String.str(Char.chr 27)^"F")
 val escapeG=text(String.str(Char.chr 27)^"G")
 val escapeH=text(String.str(Char.chr 27)^"H")
 val escapeI=text(String.str(Char.chr 27)^"I")
 val escapeJ=text(String.str(Char.chr 27)^"J")
 val escapeK=text(String.str(Char.chr 27)^"K")
 val escapeL=text(String.str(Char.chr 27)^"L")
 val escapeM=text(String.str(Char.chr 27)^"M")
 val escapeN=text(String.str(Char.chr 27)^"N")
 val escapeO=text(String.str(Char.chr 27)^"O")
 val escapeP=text(String.str(Char.chr 27)^"P")
 val escapeQ=text(String.str(Char.chr 27)^"Q")
 val escapeR=text(String.str(Char.chr 27)^"R")
 val escapeT=text(String.str(Char.chr 27)^"T")
 val escapea=text(String.str(Char.chr 27)^"a")
 val escapeb=text(String.str(Char.chr 27)^"b")
 val escapec=text(String.str(Char.chr 27)^"c")
 val escaped=text(String.str(Char.chr 27)^"d")
 val escapee=text(String.str(Char.chr 27)^"e")

 fun send chars xin=L.delay(fn()=>(xin,chars))
 fun noOutput xin=L.delay(fn()=>(xin,F.empty()))
 fun composeOutputs actions=List.foldl(fn(next,acc)=>sequenceOutput acc next)noOutput actions
 fun sendArgument argument=composeOutputs[send argument,send(escape4)]
 fun sendArguments arguments=composeOutputs[
     send(escapeA),send(singleton(D.delay(fn()=>Char.chr(force(length arguments))))),
     outputActions(map(fn arg=>cell(sendArgument arg))arguments),send(escape5)]
 fun sendMultiple function arguments=composeOutputs[
     send(escapeA),send(singleton(D.delay(fn()=>Char.chr(force(length arguments))))),
     outputActions(map(fn arg=>cell(composeOutputs[function arg,send(escape4)]))arguments),send(escape5)]
 fun getEscape xin=L.delay(fn()=>
   let val(input,responses,ids)=L.force xin
       val first=head input val second=head(tail input)
       val after=L.delay(fn()=>(tail(tail input),responses,ids))
   in L.force(returnAction(fn()=>fromNative[first,second])after)end)
 fun getArgumentNumber xin=bindAction getEscape(fn delayed=>fn current=>
   if equalText(L.force delayed)(escapeA)then L.delay(fn()=>
      let val(input,responses,ids)=L.force current
          val count=Char.ord(force(head input))
          val after=L.delay(fn()=>(tail input,responses,ids))
      in L.force(returnAction(fn()=>count)after)end)
   else errorAction(text"Expected multiple arguments")current)xin
 fun getArgument xin=L.delay(fn()=>
   let val(input,responses,ids)=L.force xin
   in case force input of F.Nil=>raise Fail"stdin empty"|F.Cons(c,rest)=>
       if force c=Char.chr 27 then
         let val second=head rest
             val after=L.delay(fn()=>(tail rest,responses,ids))
         in if force second= #"4"then L.force(returnAction(fn()=>F.empty())after)
             else L.force(errorAction(text"Bad argument escape")after)end
       else L.force(bindTransaction(getArgument(L.delay(fn()=>(rest,responses,ids))))
          (fn delayed=>returnAction(fn()=>F.cons(c,L.force delayed))))end)
 fun getArgumentsCount count=
   if count=0 then returnAction(fn()=>C.empty())
   else listActions getArgument(getArgumentsCount(count-1))
 fun getArguments xin=bindAction getArgumentNumber(fn delayed=>
    pairActions(getArgumentsCount(L.force delayed))getEscape)xin
 fun getArgumentList xin=bindAction getArguments(fn delayed=>fn current=>
   let val(arguments,ending)=L.force delayed
   in if equalText(L.force ending)(escape5)then returnAction(fn()=>L.force arguments)current
       else errorAction(text"Bad argument terminator ")current end)xin
 fun getMultipleCount function count=
   if count=0 then returnAction(fn()=>C.empty())
   else listActions function(getMultipleCount function(count-1))
 fun getMultiple function xin=bindAction getArgumentNumber(fn delayed=>
    bindAction(pairActions(getMultipleCount function(L.force delayed))getEscape)
      (fn delayed=>fn current=>let val(arguments,ending)=L.force delayed
          in if equalText(L.force ending)(escape5)then returnAction(fn()=>L.force arguments)current
             else errorAction(text"Bad argument terminator ")current end))xin
 fun controlHead values=case L.force values of C.Nil=>raise Empty|C.Cons(x,_)=>x
 fun controlTail values=C.defer(fn()=>case L.force values of C.Nil=>raise Empty|C.Cons(_,rest)=>rest)
 fun endX xin=send(escape0)xin
 fun enableButtons xin=send(escape1)xin
 fun getCommand xin=outputThenAction enableButtons
    (bindAction(pairActions getEscape getArgumentList)(fn delayed=>fn current=>
      let val(code,arguments)=L.force delayed
      in if equalText(L.force code)(escape2)then
          returnAction(fn()=>L.force(controlHead(L.force arguments)))current
         else errorAction(text"Expected command")current end))xin
 fun errorMessage message=outputThenAction(composeOutputs[send(escape6),sendArguments(singleton message)])
     (bindAction getEscape(fn delayed=>fn current=>if equalText(L.force delayed)(escape9)
         then returnAction(fn()=>raise Fail"")current else errorAction(text"Expected cancel")current))
 fun sendBoolean flag=send(text(if flag then"1"else"0"))
 fun sendNumber number=send(fromNative[
      D.delay(fn()=>Char.chr((force number div 256)mod 256)),D.delay(fn()=>Char.chr(force number mod 256))])
 fun sendSubtermData value=
   let val SubtermData(indices,i,j,children)=force value
   in composeOutputs[sendMultiple sendNumber indices,sendNumber i,sendNumber j,sendMultiple sendSubtermData children]end
 fun sendFormInfo value=case force value of
    SingleText(label,chars)=>composeOutputs[send(escapea),sendArguments(fromNative[label,chars])]
   |MultiText(label,chars)=>composeOutputs[send(escapeb),sendArguments(fromNative[label,chars])]
   |Toggle(label,options)=>composeOutputs[send(escapec),sendArguments(singleton label),
       sendArguments(flatMap(fn option=>let val(name,selected)=force option in fromNative[name,text(if force selected then"1"else"0")]end)options)]
   |Radio(label,index,options)=>composeOutputs[send(escaped),sendArguments(singleton label),sendNumber index,sendArguments options]
   |FormComment chars=>composeOutputs[send(escapee),sendArguments(singleton chars)]
   |Subterm(label,data)=>composeOutputs[send(escapeO),sendArguments(singleton label),sendSubtermData data]
 fun getFormInfo xin=bindAction(pairActions getEscape getArgumentList)(fn delayed=>fn current=>
   let val(code,arguments)=L.force delayed
       val code=L.force code val arguments=L.force arguments
       fun first()=L.force(controlHead arguments)
       fun finite values=F.defer(fn()=>case L.force values of C.Nil=>F.empty()
            |C.Cons(x,rest)=>F.cons(L.force x,finite rest))
   in if equalText code escapea orelse equalText code escapeb then
         returnAction(fn()=>cell(OutText(first())))current
      else if equalText code escapec then returnAction(fn()=>cell(OutToggle(finite arguments)))current
      else if equalText code escaped then returnAction(fn()=>cell(OutRadio(first())))current
      else if equalText code escapeO then returnAction(fn()=>cell(OutSubterm(first())))current
      else errorAction(text" XError Bad form escape sequence")current end)xin
 fun getForm xin=bindAction getEscape(fn delayed=>fn current=>
    if equalText(L.force delayed)(escape9)then returnAction(fn()=>NONE)current
    else if equalText(L.force delayed)(escape8)then
       bindAction(getMultiple getFormInfo)(fn info=>returnAction(fn()=>SOME(L.force info)))current
    else errorAction(text" XError Expected form escape")current)xin
 fun form answer information=outputThenAction(composeOutputs[send(escape8),sendBoolean answer,sendMultiple sendFormInfo information])
     (if answer then getForm else returnAction(fn()=>NONE))
 fun display title content xin=L.delay(fn()=>let val result=form false(F.fromList[FormComment title,MultiText(text"",content)])xin
    in(forwardInput result,actionOutput result)end)
 fun setParent done summary=composeOutputs[send(escapeB),sendArguments(fromNative[done,summary])]
 fun setNode value=composeOutputs[send(escapeC),sendArguments(singleton value)]
 fun setReadWrite value=composeOutputs[send(escapeD),sendArguments(singleton value)]
 fun setDone value=composeOutputs[send(escapeE),sendArguments(singleton value)]
 fun setGoal done content=composeOutputs[send(escapeF),sendArguments(fromNative[done,content])]
 fun setTactic value=composeOutputs[send(escapeG),sendArguments(singleton value)]
 fun setArgument value=composeOutputs[send(escapeH),sendArguments(singleton value)]
 fun setComment value=composeOutputs[send(escapeI),sendArguments(singleton value)]
 fun setSubgoals values=composeOutputs[send(escapeJ),sendArguments(flatMap(fn entry=>
      let val(done,summary)=force entry in fromNative[done,summary]end)values)]
 fun setStatus value=composeOutputs[send(escapeK),sendArguments(singleton value)]
 fun unsetParent xin=send(escapeL)xin
 fun bell xin=send(escapeM)xin
 fun showTactics xin=send(escapeN)xin
 fun setFull indices title content=composeOutputs[send(escapeP),sendArguments(fromNative[
      text(Int.toString(force(head indices))),title,content])]
 fun unsetFull xin=send(escapeQ)xin
 fun hideWindow xin=send(escapeR)xin
 fun showWindow xin=send(escapeT)xin

 fun scratch value=composeOutputs[send escape7,sendArguments(singleton value)]
 fun sendToggle option=let val(name,selected)=force option
    in composeOutputs[sendBoolean(force selected),sendArgument name]end
 fun sendForm values xin=L.delay(fn()=>case force values of F.Nil=>L.force(send escape5 xin)
   |F.Cons(info,rest)=>if null rest then L.force(composeOutputs[sendFormInfo info,send escape5]xin)
      else L.force(composeOutputs[sendFormInfo info,send escape4,sendForm rest]xin))
