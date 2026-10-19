functor ProtocolTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchVeritasFn(D)
 structure L=BenchLazy
 val root="tests/out/benchmarks/nofib-veritas-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun hex value=String.concat(List.map(fn c=>
    let val text=Int.fmt StringCvt.HEX(Char.ord c)
    in String.map Char.toLower(if size text=1 then"0"^text else text)end)(K.F.toList value))
 fun input s=L.delay(fn()=>(K.text s,K.controlRange(K.int 0),K.controlRange(K.int 1)))
 fun out function raw=
   let val(after,bytes)=L.force(function(input raw))
       val(rest,_,_)=L.force after
   in hex bytes^":"^hex rest end
 fun act function raw showValue=
   let val(after,reply,bytes)=L.force(function(input raw))
       val(rest,_,_)=L.force after
       val result=case L.force reply of K.Failure message=>"bad="^hex message|K.Success value=>showValue value
   in hex bytes^":"^hex rest^":"^result end
 fun check name actual=let val expected=read(root^"protocol-"^name^".reference")
    in if actual=expected then print("PASS "^label^" protocol-"^name^"\n")
       else (print("ACTUAL "^actual^"\nEXPECTED "^expected^"\n");raise Fail("protocol "^name))end
 fun outputs(name,function)=check name(out function"rest")
 val binary=K.text(String.implode[Char.chr 0,Char.chr 255])
 val sub=K.cell(K.SubtermData(K.F.fromList[0,2],K.int 3,K.int 4,
       K.singleton(K.cell(K.SubtermData(K.F.empty(),K.int 5,K.int 6,K.F.empty())))))
 val _=List.app outputs[
   ("send-args",K.sendArguments(K.fromNative[K.text"abc",K.text"",binary])),
   ("form-output",(fn xin=>
       let val result=K.form false(K.F.fromList[K.FormComment(K.text"title"),
             K.MultiText(K.text"",K.text"body"),K.Radio(K.text"kind",K.int 0,
               K.fromNative[K.text"a",K.text"b"])])xin
       in L.delay(fn()=>(K.forwardInput result,K.actionOutput result))end)),
   ("set-parent",K.setParent(K.text"yes")(K.text"parent")),("set-node",K.setNode(K.text"node")),
   ("set-rw",K.setReadWrite(K.text"r")),("set-done",K.setDone(K.text"done")),
   ("set-goal",K.setGoal(K.text"yes")(K.text"goal")),("set-tactic",K.setTactic(K.text"t")),
   ("set-argument",K.setArgument(K.text"a")),("set-comment",K.setComment(K.text"c")),
   ("set-subgoals",K.setSubgoals(K.fromNative[K.pair(K.text"a")(K.text"b"),K.pair(K.text"c")(K.text"d")])),
   ("set-status",K.setStatus(K.text"s")),("unset-parent",K.unsetParent),("bell",K.bell),
   ("show-tactics",K.showTactics),("show-window",K.showWindow),("hide-window",K.hideWindow),
   ("set-full",K.setFull(K.F.fromList[2])(K.text"title")(K.text"body")),("unset-full",K.unsetFull),
   ("send-subterm",K.sendSubtermData sub)]
 fun forms value=case L.force value of NONE=>"none"|SOME values=>
   let fun collect values=case L.force values of K.C.Nil=>[]|K.C.Cons(x,rest)=>D.force(L.force x)::collect rest
   in case collect values of[K.OutText a,K.OutText b,K.OutText c,K.OutRadio d]=>
       "form="^String.concat(List.map(fn s=>hex s^";")[a,b,c,d])|_=>raise Fail"unexpected form"end
 val _=check"parse-form"(act K.getForm(read(root^"source/veritas.stdin"))forms)
 val _=check"command"(act K.getCommand("\0272\027A\001Quit\0274\0275rest")(fn value=>"cmd="^hex(L.force value)))
 val _=check"ignored-error"(act(K.bindAction(K.errorMessage(K.text"oops"))(fn _=>K.returnAction(fn()=>42)))"\0279rest"
       (fn value=>Int.toString(L.force value)))
 val _=check"ignored-value"(act(K.bindAction(K.returnAction(fn()=>raise Fail"unneeded"))(fn _=>K.returnAction(fn()=>42)))"rest"
       (fn value=>Int.toString(L.force value)))
 val _=check"ignored-pair"(act(K.bindAction(K.pairActions(K.returnAction(fn()=>raise Fail"unneeded"))(K.returnAction(fn()=>42)))
       (fn pair=>let val(_,n)=L.force pair in K.returnAction(fn()=>L.force n)end))"rest"(fn value=>Int.toString(L.force value)))
 val _=check"handled-error"(act(K.handleAction(K.errorAction(K.text"failed"))(fn message=>K.returnAction(fn()=>K.F.append(K.text"handled:")message)))"rest"
       (fn value=>hex(L.force value)))
end
structure Need=ProtocolTests(structure D=BenchNeed val label="lazy")
structure Strict=ProtocolTests(structure D=BenchStrict val label="strict")
