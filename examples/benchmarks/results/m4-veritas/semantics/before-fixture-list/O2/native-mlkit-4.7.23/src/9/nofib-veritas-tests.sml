(* Independent observations of pinned Veritas source behavior.
   Protocol, parser and editor results are separate correctness claims. *)
functor NofibVeritasTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNofibVeritasFn(D)
 structure L=BenchLazy
 val root="tests/benchmarks/data/nofib-veritas/"
 fun read path=BenchApplicationTestIO.read path

 structure Protocol=struct
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
 fun check name actual=BenchApplicationTestIO.compare("nofib-veritas/"^label^"/protocol/"^name,
     read(root^"protocol-"^name^".reference"),actual)
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

 structure Parsing=struct
 fun hex value=String.concat(List.map(fn c=>let val value=Int.fmt StringCvt.HEX(Char.ord c)
     in String.map Char.toLower(if size value=1 then"0"^value else value)end)(K.F.toList value))
 fun unhex value=let fun digit c=if c>= #"0"andalso c<= #"9"then Char.ord c-48 else Char.ord c-87
       fun loop i=if i=size value then[]else Char.chr(16*digit(String.sub(value,i))+digit(String.sub(value,i+1)))::loop(i+2)
   in K.text(String.implode(loop 0))end
 fun check name actual=BenchApplicationTestIO.compare("nofib-veritas/"^label^"/"^name,
     read(root^name^".reference"),actual)
 fun tokens values=let fun loop values=case L.force values of K.C.Nil=>[]|K.C.Cons(value,rest)=>
        let val kind=case D.force(L.force value)of K.Reserved s=>"r:"^hex s|K.Clear s=>"c:"^hex s
           |K.BinderToken b=>"b:"^hex(K.unparseBinder b)|K.InfixBinderToken s=>"d:"^hex s
           |K.InfixOperatorToken s=>"o:"^hex s|K.ScanError s=>"e:"^hex s
        in kind::loop rest end
    in String.concatWith"\n"(loop values)end
 fun one row=case String.fields(fn c=>c= #"\t")row of[name,input]=>
    let val input=unhex input
        val _=check("tokens-"^name)(tokens(K.tokenize input))
        val flag=K.parseIterm(K.defaultTags,K.emptySignature)input
    in check("parse-"^name)(hex(K.unparseFlagged(K.internalSignature K.emptySignature)flag))end
   |_=>raise Fail"input table"
 val _=List.app one(List.filter(fn s=>s<>"")(String.fields(fn c=>c= #"\n")(read(root^"parser-inputs.tsv"))))
 end

 structure Editor=struct
 fun exists path=(OS.FileSys.access(path,[])handle _=>false)
 fun hex value=String.concat(List.map(fn c=>let val value=Int.fmt StringCvt.HEX(Char.ord c)
     in String.map Char.toLower(if size value=1 then"0"^value else value)end)(K.F.toList value))
 fun proof state=let val K.TreeState(tree,_,_)=D.force state
      val K.Tree(goal,children,done,_,_)=D.force tree
      val K.Goal(_,_,_,uid,_,_,_,_)=D.force goal
      val result=case D.force done of K.NoValue=>"none"|K.SomeValue value=>
         (case D.force value of K.TheoremDone theorem=>"proof:"^hex(K.unparseWrappedTheorem theorem)|_=>"other")
   in K.string uid^":"^Int.toString(D.force(K.length children))^":"^result end
 fun check name phase expected actual=BenchApplicationTestIO.compare(
     "nofib-veritas/"^label^"/"^name^"/"^phase,expected,actual)
 fun one name=
   let val source=root^"cases/"^name
       val input=K.text(read(source^".input"))
   in if exists(source^".protocol")then
      let val output=hex(K.program input)
          val _=check name"protocol"(read(source^".protocol"))output
      in if exists(source^".proof")then check name"proof"(read(source^".proof"))(case L.force(K.editorResult input)of K.Failure message=>"bad="^hex message|K.Success state=>proof(L.force state))
         else raise Fail("missing original outcome "^name)end
     else raise Fail("missing original protocol "^name)end
 val _=List.app one(List.filter(fn s=>s<>"")(String.fields(fn c=>c= #"\n")(read(root^"cases/FILES"))))
 end

 val input=root^"source/veritas.stdin"
 val _=T.check("nofib-veritas/"^label^"/complete-program-hash",fn()=>
     K.benchmark(K.input(read input))=valOf(Word64.fromString"0wxCD1FC6B0A4675CFB"))
 val _=T.check("nofib-veritas/"^label^"/signed-program-hash",fn()=>
     K.signedHash(valOf(Word64.fromString"0wxCD1FC6B0A4675CFB"))="-3665993109681513221")
 structure Check=BenchNofibVeritasCheckFn(K)
 val _=T.check("nofib-veritas/"^label^"/zero-skips-input",fn()=>Check.run["0","missing-source","0"]="0")
 val _=T.check("nofib-veritas/"^label^"/negative-skips-input",fn()=>Check.run["-2","missing-source","0"]="0")
 val _=T.check("nofib-veritas/"^label^"/wrong-result-rejected",fn()=>
      ((Check.run["1",input,"0"];false)handle Fail message=>String.isPrefix"incorrect result: "message|_=>false))
end
structure NeedVeritas=NofibVeritasTestsFn(structure D=BenchNeed val label="lazy")
structure StrictVeritas=NofibVeritasTestsFn(structure D=BenchStrict val label="strict")
