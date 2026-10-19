(* Veritas's pinned pure proof-editor protocol and core representations.
   Selected native indices are bounded signed 31-bit values; output hashes
   explicitly retain the original 64-bit modular arithmetic. *)
functor BenchNofibVeritasFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure C=BenchIdaFiniteFn(BenchNeed)
 type integer=int D.t
 type textNode=char F.node
 type text=char F.seq
 datatype binder=LambdaB|ForallB|ExistsB|PiB|SigmaB|ImpB|SubtypeB|DeltaB|ChooseB
 datatype unary=NotU
 datatype binary=OrB|AndB|EqualB|IsSubtypeB
 datatype constant=Truth|Falsehood|BoolType|Universe of integer
 datatype operatorType=Pre|Post|BinL|BinR
 datatype attributeTag=NameStyle|SymbolStyle|PairStyle|LetStyle|CaseStyle|OperatorStyle
   |FunStyle|BinderStyle|ConstantStyle|UnaryStyle|BinaryStyle|CondStyle|RecurseStyle
   |HypStyle|DecStyle|DefStyle|Comment
 datatype nameNode=Name of text|OperatorName of text*integer*operatorType
 type name=nameNode D.t
 datatype attributeValueNode=SymbolName of name|DatatypeName of nameNode F.seq
   |Named|Indexed|Typed|Untyped|LetValue|CaseValue|Prefixed|Linfixed|Rinfixed|Postfixed
   |Functional|Subscripted|PrefixBinder|InfixBinder|Recursive|FnValue|NonDependent
   |Grouped|Ungrouped|Parameter|NonParameter|StringValue of text
 type attribute=attributeTag*attributeValueNode D.t
 type attributes=attribute F.seq
 datatype tagArgType=TermArg|DerivArg|IntArg
 datatype itrNode=Sym of integer*integer*itrNode F.seq*attributes
   |App of itrNode D.t*itrNode D.t*itrNode F.seq*attributes
   |PairTerm of itrNode D.t*itrNode D.t*itrNode D.t*itrNode F.seq*attributes
   |Binder of binder*idecNode D.t*itrNode D.t*itrNode F.seq*attributes
   |Constant of constant*itrNode F.seq*attributes
   |Unary of unary*itrNode D.t*itrNode F.seq*attributes
   |Binary of binary*itrNode D.t*itrNode D.t*itrNode F.seq*attributes
   |Cond of idecNode D.t*itrNode D.t*itrNode D.t*itrNode F.seq*attributes
   |Const of integer*integer*integer*itrNode F.seq*attributes
   |Recurse of itrNode F.seq*itrNode D.t*itrNode F.seq*attributes
   |TagId of tagData D.t*tagArgNode F.seq|ITermError of text
 and idecNode=SymbolDec of itrNode D.t*attributes|AxiomDec of itrNode D.t*attributes
   |Def of itrNode D.t*itrNode D.t*attributes
   |Data of idecNode F.seq*itrNode F.node F.seq*attributes
   |DecPair of idecNode D.t*idecNode D.t*attributes
 and isgnNode=EmptySig of attributes|Extend of idecNode D.t*isgnNode D.t*attributes
   |Combine of isgnNode D.t*isgnNode D.t*integer*int F.seq*attributes
   |Share of isgnNode D.t*integer*integer*integer*int F.seq*attributes
 and tagArgNode=TagTerm of termNode D.t|TagTheorem of theoremNode D.t|TagInt of int F.seq
 and conversionNode=TermFunction of(tagArgNode F.seq->termNode D.t)
   |TheoremFunction of(tagArgNode F.seq->theoremNode D.t)
 and termNode=TM of itrNode D.t*itrNode D.t*isgnNode D.t|TermError of text
 and theoremNode=TH of itrNode D.t*isgnNode D.t|TheoremError of text
 withtype tagData=text*tagArgType F.seq*conversionNode F.seq
 type itr=itrNode D.t
 type idec=idecNode D.t
 type isgn=isgnNode D.t
 type term=termNode D.t
 type theorem=theoremNode D.t
 type tag=tagData D.t
 datatype signatureNode=SG of isgn|SignatureError of text
 datatype declarationNode=DC of idec*isgn|DeclarationError of text
 type signatureValue=signatureNode D.t
 type declaration=declarationNode D.t
 datatype flaggedNode=Operator of operatorNode D.t*operatorType*integer
   |Operand of operandNode D.t|ParseError of text
 and operandNode=ITerm of itr|IDec of idec|ISig of isgn|PartialApp of binder*idec*bool D.t
   |PairApp of itr|PartialInfix of binary*itr|TypeApp of flaggedNode D.t|PartialColon of itr
 and operatorNode=TermOperator of itr|BinderOperator of binder|InfixOperator of binary|SpecialOperator of text
 type flagged=flaggedNode D.t
 datatype tokenNode=Reserved of text|Clear of text|BinderToken of binder
   |InfixBinderToken of text|InfixOperatorToken of text|ScanError of text
 type token=tokenNode D.t
 type tokenStream=token C.seq

 datatype 'a optionNode=NoValue|SomeValue of 'a D.t
 datatype('a,'b)sumNode=InLeft of 'a D.t|InRight of 'b D.t
 datatype('a,'b)replyNode=Ok of 'a D.t|Bad of 'b D.t
 type lookupIndex=(integer*bool D.t,integer*integer*(integer*integer)F.seq)sumNode D.t
 type lookupEntry=(text*(lookupIndex*(integer*text)D.t)optionNode D.t)F.seq
 type lookupTable=lookupEntry F.node F.seq
 type globalState=integer*attributes*tagData F.seq
 datatype objectNode=TermSpec of itr|TheoremSpec of itr|SignatureSpec of isgn|DeclarationSpec of idec
 datatype doneNode=TermDone of term|TheoremDone of theorem|SignatureDone of signatureValue|DeclarationDone of declaration
 datatype goalNode=Goal of textNode optionNode D.t*textNode F.node optionNode D.t*
    textNode optionNode D.t*text*objectNode D.t*bool D.t*signatureValue*lookupTable
 datatype('a,'b,'c)treeNode=Tree of 'a D.t*('a,'b,'c)treeNode F.seq*'b optionNode D.t*
    ('c D.t->('a,'b,'c)treeNode D.t->('a,'b,'c)treeNode D.t)*
    ('a,'b,'c)treeNode optionNode D.t
 datatype('a,'b,'c)treeStateNode=TreeState of ('a,'b,'c)treeNode D.t*
    (integer*('a,'b,'c)treeNode D.t)F.seq*'c D.t
 type proofTree=(goalNode,doneNode,globalState)treeNode D.t
 type proofState=(goalNode,doneNode,globalState)treeStateNode D.t
 type xin=(text*integer C.seq*integer C.seq)L.delay
 datatype 'a actionReply=Success of 'a L.delay|Failure of text
 type 'a transaction=(xin*'a actionReply L.delay*text)L.delay
 type 'a action=xin->'a transaction
 type outputAction=xin->(xin*text)L.delay
 datatype subtermDataNode=SubtermData of int F.seq*integer*integer*subtermDataNode F.seq
 datatype formInputNode=SingleText of text*text|MultiText of text*text
   |Toggle of text*(text*bool D.t)F.seq|Radio of text*integer*textNode F.seq
   |FormComment of text|Subterm of text*subtermDataNode D.t
 datatype formOutputNode=OutText of text|OutToggle of textNode F.seq|OutRadio of text|OutSubterm of text
 fun force value=D.force value
 fun cell value=D.delay(fn()=>value)
 fun int(n:int)=cell n
 fun add a b=D.delay(fn()=>force a+force b)
 fun subtract a b=D.delay(fn()=>force a-force b)
 fun multiply a b=D.delay(fn()=>force a*force b)
 fun divide a b=D.delay(fn()=>force a div force b)
 fun modulo a b=D.delay(fn()=>force a mod force b)
 fun equalInt a b=force a=force b
 fun less a b=force a<force b
 fun leq a b=force a<=force b
 fun text s=F.fromList(String.explode s)
 fun string chars=String.implode(F.toList chars)
 fun head values=case force values of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail values=F.defer(fn()=>case force values of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null values=case force values of F.Nil=>true|_=>false
 fun singleton value=F.cons(value,F.empty())
 fun map function values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(D.delay(fn()=>force(function x)),map function rest))
 fun flatMap function values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(function x)(flatMap function rest))
 fun concat values=flatMap(fn x=>x)values
 fun pair a b=cell(a,b)
 fun triple a b c=cell(a,b,c)
 fun length values=D.delay(fn()=>let fun loop n values=case force values of F.Nil=>n|F.Cons(_,rest)=>loop(n+1)rest
    in loop 0 values end)
 fun foldLeft function initial values=D.delay(fn()=>
   let fun loop acc values=case force values of F.Nil=>force acc
        |F.Cons(x,rest)=>loop(D.delay(fn()=>force(function acc x)))rest
   in loop initial values end)
 fun foldRight function initial values=D.delay(fn()=>case force values of F.Nil=>force initial
   |F.Cons(x,rest)=>force(function x(foldRight function initial rest)))
 fun reverse values=F.defer(fn()=>let fun loop values acc=case force values of F.Nil=>acc
       |F.Cons(x,rest)=>loop rest(F.cons(x,acc))
    in loop values(F.empty())end)
 fun nth values index=case force values of F.Nil=>raise Subscript|F.Cons(x,rest)=>
    if equalInt index(int 0)then x else nth rest(subtract index(int 1))
 fun take count values=F.defer(fn()=>if leq count(int 0)then F.empty()else
    case force values of F.Nil=>F.empty()|F.Cons(x,rest)=>F.cons(x,take(subtract count(int 1))rest))
 fun drop count values=F.defer(fn()=>if leq count(int 0)then values else
    case force values of F.Nil=>F.empty()|F.Cons(_,rest)=>drop(subtract count(int 1))rest)
 fun all predicate values=case force values of F.Nil=>true|F.Cons(x,rest)=>predicate x andalso all predicate rest
 fun any predicate values=case force values of F.Nil=>false|F.Cons(x,rest)=>predicate x orelse any predicate rest
 fun equalLists equal left right=case(force left,force right)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xs),F.Cons(y,ys))=>equal x y andalso equalLists equal xs ys|_=>false
 fun equalText left right=equalLists(fn x=>fn y=>force x=force y)left right
 fun filter predicate values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,filter predicate rest)else filter predicate rest)
 fun zip function xs ys=F.defer(fn()=>case(force xs,force ys)of(F.Cons(x,xs),F.Cons(y,ys))=>
     F.cons(D.delay(fn()=>force(function x y)),zip function xs ys)|_=>F.empty())
 fun range lo hi=F.defer(fn()=>if less hi lo then F.empty()else F.cons(lo,range(add lo(int 1))hi))
 fun fromNative roots=List.foldr(fn(x,rest)=>F.cons(x,rest))(F.empty())roots
 fun textConcat values=concat(fromNative values)
 fun controlRange n=C.defer(fn()=>C.cons(L.delay(fn()=>n),controlRange(add n(int 1))))
 fun lookup equal key entries=D.delay(fn()=>case force entries of F.Nil=>NoValue
   |F.Cons(entry,rest)=>let val(k,v)=force entry in if equal key k then SomeValue v else force(lookup equal key rest)end)
 fun interleave separator values=F.defer(fn()=>case force values of F.Nil=>F.empty()|F.Cons(x,rest)=>
    if null rest then x else F.append x(F.append separator(interleave separator rest)))


 fun returnAction value xin=L.delay(fn()=>(xin,L.delay(fn()=>Success(L.delay value)),F.empty()))
 fun errorAction message xin=L.delay(fn()=>(xin,L.delay(fn()=>Failure message),F.empty()))
 fun forwardInput computation=L.delay(fn()=>let val(xin,_,_)=L.force computation in L.force xin end)
 fun actionValue computation=L.delay(fn()=>let val(_,reply,_)=L.force computation in L.force reply end)
 fun actionOutput computation=F.defer(fn()=>let val(_,_,out)=L.force computation in out end)
 fun outputInput computation=L.delay(fn()=>let val(xin,_)=L.force computation in L.force xin end)
 fun outputText computation=F.defer(fn()=>let val(_,out)=L.force computation in out end)
 fun sequenceOutput first second xin=L.delay(fn()=>
   let val one=first xin
       val two=second(outputInput one)
   in(outputInput two,F.append(outputText one)(outputText two))end)
 fun outputThenAction output action xin=L.delay(fn()=>
   let val one=output xin
       val two=action(outputInput one)
   in(forwardInput two,actionValue two,F.append(outputText one)(actionOutput two))end)
 fun bindTransaction computation next=L.delay(fn()=>
   let val nextComputation=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Success value=>L.force(next value input)
           |Failure message=>L.force(errorAction message input)end)
   in(forwardInput nextComputation,actionValue nextComputation,
       F.append(actionOutput computation)(actionOutput nextComputation))end)
 fun bindAction action next xin=bindTransaction(action xin)next
 fun pairTransactions computation next=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Failure message=>L.force(errorAction message input)
          |Success value=>
            let val second=next input
                val after=forwardInput second
                val reply=L.delay(fn()=>case L.force(actionValue second)of Failure message=>Failure message
                  |Success other=>Success(L.delay(fn()=>(value,other))))
            in(after,reply,actionOutput second)end end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun pairActions first second xin=pairTransactions(first xin)second
 fun listTransactions computation next=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Failure message=>L.force(errorAction message input)
          |Success value=>
            let val second=next input
                val after=forwardInput second
                val reply=L.delay(fn()=>case L.force(actionValue second)of Failure message=>Failure message
                  |Success others=>Success(L.delay(fn()=>C.cons(value,C.defer(fn()=>L.force others)))))
            in(after,reply,actionOutput second)end end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun listActions first second xin=listTransactions(first xin)second
 fun handleTransaction computation handler=L.delay(fn()=>
   let val future=L.delay(fn()=>
         let val(input,reply,_)=L.force computation
         in case L.force reply of Success value=>L.force(returnAction(fn()=>L.force value)input)
           |Failure message=>L.force(handler message input)end)
   in(forwardInput future,actionValue future,F.append(actionOutput computation)(actionOutput future))end)
 fun handleAction action handler xin=handleTransaction(action xin)handler
 fun outputActions actions xin=L.delay(fn()=>case force actions of F.Nil=>(xin,F.empty())
   |F.Cons(action,rest)=>L.force(sequenceOutput(force action)(outputActions rest)xin))
 fun splitList equal separator values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if equal separator x then F.cons(F.empty(),splitList equal separator rest)
     else case force(splitList equal separator rest)of F.Nil=>singleton(singleton x)
       |F.Cons(part,parts)=>F.cons(F.cons(x,part),parts))
 fun appendLast values value=F.append values(singleton value)
 fun generateUid xin=L.delay(fn()=>
   let val(input,responses,ids)=L.force xin
   in case L.force ids of C.Nil=>raise Match|C.Cons(number,rest)=>
      let val value=L.delay(fn()=>text(Int.toString(force(L.force number))))
          val input=L.delay(fn()=>(input,responses,rest))
      in(input,L.delay(fn()=>Success value),F.empty())end end)


 fun equalConstant left right=case(left,right)of
    (Truth,Truth)=>true|(Falsehood,Falsehood)=>true|(BoolType,BoolType)=>true
   |(Universe a,Universe b)=>equalInt a b|_=>false
 (* Source equality deliberately ignores alternative types and attributes. *)
 fun equalTerm left right=case(force left,force right)of
    (Sym(i,j,_,_),Sym(k,l,_,_))=>equalInt i k andalso equalInt j l
   |(App(a,b,_,_),App(c,d,_,_))=>equalTerm a c andalso equalTerm b d
   |(PairTerm(a,b,c,_,_),PairTerm(d,e,f,_,_))=>equalTerm a d andalso equalTerm b e andalso equalTerm c f
   |(Binder(a,b,c,_,_),Binder(d,e,f,_,_))=>a=d andalso equalDeclaration b e andalso equalTerm c f
   |(Constant(a,_,_),Constant(b,_,_))=>equalConstant a b
   |(Unary(a,b,_,_),Unary(c,d,_,_))=>a=c andalso equalTerm b d
   |(Binary(a,b,c,_,_),Binary(d,e,f,_,_))=>a=d andalso equalTerm b e andalso equalTerm c f
   |(Cond(a,b,c,_,_),Cond(d,e,f,_,_))=>equalDeclaration a d andalso equalTerm b e andalso equalTerm c f
   |(Const(a,b,c,_,_),Const(d,e,f,_,_))=>equalInt a d andalso equalInt b e andalso equalInt c f
   |(Recurse(xs,x,_,_),Recurse(ys,y,_,_))=>equalLists equalTerm xs ys andalso equalTerm x y
   |_=>false
 and equalDeclaration left right=case(force left,force right)of
    (SymbolDec(a,_),SymbolDec(b,_))=>equalTerm a b
   |(AxiomDec(a,_),AxiomDec(b,_))=>equalTerm a b
   |(Def(a,b,_),Def(c,d,_))=>equalTerm a c andalso equalTerm b d
   |(Data(ds,xs,_),Data(es,ys,_))=>equalLists equalDeclaration ds es andalso equalLists(equalLists equalTerm)xs ys
   |(DecPair(a,b,_),DecPair(c,d,_))=>equalDeclaration a c andalso equalDeclaration b d|_=>false
 and equalSignature left right=case(force left,force right)of
    (EmptySig _,EmptySig _)=>true
   |(Extend(a,b,_),Extend(c,d,_))=>equalDeclaration a c andalso equalSignature b d
   |(Combine(a,b,i,_,_),Combine(c,d,j,_,_))=>equalInt i j andalso equalSignature a c andalso equalSignature b d
   |(Share(a,i,j,k,_,_),Share(b,l,m,n,_,_))=>
       equalInt i l andalso equalInt j m andalso equalInt j m andalso equalSignature a b
   |_=>false
 fun selectTerm term indices=L.delay(fn()=>
   let fun termAt indices term declarations=case force indices of F.Nil=>(term,declarations)
         |F.Cons(index,rest)=>case force term of
            App(a,b,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |PairTerm(a,b,_,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |Binder(_,dec,body,_,_)=>if equalInt index(int 0)then decAt rest dec declarations
                else if equalInt index(int 1)then termAt rest body(F.cons(dec,declarations))else raise Match
           |Unary(_,body,_,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
           |Binary(_,a,b,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |Cond(dec,a,b,_,_)=>
                (case force dec of AxiomDec(body,info)=>
                  if equalInt index(int 0)then decAt rest dec declarations
                  else let val current=if equalInt index(int 1)then dec
                             else if equalInt index(int 2)then cell(AxiomDec(cell(Unary(NotU,body,F.empty(),info)),F.empty()))
                             else raise Fail"sel_trm"
                       in termAt rest(nth(fromNative[a,b])(subtract index(int 1)))(F.cons(current,declarations))end
                 |_=>raise Match)
           |Recurse(terms,_,_,_)=>termAt rest(nth terms index)declarations|_=>raise Match
       and decAt indices dec declarations=case force indices of F.Nil=>raise Match
         |F.Cons(index,rest)=>case force dec of
             SymbolDec(body,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
            |AxiomDec(body,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
            |DecPair(a,b,_)=>if equalInt index(int 0)then decAt rest a declarations
                 else if equalInt index(int 1)then decAt rest b(F.cons(a,declarations))else raise Match
            |_=>raise Match
   in termAt indices term(F.empty())end)

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


 fun replaceAt index values value=F.defer(fn()=>case force values of F.Nil=>raise Match
   |F.Cons(x,rest)=>if equalInt index(int 0)then F.cons(value,rest)
       else F.cons(x,replaceAt(subtract index(int 1))rest value))
 fun replaceTerm original indices replacement=
   let fun termAt indices term:itr=D.delay(fn()=>case force indices of F.Nil=>force replacement
        |F.Cons(index,rest)=>case force term of
           App(a,b,types,attrs)=>if equalInt index(int 0)then App(termAt rest a,b,types,attrs)
                else if equalInt index(int 1)then App(a,termAt rest b,types,attrs)else raise Match
          |PairTerm(a,b,c,types,attrs)=>if equalInt index(int 0)then PairTerm(termAt rest a,b,c,types,attrs)
                else if equalInt index(int 1)then PairTerm(a,termAt rest b,c,types,attrs)else raise Match
          |Binder(q,dec,body,types,attrs)=>if equalInt index(int 0)then Binder(q,decAt rest dec,body,types,attrs)
                else if equalInt index(int 1)then Binder(q,dec,termAt rest body,types,attrs)else raise Match
          |Unary(c,body,types,attrs)=>if equalInt index(int 0)then Unary(c,termAt rest body,types,attrs)else raise Match
          |Binary(c,a,b,types,attrs)=>if equalInt index(int 0)then Binary(c,termAt rest a,b,types,attrs)
                else if equalInt index(int 1)then Binary(c,a,termAt rest b,types,attrs)else raise Match
          |Cond(dec,a,b,types,attrs)=>if equalInt index(int 0)then Cond(decAt rest dec,a,b,types,attrs)
                else if equalInt index(int 1)then Cond(dec,termAt rest a,b,types,attrs)
                else if equalInt index(int 2)then Cond(dec,a,termAt rest b,types,attrs)else raise Match
          |Recurse(terms,body,types,attrs)=>Recurse(replaceAt index terms(termAt rest(nth terms index)),body,types,attrs)
          |_=>raise Fail("iL(len):"^Int.toString(force(length indices))^"\niL:"^
                  String.concat(List.map Int.toString(F.toList indices))^"|"))
       and decAt indices dec:idec=D.delay(fn()=>case force indices of F.Nil=>raise Match
         |F.Cons(index,rest)=>case force dec of
             SymbolDec(body,attrs)=>if equalInt index(int 0)then SymbolDec(termAt rest body,attrs)else raise Match
            |AxiomDec(body,attrs)=>if equalInt index(int 0)then AxiomDec(termAt rest body,attrs)else raise Match
            |DecPair(a,b,attrs)=>if equalInt index(int 0)then DecPair(decAt rest a,b,attrs)
                 else if equalInt index(int 1)then DecPair(a,decAt rest b,attrs)else raise Match
            |_=>raise Match)
   in termAt indices original end
 fun mapSymbols symbol constructor=
   let fun termAt n term:itr=D.delay(fn()=>case force term of
          Sym(i,j,types,attrs)=>if less i n then Sym(i,j,map(termAt n)types,attrs)
               else force(symbol n i j(map(termAt n)types)attrs)
         |Const(i,j,k,types,attrs)=>if less i n then Const(i,j,k,map(termAt n)types,attrs)
               else force(constructor n i j k(map(termAt n)types)attrs)
         |Constant(c,types,attrs)=>Constant(c,map(termAt n)types,attrs)
         |App(a,b,types,attrs)=>App(termAt n a,termAt n b,map(termAt n)types,attrs)
         |PairTerm(a,b,c,types,attrs)=>PairTerm(termAt n a,termAt n b,termAt n c,map(termAt n)types,attrs)
         |Binder(q,dec,body,types,attrs)=>Binder(q,decAt n dec,termAt(add n(int 1))body,map(termAt n)types,attrs)
         |Unary(c,body,types,attrs)=>Unary(c,termAt n body,map(termAt n)types,attrs)
         |Binary(c,a,b,types,attrs)=>Binary(c,termAt n a,termAt n b,map(termAt n)types,attrs)
         |Cond(dec,a,b,types,attrs)=>Cond(decAt n dec,termAt(add n(int 1))a,
               termAt(add n(int 1))b,map(termAt n)types,attrs)
         |Recurse(terms,body,types,attrs)=>Recurse(map(termAt n)terms,termAt n body,map(termAt n)types,attrs)
         |TagId _=>force term|ITermError _=>force term)
       and decAt n dec:idec=D.delay(fn()=>case force dec of
          SymbolDec(body,attrs)=>SymbolDec(termAt n body,attrs)
         |AxiomDec(body,attrs)=>AxiomDec(termAt n body,attrs)
         |DecPair(a,b,attrs)=>DecPair(decAt n a,decAt(add n(int 1))b,attrs)
         |Def(a,b,attrs)=>Def(termAt n a,termAt n b,attrs)
         |Data(declarations,terms,attrs)=>
            let val result=dataAt n declarations terms attrs
                val ds=F.defer(fn()=>let val(ds,_,_)=L.force result in ds end)
                val terms=F.defer(fn()=>let val(_,terms,_)=L.force result in terms end)
                val attrs=F.defer(fn()=>let val(_,_,attrs)=L.force result in attrs end)
            in Data(ds,terms,attrs)end)
       and dataAt n declarations terms attrs=L.delay(fn()=>case force declarations of
          F.Nil=>(F.empty(),map(map(termAt(add n(int 1))))terms,attrs)
         |F.Cons(dec,rest)=>
            let val following=dataAt(add n(int 1))rest terms attrs
                val terms=F.defer(fn()=>let val(_,terms,_)=L.force following in terms end)
                val attrs=F.defer(fn()=>let val(_,_,attrs)=L.force following in attrs end)
            (* Original keeps rest, not its separately computed dcL1. *)
            in(F.cons(decAt n dec,rest),terms,attrs)end)
   in(termAt(int 0),decAt(int 0))end
 fun nthSignature index signatureValue:isgn=D.delay(fn()=>if equalInt index(int 0)then force signatureValue
   else case force signatureValue of Extend(_,rest,_)=>force(nthSignature(subtract index(int 1))rest)
      |Combine(first,second,k,_,_)=>force(if less index k then nthSignature(subtract index(int 1))second
          else nthSignature(subtract(subtract index k)(int 1))first)
      |Share(rest,_,_,_,_,_)=>force(nthSignature(subtract index(int 1))rest)|_=>raise Match)
 fun nthDeclaration index signatureValue:idec=D.delay(fn()=>case force(nthSignature index signatureValue)of
     Extend(dec,_,_)=>force dec|_=>raise Match)
 fun signatureLength signatureValue:integer=D.delay(fn()=>case force signatureValue of EmptySig _=>0
    |Extend(_,rest,_)=>1+force(signatureLength rest)
    |Combine(first,_,k,_,_)=>1+force k+force(signatureLength first)
    |Share(rest,_,_,_,_,_)=>1+force(signatureLength rest))


 fun shareMap signatureValue=
   let fun shared signatureValue n=F.defer(fn()=>case force signatureValue of
         Share(_,_,_,_,indices,_)=>F.append(range(int 0)(subtract n(int 1)))(map(fn i=>D.delay(fn()=> ~(force i)))indices)
        |Combine(_,_,_,indices,_)=>F.append(range(int 0)(subtract n(int 1)))(map(fn i=>D.delay(fn()=> ~(force i)))indices)
        |EmptySig _=>range(int 0)(subtract n(int 1))
        |Extend(_,rest,_)=>shared rest(add n(int 1)))
   in shared signatureValue(int 0)end
 fun canonicalIndex indices index=D.delay(fn()=>force(if null indices then index else nth indices index))
 fun shareSymbol indices depth i j types attrs=cell(Sym(add depth(canonicalIndex indices(subtract i depth)),j,types,attrs))
 fun shareConstructor indices depth i j k types attrs=cell(Const(add depth(canonicalIndex indices(subtract i depth)),j,k,types,attrs))
 fun shiftSymbol indices offset depth i j types attrs=shareSymbol indices depth(add i offset)j types attrs
 fun shiftConstructor indices offset depth i j k types attrs=shareConstructor indices depth(add i offset)j k types attrs
 fun shareTerm indices term=
   let val(terms,_)=mapSymbols(shareSymbol indices)(shareConstructor indices)in terms term end
 fun shiftTerm indices offset term=
   let val(terms,_)=mapSymbols(shiftSymbol indices offset)(shiftConstructor indices offset)in terms term end
 fun shiftDeclaration indices offset dec=
   let val(_,decs)=mapSymbols(shiftSymbol indices offset)(shiftConstructor indices offset)in decs dec end
 fun substitutionTable index dec term=L.delay(fn()=>case(force dec,force term)of
    (DecPair(a,b,_),PairTerm(x,y,_,_,_))=>
       let val first=substitutionTable(add index(int 1))a x
           val firstIndex=D.delay(fn()=>force(#1(L.force first)))
           val firstTable=F.defer(fn()=> #2(L.force first))
           val second=substitutionTable(add firstIndex(int 1))b y
           val finalIndex=D.delay(fn()=>force(#1(L.force second)))
           val secondTable=F.defer(fn()=> #2(L.force second))
       in(finalIndex,F.append firstTable secondTable)end
   |(SymbolDec _,_)=>(index,singleton(pair index term))|_=>raise Match)
 fun substituteSymbol table depth i j types attrs:itr=D.delay(fn()=>
    if equalInt i depth then case force(lookup equalInt j table)of SomeValue term=>force(shiftTerm(F.empty())depth term)|_=>raise Match
    else Sym(subtract i(int 1),j,types,attrs))
 fun substituteConstructor depth i j k types attrs=cell(Const(subtract i(int 1),j,k,types,attrs))
 fun substituteTerm dec original replacement=
   let val result=substitutionTable(int 0)dec replacement
       val table=F.defer(fn()=> #2(L.force result))
       val(terms,_)=mapSymbols(substituteSymbol table)substituteConstructor
   in terms original end
 fun substituteDeclaration first second replacement=
   let val result=substitutionTable(int 0)first replacement
       val table=F.defer(fn()=> #2(L.force result))
       val(_,decs)=mapSymbols(substituteSymbol table)substituteConstructor
   in decs second end
 fun extractionIndices declaration index=
   let fun extract index dec j path stack=F.defer(fn()=>if equalInt index(int 0)then path
        else case force dec of DecPair(a,b,_)=>extract(subtract index(int 1))a(add j(int 1))path
              (F.cons(pair b(F.cons(add j(int 1),path)),stack))
          |_=>case force stack of F.Cons(entry,rest)=>let val(next,path)=force entry
              in extract(subtract index(int 1))next(add j(int 1))path rest end|_=>raise Match)
   in extract index declaration(int 0)(F.empty())(F.empty())end
 fun uncurrySymbol indices decDepth localDepth i j types attrs=
   if less(subtract i localDepth)decDepth then cell(Sym(localDepth,add j(nth indices i),types,attrs))
     else cell(Sym(add(subtract i decDepth)(int 1),j,types,attrs))
 fun uncurryConstructor indices decDepth localDepth i j k types attrs=
   if less(subtract i localDepth)decDepth then cell(Const(localDepth,add j(nth indices i),k,types,attrs))
     else cell(Const(add(subtract i decDepth)(int 1),j,k,types,attrs))
 fun uncurryTerm dec index term=
   let val indices=extractionIndices dec index
       val depth=length indices
       val(terms,_)=mapSymbols(uncurrySymbol indices depth)(uncurryConstructor indices depth)
   in terms term end
 fun extractDeclaration index dec:idec=D.delay(fn()=>
   let fun extract index dec stack=case force dec of
          DecPair(a,b,_)=>extract(subtract index(int 1))a(F.cons(b,stack))
         |_=>if equalInt index(int 0)then force dec else case force stack of F.Cons(next,rest)=>
             extract(subtract index(int 1))next rest|_=>raise Match
   in extract index dec(F.empty())end)
 fun remakeType original path replacement:itr=D.delay(fn()=>case force original of Binder(q,dec,body,types,attrs)=>
   (case force path of F.Nil=>force(substituteTerm dec body replacement)
     |F.Cons(_,rest)=>Binder(q,dec,remakeType body rest replacement,types,attrs))|_=>raise Match)
 fun isSymbolDeclaration dec=case force dec of SymbolDec _=>true
   |DecPair(a,b,_)=>isSymbolDeclaration a andalso isSymbolDeclaration b|_=>false
 fun isAxiomDeclaration dec=case force dec of AxiomDec _=>true
   |DecPair(a,b,_)=>isAxiomDeclaration a andalso isAxiomDeclaration b|_=>false
 fun isDefinitionDeclaration dec=case force dec of Def _=>true
   |DecPair(a,b,_)=>isDefinitionDeclaration a andalso isDefinitionDeclaration b|_=>false
 fun declarationType dec:itr=D.delay(fn()=>case force dec of
    SymbolDec(body,_)=>force body|AxiomDec(body,_)=>force body
   |DecPair(a,b,_)=>if isSymbolDeclaration dec then Binder(SigmaB,a,declarationType b,F.empty(),F.empty())
        else if isAxiomDeclaration dec then Binary(AndB,declarationType a,
             shiftTerm(F.empty())(int ~1)(declarationType b),F.empty(),F.empty())
        else Sym(int 0,int 0,F.empty(),F.empty())|_=>raise Match)
 fun makePi dec term=cell(Binder(PiB,dec,term,F.empty(),F.empty()))
 fun functionSpace first second=cell(Binder(PiB,cell(SymbolDec(first,F.empty())),
      shiftTerm(F.empty())(int 1)second,F.empty(),F.empty()))
 fun makeSymbols dec i j=L.delay(fn()=>case force dec of
    SymbolDec _=>(cell(Sym(i,j,F.empty(),F.empty())),add j(int 1))
   |DecPair(a,b,_)=>let val first=makeSymbols a i(add j(int 1))
        val term1=D.delay(fn()=>force(#1(L.force first)))
        val next1=D.delay(fn()=>force(#2(L.force first)))
        val second=makeSymbols b i next1
        val term2=D.delay(fn()=>force(#1(L.force second)))
        val next2=D.delay(fn()=>force(#2(L.force second)))
     in(cell(PairTerm(term1,term2,declarationType dec,F.empty(),F.empty())),next2)end
   |_=>raise Match)
 fun makeSymbolList declarations index terms=F.defer(fn()=>case force declarations of F.Nil=>terms
   |F.Cons(dec,rest)=>
      let val result=makeSymbols dec index(int 0)
          val term=D.delay(fn()=>force(#1(L.force result)))
      in makeSymbolList rest(add index(int 1))(F.cons(term,terms))end)


 fun selectSymbolType symbol signatureValue i j:itr=D.delay(fn()=>
   let val dec=nthDeclaration i signatureValue
       fun wrong()=raise Fail("select: "^(if symbol then"True"else"False")^
           Int.toString(force i)^Int.toString(force j)^"|\n")
   in case force(extractDeclaration j dec)of
       SymbolDec(body,_)=>if symbol then force(uncurryTerm dec j body)else wrong()
      |AxiomDec(body,_)=>if not symbol then force(uncurryTerm dec j body)else wrong()
      |Def(body,ty,_)=>if symbol then force(uncurryTerm dec j ty)
          else Binary(EqualB,cell(Sym(int 0,j,F.empty(),F.empty())),uncurryTerm dec j body,F.empty(),F.empty())
      |_=>wrong()end)
 (* The pinned source's constructor-type implementation is this stub. *)
 fun selectConstructorType signatureValue i j k=cell(Sym(int 0,int 0,F.empty(),F.empty()))
 fun symbolType signatureValue i j=shiftTerm(shareMap signatureValue)i(selectSymbolType true signatureValue i j)
 fun constructorType signatureValue i j k=shiftTerm(shareMap signatureValue)i(selectConstructorType signatureValue i j k)
 fun axiomType signatureValue i j=shiftTerm(shareMap signatureValue)i(selectSymbolType false signatureValue i j)
 fun otherTypes term=F.defer(fn()=>case force term of
    Sym(_,_,types,_)=>types|App(_,_,types,_)=>types|PairTerm(_,_,_,types,_)=>types|Const(_,_,_,types,_)=>types
   |Binder(_,_,_,types,_)=>types|Unary(_,_,types,_)=>types|Binary(_,_,_,types,_)=>types|Cond(_,_,_,types,_)=>types
   |Constant(_,types,_)=>types|Recurse(_,_,types,_)=>types|_=>raise Match)
 fun termType signatureValue term:itr=D.delay(fn()=>case force(otherTypes term)of
    F.Nil=>force(naturalType signatureValue term)|F.Cons(ty,_)=>force ty)
 and naturalType signatureValue term:itr=D.delay(fn()=>case force term of
    Sym(i,j,_,_)=>force(symbolType signatureValue i j)
   |Const(i,j,k,_,_)=>force(constructorType signatureValue i j k)
   |App(first,second,_,_)=>
      let val ty=termType signatureValue first
          fun result ty=case force ty of Binder(PiB,dec,body,_,_)=>force(substituteTerm dec body second)|_=>raise Match
      in case force ty of Binder(PiB,_,_,_,_)=>result ty|_=>result(naturalType signatureValue first)end
   |PairTerm(_,_,ty,_,_)=>force ty
   |Binder(kind,dec,body,_,_)=>force(binderType signatureValue kind dec body)
   |Constant(kind,_,_)=>force(constantType kind)
   |Recurse(_,ty,_,_)=>force ty|_=>Constant(BoolType,F.empty(),F.empty()))
 and binderType signatureValue kind dec body:itr=D.delay(fn()=>case kind of
    ForallB=>Constant(BoolType,F.empty(),F.empty())
   |ExistsB=>Constant(BoolType,F.empty(),F.empty())
   |ImpB=>Constant(BoolType,F.empty(),F.empty())
   |PiB=>force(productType signatureValue dec body)
   |SigmaB=>force(productType signatureValue dec body)
   |SubtypeB=>Constant(Universe(int 0),F.empty(),F.empty())
   |LambdaB=>Binder(PiB,dec,termType(cell(Extend(dec,signatureValue,F.empty())))body,F.empty(),F.empty())
   |ChooseB=>Binder(SubtypeB,dec,body,F.empty(),F.empty())|_=>raise Match)
 and productType signatureValue dec body:itr=D.delay(fn()=>
   let val extended=cell(Extend(dec,signatureValue,F.empty()))
       val first=termType extended body
       val second=termType signatureValue(declarationType dec)
       val i=case force first of Constant(Universe i,_,_)=>i|_=>raise Match
       val j=case force second of Constant(Universe j,_,_)=>j|_=>raise Match
   in Constant(Universe(D.delay(fn()=>Int.max(force i,force j))),F.empty(),F.empty())end)
 and constantType kind:itr=D.delay(fn()=>case kind of
    Truth=>Constant(BoolType,F.empty(),F.empty())|Falsehood=>Constant(BoolType,F.empty(),F.empty())
   |BoolType=>Constant(Universe(int 0),F.empty(),F.empty())
   |Universe i=>Constant(Universe(add i(int 1)),F.empty(),F.empty()))
 fun evaluateProposition term=case force term of
    Constant(Truth,_,_)=>true|Constant(Falsehood,_,_)=>false
   |Binder(ForallB,dec,body,_,_)=>evaluateQuantifier true dec body
   |Binder(ExistsB,dec,body,_,_)=>evaluateQuantifier false dec body
   |Binder(ImpB,dec,body,_,_)=>not(evaluateProposition(declarationType dec))orelse evaluateProposition body
   |Binary(AndB,a,b,_,_)=>evaluateProposition a andalso evaluateProposition b
   |Binary(OrB,a,b,_,_)=>evaluateProposition a orelse evaluateProposition b
   |Binary(EqualB,a,b,_,_)=>evaluateProposition a=evaluateProposition b
   |Unary(NotU,body,_,_)=>not(evaluateProposition body)
   |Cond(dec,first,_,_,_)=>
        evaluateProposition(substituteTerm dec first(cell(Constant(Truth,F.empty(),F.empty()))))andalso
        evaluateProposition(substituteTerm dec first(cell(Constant(Falsehood,F.empty(),F.empty()))))
   |_=>raise Match
 and evaluateQuantifier universal dec body=
   let fun predicate value=evaluateProposition(substituteTerm dec body value)
   in if universal then all predicate(truthTable dec)else any predicate(truthTable dec)end
 and truthTable dec=F.defer(fn()=>case force dec of
    SymbolDec(body,_)=>(case force body of Constant(BoolType,_,_)=>
       F.fromList[Constant(Truth,F.empty(),F.empty()),Constant(Falsehood,F.empty(),F.empty())]|_=>raise Match)
   |DecPair(a,b,_)=>truthPairs(truthTable a)(truthTable b)|_=>raise Match)
 and truthPairs first second=F.defer(fn()=>case force first of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(map(fn y=>cell(PairTerm(x,y,cell(Constant(BoolType,F.empty(),F.empty())),F.empty(),F.empty())))second)
       (truthPairs rest second))
 fun occurs level term=case force term of Sym(i,_,_,_)=>equalInt level i
   |App(a,b,_,_)=>occurs level a orelse occurs level b
   |PairTerm(a,b,c,_,_)=>occurs level a orelse occurs level b orelse occurs level c
   |Binder(_,dec,body,_,_)=>occursDeclaration level dec orelse occurs(add level(int 1))body
   |Unary(_,body,_,_)=>occurs level body
   |Binary(_,a,b,_,_)=>occurs level a orelse occurs level b
   |Cond(dec,a,b,_,_)=>occursDeclaration level dec orelse occurs(add level(int 1))a orelse occurs(add level(int 1))b
   |Recurse(terms,body,_,_)=>any(occurs level)terms orelse occurs level body|_=>false
 and occursDeclaration level dec=case force dec of SymbolDec(body,_)=>occurs level body
   |AxiomDec(body,_)=>occurs level body|DecPair(a,b,_)=>occursDeclaration level a orelse occursDeclaration(add level(int 1))b
   |_=>raise Match

 fun termAttributes term=F.defer(fn()=>case force term of
    Sym(i,j,types,attrs)=>attrs
   |App(a,b,types,attrs)=>attrs
   |PairTerm(a,b,c,types,attrs)=>attrs
   |Constant(kind,types,attrs)=>attrs
   |Binder(kind,dec,body,types,attrs)=>attrs
   |Unary(kind,body,types,attrs)=>attrs
   |Binary(kind,a,b,types,attrs)=>attrs
   |Cond(dec,a,b,types,attrs)=>attrs
   |Const(i,j,k,types,attrs)=>attrs
   |Recurse(terms,body,types,attrs)=>attrs|_=>raise Match)
 fun replaceAttributes term attrs:itr=D.delay(fn()=>case force term of
    Sym(i,j,types,_)=>Sym(i,j,types,attrs)
   |App(a,b,types,_)=>App(a,b,types,attrs)
   |PairTerm(a,b,c,types,_)=>PairTerm(a,b,c,types,attrs)
   |Constant(kind,types,_)=>Constant(kind,types,attrs)
   |Binder(kind,dec,body,types,_)=>Binder(kind,dec,body,types,attrs)
   |Unary(kind,body,types,_)=>Unary(kind,body,types,attrs)
   |Binary(kind,a,b,types,_)=>Binary(kind,a,b,types,attrs)
   |Cond(dec,a,b,types,_)=>Cond(dec,a,b,types,attrs)
   |Const(i,j,k,types,_)=>Const(i,j,k,types,attrs)
   |Recurse(terms,body,types,_)=>Recurse(terms,body,types,attrs)|_=>raise Match)
 fun addType term ty:itr=D.delay(fn()=>case force term of
    Sym(i,j,types,attrs)=>Sym(i,j,F.cons(ty,types),attrs)
   |App(a,b,types,attrs)=>App(a,b,F.cons(ty,types),attrs)
   |PairTerm(a,b,c,types,attrs)=>PairTerm(a,b,c,F.cons(ty,types),attrs)
   |Constant(kind,types,attrs)=>Constant(kind,F.cons(ty,types),attrs)
   |Binder(kind,dec,body,types,attrs)=>Binder(kind,dec,body,F.cons(ty,types),attrs)
   |Unary(kind,body,types,attrs)=>Unary(kind,body,F.cons(ty,types),attrs)
   |Binary(kind,a,b,types,attrs)=>Binary(kind,a,b,F.cons(ty,types),attrs)
   |Cond(dec,a,b,types,attrs)=>Cond(dec,a,b,F.cons(ty,types),attrs)
   |Const(i,j,k,types,attrs)=>Const(i,j,k,F.cons(ty,types),attrs)
   |Recurse(terms,body,types,attrs)=>Recurse(terms,body,F.cons(ty,types),attrs)|_=>raise Match)

 fun getTermAttributes term indices=
   let val selected=selectTerm term indices
       val selectedTerm=D.delay(fn()=>force(#1(L.force selected)))
   in termAttributes selectedTerm end
 fun setTermAttributes term indices attributes=
   let val selected=selectTerm term indices
       val subterm=D.delay(fn()=>force(#1(L.force selected)))
   in replaceTerm term indices(replaceAttributes subterm attributes)end
 fun declarationAttributes dec=F.defer(fn()=>case force dec of
    SymbolDec(_,attrs)=>attrs|AxiomDec(_,attrs)=>attrs|Def(_,_,attrs)=>attrs|Data(_,_,attrs)=>attrs|DecPair(_,_,attrs)=>attrs)
 fun setDeclarationAttributes dec attrs:idec=D.delay(fn()=>case force dec of
    SymbolDec(term,_)=>SymbolDec(term,attrs)|AxiomDec(term,_)=>AxiomDec(term,attrs)
   |Def(a,b,_)=>Def(a,b,attrs)|Data(decs,terms,_)=>Data(decs,terms,attrs)|DecPair(a,b,_)=>DecPair(a,b,attrs))
 fun signatureAttributes signatureValue=F.defer(fn()=>case force signatureValue of
    EmptySig attrs=>attrs|Extend(_,_,attrs)=>attrs|Combine(_,_,_,_,attrs)=>attrs|Share(_,_,_,_,_,attrs)=>attrs)
 fun setSignatureAttributes signatureValue attrs:isgn=D.delay(fn()=>case force signatureValue of
    EmptySig _=>EmptySig attrs|Extend(dec,sg,_)=>Extend(dec,sg,attrs)
   |Combine(a,b,k,map,_)=>Combine(a,b,k,map,attrs)|Share(sg,i,j,k,map,_)=>Share(sg,i,j,k,map,attrs))
 fun subSignature first second=
   let fun sub index signatureValue=D.delay(fn()=>if equalSignature first signatureValue then SomeValue index
         else case force signatureValue of EmptySig _=>NoValue
          |Extend(_,rest,_)=>force(sub(add index(int 1))rest)
          |Combine(a,b,k,_,_)=>(case force(sub index b)of SomeValue found=>SomeValue found|NoValue=>force(sub(add index k)a))
          |Share(rest,_,_,_,_,_)=>force(sub index rest))
   in sub(int 0)second end


 fun foldRightOne function values=D.delay(fn()=>case force values of F.Nil=>raise Empty
   |F.Cons(x,rest)=>force(if null rest then x else function x(foldRightOne function rest)))
 fun iterate count function value=if equalInt count(int 0)then value
   else iterate(subtract count(int 1))function(function value)
 fun makeApplication first second=cell(App(first,second,F.empty(),F.empty()))
 fun etaMatch dec term index=raise Fail"VTS_ERROR"
 fun makeRecursive functionType clauseType recursiveTypes:itr=D.delay(fn()=>case force recursiveTypes of F.Nil=>force clauseType
   |F.Cons(ty,rest)=>case force functionType of Binder(PiB,dec,body,_,_)=>
        let val result=makeRecursive(shiftTerm(F.empty())(int 1)functionType)(shiftTerm(F.empty())(int 1)clauseType)rest
            val argument=substituteTerm dec body ty
        in Binder(PiB,cell(SymbolDec(argument,F.empty())),result,F.empty(),F.empty())end|_=>raise Match)
 fun generateType index functionType recursiveTypes constructor types:itr=D.delay(fn()=>case force functionType of
    Binder(PiB,dec,body,_,_)=>(case force types of F.Nil=>
        force(makeRecursive functionType(substituteTerm dec body constructor)recursiveTypes)
      |F.Cons(ty,rest)=>
        let val applied=makeApplication(shiftTerm(F.empty())(int 1)constructor)(cell(Sym(int 0,int 0,F.empty(),F.empty())))
            val fnType=shiftTerm(F.empty())(int 1)functionType
            val shifted=map(shiftTerm(F.empty())(int 1))recursiveTypes
            val recursive=F.defer(fn()=>if equalTerm ty(cell(Sym(int 0,int 0,F.empty(),F.empty())))
               then F.append shifted(singleton(cell(Sym(index,int 1,F.empty(),F.empty()))))else shifted)
            val result=generateType(add index(int 1))fnType recursive applied rest
            val argument=shiftTerm(F.empty())index ty
        in Binder(PiB,cell(SymbolDec(argument,F.empty())),result,F.empty(),F.empty())end)
   |_=>raise Match)
 fun generateTypeList parameters dataType functionType rows i j k=F.defer(fn()=>case force rows of F.Nil=>F.empty()
   |F.Cons(types,rest)=>
      let val constructor=foldRight makeApplication(cell(Const(i,j,k,F.empty(),F.empty())))(reverse parameters)
          val ty=generateType(int 0)functionType(F.empty())constructor types
          val dec=cell(SymbolDec(dataType,F.empty()))
          fun substituteParameters index term parameters:itr=D.delay(fn()=>case force parameters of F.Nil=>force term
            |F.Cons(parameter,rest)=>force(substituteParameters(subtract index(int 1))
                 (substituteTerm dec term(shiftTerm(F.empty())index parameter))rest))
          val result=substituteParameters(subtract(length parameters)(int 1))(substituteTerm dec ty dataType)parameters
      in F.cons(result,generateTypeList parameters dataType functionType rest i j(add k(int 1)))end)
 fun datatypeInformation signatureValue term=L.delay(fn()=>case force term of
    App(first,second,_,_)=>let val result=datatypeInformation signatureValue first
         val(i,j,parameters,declarations,types)=L.force result
       in(i,j,F.cons(second,parameters),declarations,types)end
   |Const(i,j,k,_,_)=>
      let val dec=extractDeclaration j(nthDeclaration i signatureValue)
      in case force(shiftDeclaration(shareMap signatureValue)i dec)of
          Data(declarations,types,_)=> (i,j,F.empty(),declarations,types)|_=>raise Match end
   |_=>raise Match)
 fun parameterCount types:integer=D.delay(fn()=>case force types of F.Nil=>0
   |F.Cons(term,rest)=>(case force term of Sym _=>2+force(parameterCount rest)|_=>force(parameterCount rest)))
 fun shiftUnder depth offset term=
   let fun bind term=cell(Binder(PiB,cell(SymbolDec(cell(Sym(int 0,int 0,F.empty(),F.empty())),F.empty())),
            term,F.empty(),F.empty()))
       fun body term:itr=D.delay(fn()=>case force term of Binder(_,_,body,_,_)=>force body|_=>raise Match)
   in iterate depth body(shiftTerm(F.empty())offset(iterate depth bind term))end
 fun clauseTypes signatureValue dataType functionType=L.delay(fn()=>
   let val(i,j,parameters,declarations,types)=L.force(datatypeInformation signatureValue dataType)
       val functionType=shiftTerm(F.empty())(add(length declarations)(int 1))functionType
       val dataType=shiftTerm(F.empty())(length declarations)dataType
       val shifted=map(map(shiftUnder(add(length declarations)(int 1))j))types
       val clauses=generateTypeList parameters dataType functionType shifted i j(int 0)
       val counts=map parameterCount types
   in(clauses,counts)end)
 fun makeInduction term recursiveType recursiveTypes:itr=D.delay(fn()=>case force recursiveTypes of F.Nil=>force recursiveType
   |F.Cons(ty,rest)=>
      let val result=makeInduction term recursiveType rest
          val dec=cell(SymbolDec(makeApplication term ty,F.empty()))
      in Binder(ImpB,dec,result,F.empty(),F.empty())end)
 fun inductionType index term recursiveTypes constructor types:itr=D.delay(fn()=>case force types of
    F.Nil=>force(makeInduction term(makeApplication term constructor)recursiveTypes)
   |F.Cons(ty,rest)=>
      let val constructor=makeApplication(shiftTerm(F.empty())(int 1)constructor)(cell(Sym(int 0,int 0,F.empty(),F.empty())))
          val term=shiftTerm(F.empty())(int 1)term
          val shifted=map(shiftTerm(F.empty())(int 1))recursiveTypes
          val recursive=F.defer(fn()=>if equalTerm ty(cell(Sym(int 0,int 0,F.empty(),F.empty())))
              then F.append shifted(singleton ty)else shifted)
          val result=inductionType(add index(int 1))term recursive constructor rest
          val dec=cell(SymbolDec(shiftTerm(F.empty())index ty,F.empty()))
      in Binder(ForallB,dec,result,F.empty(),F.empty())end)
 fun inductionTypeList recursiveType symbols term types i j k=F.defer(fn()=>case force types of F.Nil=>F.empty()
   |F.Cons(arguments,rest)=>
      let val constructor=foldRight makeApplication(cell(Const(i,j,k,F.empty(),F.empty())))(reverse symbols)
          val initial=inductionType(int 0)term(F.empty())constructor arguments
          val dec=cell(SymbolDec(cell(Const(i,j,int 0,F.empty(),F.empty())),F.empty()))
          val result=substituteTerm dec initial recursiveType
      in F.cons(result,inductionTypeList recursiveType symbols term rest i j(add k(int 1)))end)
 fun inductionTerm signatureValue term:itr=D.delay(fn()=>
   let val(i,j,_,declarations,types)=L.force(datatypeInformation signatureValue term)
       val shiftedTypes=map(map(shiftUnder(int 1)(int 1)))types
       val symbols=makeSymbolList declarations(int 0)(F.empty())
       val dataType=foldRight makeApplication(shiftTerm(F.empty())(length declarations)term)(reverse symbols)
       val ty=cell(Binder(PiB,cell(SymbolDec(dataType,F.empty())),cell(Constant(BoolType,F.empty(),F.empty())),F.empty(),F.empty()))
       val dec=cell(SymbolDec(ty,F.empty()))
       val shiftedDatatype=shiftTerm(F.empty())(int 1)dataType
       val shiftedSymbols=map(shiftTerm(F.empty())(int 2))symbols
       val clauses=inductionTypeList shiftedDatatype shiftedSymbols(cell(Sym(int 1,int 0,F.empty(),F.empty())))
            shiftedTypes(add(add(int 2)i)(length declarations))j(int 1)
       val application=makeApplication(cell(Sym(int 1,int 0,F.empty(),F.empty())))(cell(Sym(int 0,int 0,F.empty(),F.empty())))
       val all=cell(Binder(ForallB,cell(SymbolDec(shiftedDatatype,F.empty())),application,F.empty(),F.empty()))
       val implicationDec=cell(SymbolDec(all,F.empty()))
       fun imply first second=cell(Binder(ImpB,implicationDec,second,F.empty(),F.empty()))
       val body=foldRightOne imply(F.append clauses(singleton all))
       fun forall dec term=cell(Binder(ForallB,dec,term,F.empty(),F.empty()))
   in force(foldRight forall body(reverse(F.cons(dec,declarations))))end)
 fun equivalentIndices equal value values=
   let fun loop index values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>if equal x value then F.cons(index,loop(add index(int 1))rest)
             else loop(add index(int 1))rest)
   in loop(int 0)values end
 fun union equal first second=F.defer(fn()=>case force first of F.Nil=>second
   |F.Cons(x,rest)=>if any(equal x)second then union equal rest second else F.cons(x,union equal rest second))
 fun updateIndices value indices values=
   let fun loop index values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>F.cons(if any(equalInt index)indices then value else x,loop(add index(int 1))rest))
   in loop(int 0)values end
 fun addEquivalence pairValue values=
   let val(i,j)=force pairValue
       val left=nth values i val right=nth values j
       val matches=union equalInt(equivalentIndices equalInt left values)(equivalentIndices equalInt right values)
       val value=D.delay(fn()=>Int.min(force left,force right))
   in updateIndices value matches values end
 fun addEquivalenceRange i j count values=
   let fun pairs i j count=F.defer(fn()=>if equalInt count(int 0)then F.empty()
          else F.cons(pair i j,pairs(add i(int 1))(add j(int 1))(subtract count(int 1))))
   in foldRight addEquivalence values(pairs i j count)end
 fun splitDefinition dec=L.delay(fn()=>case force dec of Def(term,ty,_)=>
      (cell(SymbolDec(ty,F.empty())),term,ty)
   |DecPair(a,b,_)=>
      let val first=splitDefinition a val second=splitDefinition b
          val(dec1,term1,_)=L.force first
          val(dec2,term2,type2)=L.force second
          val ty=shiftTerm(F.empty())(int 1)(substituteTerm a type2 term1)
          val term=substituteTerm a term2 term1
      in(cell(DecPair(dec1,dec2,F.empty())),cell(PairTerm(term1,term,ty,F.empty(),F.empty())),ty)end
   |_=>raise Match)


 fun termError message=cell(TermError(text message))
 fun theoremError message=cell(TheoremError(text message))
 fun signatureError message=cell(SignatureError(text message))
 fun declarationError message=cell(DeclarationError(text message))
 fun bareConstant kind=cell(Constant(kind,F.empty(),F.empty()))
 fun bareBinder kind dec body=cell(Binder(kind,dec,body,F.empty(),F.empty()))
 fun bareBinary kind first second=cell(Binary(kind,first,second,F.empty(),F.empty()))
 fun symbol signatureValue i j:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TM(cell(Sym(i,j,F.empty(),F.empty())),symbolType sg i j,sg)
       else force(termError"Malformed symbol")|_=>raise Match)
 fun universe signatureValue index:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if leq(int 0)index then TM(bareConstant(Universe index),bareConstant(Universe(add index(int 1))),sg)
       else force(termError"Malformed Universe")|_=>raise Match)
 fun piFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(Universe i,_,_),Extend(dec,parent,_))=>
        (case force(termType parent(declarationType dec))of Constant(Universe j,_,_)=>
           TM(bareBinder PiB dec body,bareConstant(Universe(D.delay(fn()=>Int.max(force i,force j)))),parent)
          |_=>force(termError"Malformed pi expression"))
      |_=>force(termError"Sort of pi exression is not a universe"))
   |_=>force(termError"Sort of pi exression is not a universe"))
 fun lambdaFormation term:term=D.delay(fn()=>case force term of TermError _=>force term
   |TM(body,ty,sg)=>(case force sg of Extend(dec,parent,_)=>if isSymbolDeclaration dec then
        TM(bareBinder LambdaB dec body,bareBinder PiB dec ty,parent)else force(termError"lambda: invalid declaration")
       |_=>force(termError"Malformed lambda expression")))
 fun application first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(f,ty,sg1),TM(argument,argType,sg2))=>(case force ty of Binder(PiB,dec,body,_,_)=>
         if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)argType then
           TM(makeApplication f argument,substituteTerm dec body argument,sg1)else force(termError"Malformed application")
       |_=>force(termError"Malformed application (2)"))
   |_=>force(termError"Malformed application (2)"))
 fun sigmaFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(Universe i,_,_),Extend(dec,parent,_))=>
        (case force(termType parent(declarationType dec))of Constant(Universe j,_,_)=>
           TM(bareBinder SigmaB dec body,bareConstant(Universe(D.delay(fn()=>Int.max(force i,force j)))),parent)
          |_=>force(termError"Malformed sigma"))
      |_=>force(termError"Malformed sigma (2)"))
   |_=>force(termError"Malformed sigma (2)"))
 fun pairFormation first second pairType:term=D.delay(fn()=>case(force first,force second,force pairType)of
    (TM(a,aType,sg1),TM(b,bType,sg2),TM(ty,_,sg3))=>(case force ty of Binder(SigmaB,dec,result,_,_)=>
      if equalSignature sg1 sg2 andalso equalSignature sg2 sg3 andalso equalTerm aType(declarationType dec)
         andalso equalTerm bType(substituteTerm dec result a)then TM(cell(PairTerm(a,b,ty,F.empty(),F.empty())),ty,sg1)
      else force(termError"Malformed pair")|_=>force(termError"Malformed pair (2)"))
   |_=>force(termError"Malformed pair (2)"))
 fun subtypeFormation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
        if equalTerm(termType parent(declarationType dec))(bareConstant(Universe(int 0)))
           then TM(bareBinder SubtypeB dec body,bareConstant(Universe(int 0)),parent)
           else force(termError"Malformed subtype")|_=>force(termError"Malformed subtype (2)"))
   |_=>force(termError"Malformed subtype (2)"))
 fun subtypeIntroduction first second proof:term=D.delay(fn()=>case(force first,force second,force proof)of
    (TM(body,ty,sg1),TM(subtype,_,sg2),TH(theorem,sg3))=>(case force subtype of Binder(SubtypeB,dec,condition,_,_)=>
      if equalSignature sg1 sg2 andalso equalSignature sg2 sg3
         andalso equalTerm(termType sg2(declarationType dec))(bareConstant(Universe(int 0)))
         andalso equalTerm ty(declarationType dec)andalso equalTerm theorem(substituteTerm dec condition body)
      then TM(addType body subtype,subtype,sg1)else force(termError"Malformed subtype introduction ")
      |_=>force(termError"Malformed subtype introduction (2)"))
   |_=>force(termError"Malformed subtype introduction (2)"))
 fun subtypeElimination term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Binder(SubtypeB,dec,_,_,_)=>let val ty=declarationType dec in TM(addType body ty,ty,sg)end
      |_=>force(termError" outof: argument invalid"))
   |_=>force(termError" outof: argument invalid"))
 fun boolean signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant BoolType,bareConstant(Universe(int 0)),sg)|_=>raise Match)
 fun truth signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant Truth,bareConstant BoolType,sg)|_=>raise Match)
 fun falsehood signatureValue:term=D.delay(fn()=>case force signatureValue of SG sg=>
    TM(bareConstant Falsehood,bareConstant BoolType,sg)|_=>raise Match)
 fun universal term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isSymbolDeclaration dec then TM(bareBinder ForallB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed universal quantification")
      |_=>force(termError"Malformed universal quantification (2)"))
   |_=>force(termError"Malformed universal quantification (2)"))
 fun existential term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isSymbolDeclaration dec then TM(bareBinder ExistsB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed existential quantification")
      |_=>force(termError"Malformed existential quantification (2)"))
   |_=>force(termError"Malformed existential quantification (2)"))
 fun implication term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case(force ty,force sg)of(Constant(BoolType,_,_),Extend(dec,parent,_))=>
       if isAxiomDeclaration dec then TM(bareBinder ImpB dec body,bareConstant BoolType,parent)
         else force(termError"Malformed Implication")
      |_=>force(termError"Malformed Implication (2)"))
   |_=>force(termError"Malformed Implication (2)"))
 fun conjunction first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of(Constant(BoolType,_,_),Constant(BoolType,_,_))=>
       if equalSignature sg1 sg2 then TM(bareBinary AndB a b,bareConstant BoolType,sg1)
          else force(termError"Malformed conjunction")
       |_=>force(termError"Malformed conjunction (2)"))
   |_=>force(termError"Malformed conjunction (2)"))
 fun disjunction first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of(Constant(BoolType,_,_),Constant(BoolType,_,_))=>
       if equalSignature sg1 sg2 then TM(bareBinary OrB a b,bareConstant BoolType,sg1)
          else force(termError"Malformed disjunction ")
       |_=>force(termError"Malformed disjunction (2)"))
   |_=>force(termError"Malformed disjunction (2)"))
 fun negation term:term=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>TM(cell(Unary(NotU,body,F.empty(),F.empty())),bareConstant BoolType,sg)
      |_=>force(termError"Malformed negation"))
   |_=>force(termError"Malformed negation"))
 fun equality first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,_,sg1),TM(b,_,sg2))=>if equalSignature sg1 sg2 then TM(bareBinary EqualB a b,bareConstant BoolType,sg1)
       else force(termError"Malformed equality")|_=>raise Match)
 fun isSubtype first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force ty1,force ty2)of
       (Constant(Universe i,_,_),Constant(Universe j,_,_))=>
          if equalInt i(int 0)andalso equalInt j(int 0)then
            if equalSignature sg1 sg2 then TM(bareBinary IsSubtypeB a b,bareConstant BoolType,sg1)
               else force(termError"Malformed subtype")
          else force(termError"Malformed subtype (2)")|_=>force(termError"Malformed subtype (2)"))
   |_=>force(termError"Malformed subtype (2)"))
 fun conditional first second:term=D.delay(fn()=>case(force first,force second)of
    (TM(a,ty1,sg1),TM(b,ty2,sg2))=>(case(force sg1,force sg2)of(Extend(dec1,parent1,_),Extend(dec2,parent2,_))=>
      if equalSignature parent1 parent2 andalso equalTerm ty1 ty2 andalso
           equalTerm(cell(Unary(NotU,declarationType dec1,F.empty(),F.empty())))(declarationType dec2)
      then TM(cell(Cond(dec1,a,b,F.empty(),F.empty())),ty1,parent1)else force(termError"Malformed conditional")
       |_=>force(termError"Malformed conditional (2)"))
   |_=>force(termError"Malformed conditional (2)"))
 fun choose theorem:term=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binder(ExistsB,dec,condition,_,_)=>
       if equalTerm(termType sg(declarationType dec))(bareConstant(Universe(int 0)))
         then TM(bareBinder ChooseB dec condition,bareBinder SubtypeB dec condition,sg)
         else force(termError"epsilon operator error")|_=>force(termError"epsilon operator error (2)"))
   |_=>force(termError"epsilon operator error (2)"))
 fun constructor signatureValue i j k:term=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TM(cell(Const(i,j,k,F.empty(),F.empty())),constructorType sg i j k,sg)
       else force(termError"Malformed constructor")|_=>raise Match)
 fun recurse terms function:term=D.delay(fn()=>case force function of TM(body,_,sg)=>
    (case force body of Binder(PiB,dec,_,_,_)=>(case force dec of SymbolDec(dataType,_)=>
       let val result=clauseTypes sg dataType body
           val types=F.defer(fn()=> #1(L.force result))
           fun ok term ty=case force term of TM(_,actual,signatureValue)=>equalSignature sg signatureValue andalso equalTerm actual ty
              |_=>raise Match
           val valid=all(fn value=>let val(term,ty)=force value in ok term ty end)(zip pair terms types)
           val bodies=map(fn term=>D.delay(fn()=>case force term of TM(body,_,_)=>force body|_=>raise Match))terms
       in if valid then TM(cell(Recurse(bodies,body,F.empty(),F.empty())),body,sg)else force(termError"recurse error")end
       |_=>force(termError"recurse error (2)"))|_=>force(termError"recurse error (2)"))
   |_=>force(termError"recurse error (2)"))
 fun widen term theorem:term=D.delay(fn()=>case(force term,force theorem)of
    (TM(body,ty,sg1),TH(proposition,sg2))=>(case force proposition of Binary(IsSubtypeB,from,to,_,_)=>
        if equalSignature sg1 sg2 andalso equalTerm ty from then TM(addType body to,to,sg1)
           else force(termError"widen: error")|_=>force(termError"widen: error (2)"))
   |_=>force(termError"widen: error (2)"))
 fun setTermInformation term indices attrs:term=D.delay(fn()=>case force term of
    TM(body,ty,sg)=>TM(setTermAttributes body indices attrs,ty,sg)|TermError _=>force term)
 fun getTermInformation term indices=F.defer(fn()=>case force term of TM(body,_,_)=>getTermAttributes body indices|_=>raise Match)
 fun internalTerm term=L.delay(fn()=>case force term of TM(body,ty,sg)=>(body,ty,sg)|_=>raise Match)
 fun restoreTerm source=termError"restore_Trm unimplemented"


 val emptySignature:signatureValue=cell(SG(cell(EmptySig(F.empty()))))
 fun extendSignature declaration signatureValue:signatureValue=D.delay(fn()=>case(force declaration,force signatureValue)of
    (DC(dec,first),SG second)=>if equalSignature first second then SG(cell(Extend(dec,second,F.empty())))
       else force(signatureError"Malformed signature extension")
   |_=>force(signatureError"Invalid declaration in signature"))
 fun combineSignatures first second:signatureValue=D.delay(fn()=>case(force first,force second)of(SG a,SG b)=>
    let val mapA=shareMap a val mapB=shareMap b
        val offset=length mapB
        val combined=F.append mapB(map(fn i=>add i offset)mapA)
    in SG(cell(Combine(a,b,signatureLength b,combined,F.empty())))end|_=>raise Match)
 fun shareSignature signatureValue i j:signatureValue=D.delay(fn()=>case force signatureValue of SG sg=>
    let val first=nthSignature i sg val second=nthSignature j sg
        val map=shareMap sg
    in if equalSignature first second then SG(cell(Share(sg,i,j,signatureLength second,
          addEquivalenceRange i j(signatureLength second)map,F.empty())))
       else force(signatureError"sg: Share")end|_=>raise Match)
 fun getSignatureInformation signatureValue=F.defer(fn()=>case force signatureValue of SG sg=>signatureAttributes sg|_=>raise Match)
 fun setSignatureInformation signatureValue attrs:signatureValue=D.delay(fn()=>case force signatureValue of SG sg=>
    SG(setSignatureAttributes sg attrs)|_=>raise Match)
 fun internalSignature signatureValue:isgn=D.delay(fn()=>case force signatureValue of SG sg=>force sg|_=>raise Match)
 fun restoreSignature source=signatureError"restore_Sgn unimplemented"
 fun symbolDeclaration term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force(termType sg ty)of Constant(Universe _,_,_)=>DC(cell(SymbolDec(body,F.empty())),sg)
      |_=>force(declarationError"Malformed symbol declaration"))|_=>raise Match)
 fun axiomDeclaration term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>DC(cell(AxiomDec(body,F.empty())),sg)
      |_=>force(declarationError"Malformed axiom declaration"))
   |_=>force(declarationError"Malformed axiom declaration"))
 fun definition term:declaration=D.delay(fn()=>case force term of TM(body,ty,sg)=>DC(cell(Def(body,ty,F.empty())),sg)|_=>raise Match)
 fun makeData terms theorem:declaration=D.delay(fn()=>case force theorem of TH(body,sg)=>
   let fun wellFormed parameter=case force parameter of TM(body,ty,_)=>
         (case force ty of Constant(Universe _,_,_)=>equalTerm body(cell(Sym(int 0,int 0,F.empty(),F.empty())))orelse not(occurs(int 0)body)
           |_=>false)|_=>false
       fun termBody term:itr=D.delay(fn()=>case force term of TM(body,_,_)=>force body|_=>raise Match)
       fun base terms=not(any(fn term=>equalTerm term(cell(Sym(int 0,int 0,F.empty(),F.empty()))))(map termBody terms))
       fun exists first second=bareBinder ExistsB(cell(SymbolDec(shiftTerm(F.empty())(int ~1)first,F.empty())))
           (shiftTerm(F.empty())(int 1)second)
       fun proof terms=foldRight exists(bareConstant Truth)(reverse(map termBody terms))
       val proofs=map proof(filter base terms)
   in if all(all wellFormed)terms then
        if any(equalTerm body)proofs then DC(cell(Data(F.empty(),map(map termBody)terms,F.empty())),sg)
           else force(declarationError"Malformed datatype")
      else force(declarationError"Malformed datatype (2)")end
   |_=>raise Match)
 fun polymorphicData declaration:declaration=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    (case(force dec,force sg)of(Data(parameters,terms,_),Extend(new,parent,_))=>
       if isSymbolDeclaration new then DC(cell(Data(F.cons(new,parameters),terms,F.empty())),parent)
          else force(declarationError"Malformed datatype (polydata)")
      |_=>force(declarationError"Malformed datatype (polydata 2)"))
   |_=>force(declarationError"Malformed datatype (polydata 2)"))
 fun declarationPair declaration:declaration=D.delay(fn()=>case force declaration of DC(first,sg)=>
    (case force sg of Extend(second,parent,_)=>DC(cell(DecPair(second,first,F.empty())),parent)
       |_=>force(declarationError"Malformed declaation pair"))
   |_=>force(declarationError"Malformed declaation pair"))
 fun getDeclarationInformation declaration=F.defer(fn()=>case force declaration of DC(dec,_)=>declarationAttributes dec|_=>raise Match)
 fun setDeclarationInformation declaration attrs:declaration=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    DC(setDeclarationAttributes dec attrs,sg)|_=>raise Match)
 fun internalDeclaration declaration=L.delay(fn()=>case force declaration of DC(dec,sg)=>(dec,sg)|_=>raise Match)
 fun restoreDeclaration source=raise Fail"BadDeclaration"


 fun axiom signatureValue i j:theorem=D.delay(fn()=>case force signatureValue of SG sg=>
    if equalInt(nth(shareMap sg)i)i then TH(axiomType sg i j,sg)
       else force(theoremError"Malformed Axiom")|_=>raise Match)
 fun generalize theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isSymbolDeclaration dec then TH(bareBinder ForallB dec body,parent)
        else force(theoremError"Malformed generalisation")|_=>force(theoremError"Malformed generalisation (2)"))
   |_=>force(theoremError"Malformed generalisation (2)"))
 fun specialize theorem term:theorem=D.delay(fn()=>case(force theorem,force term)of(TH(body,sg1),TM(argument,ty,sg2))=>
    (case force body of Binder(ForallB,dec,result,_,_)=>
       if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)ty then TH(substituteTerm dec result argument,sg1)
          else force(theoremError"Malformed specialisation")|_=>force(theoremError"Malformed specialisation (2)"))
   |_=>force(theoremError"Malformed specialisation (2)"))
 fun existsIntroduction proof exists witness:theorem=D.delay(fn()=>case(force proof,force exists,force witness)of
    (TH(body,sg1),TM(target,_,sg2),TM(term,ty,sg3))=>(case force target of Binder(ExistsB,dec,condition,_,_)=>
       if equalSignature sg1 sg2 andalso equalSignature sg2 sg3 andalso equalTerm(declarationType dec)ty
          andalso equalTerm(substituteTerm dec condition term)body then TH(target,sg2)
          else force(theoremError"Malformed existential introduction")|_=>force(theoremError"Malformed existential introduction (2)"))
   |_=>force(theoremError"Malformed existential introduction (2)"))
 fun existsElimination first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body1,sg1),TH(body2,sg2))=>
    (case(force body1,force body2)of(Binder(ForallB,dec1,inner,_,_),Binder(ExistsB,dec2,condition,_,_))=>
       (case force inner of Binder(ImpB,dec,result,_,_)=>if equalSignature sg1 sg2 andalso equalDeclaration dec1 dec2
           andalso equalTerm(declarationType dec)condition andalso not(occurs(int 0)result)then TH(result,sg1)
           else force(theoremError"Invalid existential elimination")|_=>force(theoremError"Invalid existential elimination"))
      |_=>force(theoremError"Invalid existential elimination"))
   |_=>force(theoremError"Invalid existential elimination"))
 fun discharge theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isAxiomDeclaration dec then TH(bareBinder ImpB dec body,parent)
       else force(theoremError"Invalid implication introduction")|_=>force(theoremError"Invalid implication introduction (2)"))
   |_=>force(theoremError"Invalid implication introduction (2)"))
 fun modusPonens first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body,sg1),TH(argument,sg2))=>
    (case force body of Binder(ImpB,dec,result,_,_)=>if equalSignature sg1 sg2 andalso equalTerm(declarationType dec)argument
       then TH(result,sg1)else force(theoremError"Invalid implication elimination")|_=>force(theoremError"Invalid implication elimination"))
   |_=>force(theoremError"Invalid implication elimination"))
 fun tautology term:theorem=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Constant(BoolType,_,_)=>if evaluateProposition body then TH(body,sg)
          else force(theoremError"term is not a tautology")
       |_=>force(theoremError("argument must be a term of sort "^String.str(Char.chr 96)^"bool'")))
   |_=>force(theoremError("argument must be a term of sort "^String.str(Char.chr 96)^"bool'")))
 fun reflexivity term:theorem=D.delay(fn()=>case force term of TM(body,_,sg)=>TH(bareBinary EqualB body body,sg)|_=>raise Match)
 fun symmetry theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(EqualB,first,second,_,_)=>TH(bareBinary EqualB second first,sg)
       |_=>force(theoremError"symmetry: argument must be an equality term"))
   |_=>force(theoremError"symmetry: argument must be an equality term"))
 fun betaRewrite theorem indices:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    let val(selected,_)=L.force(selectTerm body indices)
    in case force selected of App(function,argument,_,_)=>(case force function of Binder(LambdaB,dec,result,_,_)=>
          TH(replaceTerm body indices(substituteTerm dec result argument),sg)|_=>force(theoremError"Invalid beta reduction"))
       |_=>force(theoremError"Invalid beta reduction")end|_=>raise Match)
 fun etaRewrite theorem indices:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    let val(selected,_)=L.force(selectTerm body indices)
    in case force selected of Binder(LambdaB,dec,application,_,_)=>(case force application of App(function,argument,_,_)=>
         if not(occurs(int 0)function)andalso etaMatch dec argument(int 1)
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)function),sg)
           else force(theoremError"Invalid eta reduction")|_=>force(theoremError"Invlaid eta reduction (2)"))
      |_=>force(theoremError"Invlaid eta reduction (2)")end|_=>raise Match)
 fun conditionalTrueRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(proof,sg1),TH(body,sg2))=>
    let val(selected,declarations)=L.force(selectTerm body indices)
    in case force selected of Cond(dec,yes,_,_,_)=>
        let val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg2 declarations
        in if equalSignature sg1 signatureValue andalso equalTerm proof(declarationType dec)
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)yes),sg1)
           else force(theoremError"cond_true_rw: error")end
       |_=>force(theoremError"cond_true_rw: error 2")end|_=>raise Match)
 fun conditionalFalseRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(proof,sg1),TH(body,sg2))=>
    let val(selected,declarations)=L.force(selectTerm body indices)
    in case force selected of Cond(dec,_,no,_,_)=>
        let val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg2 declarations
        in if equalSignature sg1 signatureValue andalso equalTerm proof(cell(Unary(NotU,declarationType dec,F.empty(),F.empty())))
           then TH(replaceTerm body indices(shiftTerm(F.empty())(int ~1)no),sg1)
           else force(theoremError"cond_false_rw: error")end
       |_=>force(theoremError"cond_false_rw: error 2")end|_=>raise Match)
 fun subtermRewrite first second indices:theorem=D.delay(fn()=>case(force first,force second)of(TH(body,sg1),TH(equation,sg2))=>
    (case force equation of Binary(EqualB,from,to,_,_)=>
       let val(selected,declarations)=L.force(selectTerm body indices)
           val signatureValue=foldRight(fn dec=>fn sg=>cell(Extend(dec,sg,F.empty())))sg1 declarations
       (* The source compares sg3 with itself, not with sg2. *)
       in if equalSignature signatureValue signatureValue andalso equalTerm from selected
          then TH(replaceTerm body indices to,sg1)else force(theoremError"subterm_rw: terms or sigs unequal")end
      |_=>force(theoremError"subterm_rw: Invalid argument"))
   |_=>force(theoremError"subterm_rw: Invalid argument"))
 fun injection theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(EqualB,first,second,_,_)=>
       let fun reduce term arguments=F.defer(fn()=>case force term of App(first,second,_,_)=>reduce first(F.cons(second,arguments))
               |_=>F.cons(term,arguments))
           val left=reduce first(F.empty())val right=reduce second(F.empty())
           val c1=head left val c2=head right val args1=tail left val args2=tail right
       in case(force c1,force c2)of(Const(i,j,k,_,_),Const _)=>
          (case force(extractDeclaration j(nthDeclaration i sg))of Data(declarations,_,_)=>
             if less(length declarations)(length args1)andalso equalTerm c1 c2 andalso equalInt(length args1)(length args2)then
                let val a=drop(length declarations)args1 val b=drop(length declarations)args2
                    val equations=zip(bareBinary EqualB)a b
                in TH(foldRightOne(bareBinary AndB)equations,sg)end
             else force(theoremError"Invalid injection")
            |_=>force(theoremError"Invalid injection: not a datatype"))
         |_=>force(theoremError"Invalid injection (3)")end
      |_=>force(theoremError"Invalid injection (4)"))
   |_=>force(theoremError"Invalid injection (4)"))
 fun induction term:theorem=D.delay(fn()=>case force term of TM(body,_,sg)=>
    (case force body of Const(i,j,k,_,_)=>if equalInt k(int 0)then TH(inductionTerm sg body,sg)
       else force(theoremError"Invalid induction")|_=>force(theoremError"Invalid induction"))
   |_=>force(theoremError"Invalid induction"))
 fun subtypeProofIntroduction theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binder(ForallB,dec1,body,_,_)=>
       (case force body of Binder(ExistsB,dec2,equation,_,_)=>
          (case force equation of Binary(EqualB,first,second,_,_)=>
             (case(force first,force second)of(Sym(i,j,_,_),Sym(k,l,_,_))=>
                if equalInt i(int 1)andalso equalInt j(int 0)andalso equalInt k(int 0)andalso equalInt l(int 0)
                  then TH(bareBinary IsSubtypeB(declarationType dec1)(shiftTerm(F.empty())(int ~1)(declarationType dec2)),sg)
                  else force(theoremError"issubtype_intro error (1)")
               |_=>force(theoremError"issubtype_intro error (1)"))
            |_=>force(theoremError"issubtype_intro error (2)"))
         |_=>force(theoremError"issubtype_intro error (2)"))
      |_=>force(theoremError"issubtype_intro error (3)"))
   |_=>force(theoremError"issubtype_intro error (3)"))
 fun subtypeProofElimination theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force body of Binary(IsSubtypeB,first,second,_,_)=>
       let val dec1=cell(SymbolDec(first,F.empty()))
           val dec2=cell(SymbolDec(shiftTerm(F.empty())(int 1)second,F.empty()))
           val equation=bareBinary EqualB(cell(Sym(int 1,int 0,F.empty(),F.empty())))(cell(Sym(int 0,int 0,F.empty(),F.empty())))
       in TH(bareBinder ForallB dec1(bareBinder ExistsB dec2 equation),sg)end
      |_=>force(theoremError"issubtype_elim error"))
   |_=>force(theoremError"issubtype_elim error"))
 fun equalityOfTypes first second:theorem=D.delay(fn()=>case(force first,force second)of(TH(body1,sg1),TH(body2,sg2))=>
    (case(force body1,force body2)of(Binary(IsSubtypeB,a,b,types1,attrs1),Binary(IsSubtypeB,c,d,types2,attrs2))=>
       if null types1 andalso null attrs1 andalso null types2 andalso null attrs2 then
          if equalSignature sg1 sg2 andalso equalTerm a d andalso equalTerm b c then TH(bareBinary EqualB a b,sg1)
             else force(theoremError"eq_of_ty error")
       else force(theoremError"eq_of_ty error (2)")
      |_=>force(theoremError"eq_of_ty error (2)"))
   |_=>force(theoremError"eq_of_ty error (2)"))
 fun fromSubtype term:theorem=D.delay(fn()=>case force term of TM(body,ty,sg)=>
    (case force ty of Binder(SubtypeB,dec,condition,_,_)=>TH(substituteTerm dec condition body,sg)
       |_=>force(theoremError"from: argument must be term of subtype sort"))
   |_=>force(theoremError"from: argument must be term of subtype sort"))
 fun definitionElimination theorem:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    (case force sg of Extend(dec,parent,_)=>if isDefinitionDeclaration dec then
       let val result=splitDefinition dec
           val(new,replacement,_)=L.force result
       in TH(substituteTerm new body replacement,parent)end
       else force(theoremError"Definition elimination error")
      |_=>force(theoremError"Definition elimination error (2)"))
   |_=>force(theoremError"Definition elimination error (2)"))
 fun weaken signatureValue theorem:theorem=D.delay(fn()=>case(force signatureValue,force theorem)of(SG sg1,TH(body,sg2))=>
    (case force(subSignature sg2 sg1)of SomeValue index=>TH(shiftTerm(shareMap sg1)index body,sg1)
      |NoValue=>force(theoremError"Weaken error"))|_=>raise Match)
 fun setTheoremInformation theorem indices attrs:theorem=D.delay(fn()=>case force theorem of TH(body,sg)=>
    TH(setTermAttributes body indices attrs,sg)|_=>raise Match)
 fun getTheoremInformation theorem indices=F.defer(fn()=>case force theorem of TH(body,sg)=>getTermAttributes body indices|_=>raise Match)
 fun restoreTheorem source=raise Fail"BadTheorem"
 fun internalTheorem theorem=L.delay(fn()=>case force theorem of TH(body,sg)=>(body,sg)
   |TheoremError _=>raise Fail"add feed to itm via extra itrm ctr")


 fun equalWrappedTerms first second=case(force first,force second)of(TM(a,_,sg1),TM(b,_,sg2))=>
    equalTerm a b andalso equalSignature sg1 sg2|_=>raise Match
 fun equalWrappedSignatures first second=case(force first,force second)of(SG a,SG b)=>equalSignature a b|_=>raise Match
 fun equalWrappedDeclarations first second=case(force first,force second)of(DC(a,sg1),DC(b,sg2))=>
    equalDeclaration a b andalso equalSignature sg1 sg2|_=>raise Match
 fun equalWrappedTheorems first second=case(force first,force second)of(TH(a,sg1),TH(b,sg2))=>
    equalTerm a b andalso equalSignature sg1 sg2|_=>raise Match
 fun wrappedTermType term:term=D.delay(fn()=>case force term of TM(_,ty,sg)=>TM(ty,termType sg ty,sg)|_=>raise Match)
 fun wrappedDeclarationType declaration:term=D.delay(fn()=>case force declaration of DC(dec,sg)=>
    let val ty=declarationType dec in TM(ty,termType sg ty,sg)end|_=>raise Match)
 fun wrappedTheoremType theorem:term=D.delay(fn()=>case force theorem of TH(body,sg)=>TM(body,bareConstant BoolType,sg)|_=>raise Match)
 fun shiftWrappedTerm offset signatureValue term:term=D.delay(fn()=>case(force signatureValue,force term)of(SG sg1,TM(body,ty,sg2))=>
    if equalSignature sg2(nthSignature offset sg1)then
       TM(shiftTerm(shareMap sg2)offset body,shiftTerm(shareMap sg2)offset ty,sg1)
    else force(termError"shift_Trm: signatures unequal")|_=>raise Match)
 fun substituteWrappedTerm first second:term=D.delay(fn()=>case(force first,force second)of(TM(body,ty,sg1),TM(replacement,replacementType,sg2))=>
    (case force sg1 of Extend(dec,parent,_)=>if equalSignature parent sg2 andalso equalTerm(declarationType dec)replacementType
       then TM(substituteTerm dec body ty,substituteTerm dec ty replacement,parent)
       else force(termError"subst_Trm: signatures unequal or type of dc unequal to type of second argument")
      |_=>force(termError"subst_Trm: Invalid arguments"))
   |_=>force(termError"subst_Trm: Invalid arguments"))
 fun termSignature term:signatureValue=D.delay(fn()=>case force term of TM(_,_,sg)=>SG sg|TermError message=>SignatureError message)
 fun declarationSignature declaration:signatureValue=D.delay(fn()=>case force declaration of DC(_,sg)=>SG sg|DeclarationError message=>SignatureError message)
 fun theoremSignature theorem:signatureValue=D.delay(fn()=>case force theorem of TH(_,sg)=>SG sg|TheoremError message=>SignatureError message)
 fun validTheorem theorem=case force theorem of TH _=>true|_=>false
 fun validTerm term=case force term of TM _=>true|_=>false
 fun validSignature signatureValue=case force signatureValue of SG _=>true|_=>false


 fun symbolName value=pair NameStyle(cell(SymbolName value))
 fun datatypeNames values=pair NameStyle(cell(DatatypeName values))
 val symbolNamed=pair SymbolStyle(cell Named)
 val symbolIndexed=pair SymbolStyle(cell Indexed)
 val pairTyped=pair PairStyle(cell Typed)
 val pairUntyped=pair PairStyle(cell Untyped)
 val letStyle=pair LetStyle(cell LetValue)
 fun operatorStyle kind=pair OperatorStyle(cell(case kind of Pre=>Prefixed|BinL=>Linfixed|BinR=>Rinfixed|Post=>Postfixed))
 val infixBinder=pair BinderStyle(cell InfixBinder)
 val prefixBinder=pair BinderStyle(cell PrefixBinder)
 val recursiveStyle=pair RecurseStyle(cell Recursive)
 val nondependent=pair HypStyle(cell NonDependent)
 val grouped=pair DecStyle(cell Grouped)
 val ungrouped=pair DecStyle(cell Ungrouped)
 val declarationTyped=pair DecStyle(cell Typed)
 val declarationUntyped=pair DecStyle(cell Untyped)
 val definitionParameter=pair DefStyle(cell Parameter)
 val definitionNonparameter=pair DefStyle(cell NonParameter)
 fun attributeValue tag attributes=D.delay(fn()=>case force attributes of F.Nil=>SymbolName(cell(Name(text"_")))
   |F.Cons(attribute,rest)=>let val(current,value)=force attribute
       in if tag=current then force value else force(attributeValue tag rest)end)


 val endOfLine=[#"\n",#"\012",#"\r"]
 val whiteSpace=[#" ",#"\t"]@endOfLine
 val symbolCharacters=String.explode"!#$&*-+=~<>?/\\.:|@"
 val singleCharacters=List.map Char.chr[44,59,34,96,39,40,41,123,125,91,93,176,185]
 val binderCharacters=List.map Char.chr[208,211,236,177,178,229,196]
 val infixBinderCharacters=List.map Char.chr[183,184,167,182,187]
 val infixOperatorCharacters=List.map Char.chr[179,180,61,172,58]
 fun asciiAlphaNumeric c=(c>= #"A"andalso c<= #"Z")orelse(c>= #"a"andalso c<= #"z")orelse(c>= #"0"andalso c<= #"9")
 fun contains characters c=List.exists(fn value=>c=value)characters
 fun byte n=text(String.str(Char.chr n))
 val reservedTokens: text list=List.map text[
    "empty","signature","extend","combine","with","sharing","++","=","(",")","@","operator",";",":",
    String.str(Char.chr 189),"datatype","|","case","of",String.str(Char.chr 167),"recurse","end","typed","fn","rec",
    "if","then","else","let","in",String.str(Char.chr 168),String.str(Char.chr 169),"{","}","[","]",
    String.str(Char.chr 208),String.str(Char.chr 211),String.str(Char.chr 236),String.str(Char.chr 229),
    String.str(Char.chr 177),String.str(Char.chr 178),".",",",String.str(Char.chr 181),String.str(Char.chr 179),
    String.str(Char.chr 180),String.str(Char.chr 182),String.str(Char.chr 172),String.str(Char.chr 183),
    String.str(Char.chr 184),String.str(Char.chr 185),String.str(Char.chr 176),"BinL","BinR","Pre","Post",
    String.str(Char.chr 196),String.str(Char.chr 187)]
 fun binderCharacter character=case Char.ord character of 208=>PiB|211=>SigmaB|236=>LambdaB
   |177=>ForallB|178=>ExistsB|229=>ChooseB|196=>DeltaB|_=>raise Fail("Mk_bdr: "^String.str character)
 fun tokenCons value rest=C.cons(L.delay(fn()=>value),rest)
 fun tokenize characters=
   let fun scan input current=C.defer(fn()=>case force input of F.Nil=>tokenCons(cell(Clear current))(C.empty())
         |F.Cons(character,rest)=>
           let val c=force character
               fun emitted token=tokenCons(cell(Clear current))(tokenCons token(scan rest(F.empty())))
           in if contains binderCharacters c then emitted(cell(BinderToken(binderCharacter c)))
              else if contains infixBinderCharacters c then emitted(cell(InfixBinderToken(singleton character)))
              else if contains infixOperatorCharacters c then emitted(cell(InfixOperatorToken(singleton character)))
              else if contains singleCharacters c orelse Char.ord c>127 then emitted(cell(Clear(singleton character)))
              else if contains symbolCharacters c then tokenCons(cell(Clear current))(symbolScan rest(singleton character))
              else if contains whiteSpace c then tokenCons(cell(Clear current))(scan rest(F.empty()))
              else if asciiAlphaNumeric c orelse c= #"_"then scan rest(F.cons(character,current))
              else if c= #"%"then tokenCons(cell(Clear current))(scan(discard rest)(F.empty()))
              else if c= #"^"then superScan rest(F.cons(character,current))
              else tokenCons(cell(ScanError(text"\nInvalid character\n")))(C.empty())end)
       and symbolScan input current=C.defer(fn()=>case force input of F.Nil=>tokenCons(cell(Clear current))(C.empty())
         |F.Cons(character,rest)=>let val c=force character
           in if contains symbolCharacters c then symbolScan rest(F.cons(character,current))
              else if c= #"^"then superScan rest(F.cons(character,current))
              else tokenCons(cell(Clear current))(scan input(F.empty()))end)
       and superScan input current=C.defer(fn()=>if equalText current(text"^")then
             tokenCons(cell(ScanError(text"\nAttempt to superscript invalid string\n")))(C.empty())
           else case force input of F.Nil=>tokenCons(cell(ScanError(text"\nEmpty superscript\n")))(C.empty())
            |F.Cons(character,rest)=>if asciiAlphaNumeric(force character)orelse contains symbolCharacters(force character)
                then tokenCons(cell(Clear(F.cons(character,current))))(scan rest(F.empty()))
                else tokenCons(cell(ScanError(text"\nInvalid superscript character\n")))(C.empty()))
       and discard input=F.defer(fn()=>case force input of F.Nil=>F.empty()
          |F.Cons(c,rest)=>if contains endOfLine(force c)then rest else discard rest)
       fun denull tokens=C.defer(fn()=>case L.force tokens of C.Nil=>C.empty()
         |C.Cons(delayed,rest)=>
            let val token=L.force delayed
            in case force token of Clear chars=>if null chars then denull rest
               else let val value=reverse chars
                        val token=cell(if List.exists(fn s=>equalText value s)reservedTokens then Reserved value else Clear value)
                    in tokenCons token(denull rest)end
              |Reserved _=>raise Fail" optimise to trap some reserved earlier and reduce length of reserved set"
              |ScanError _=>tokenCons token(C.empty())
              |_=>tokenCons token(denull rest)end)
   in denull(scan characters(F.empty()))end


 fun integerText number=text(String.map(fn #"~"=> #"-"|c=>c)(Int.toString(force number)))
 fun operatorText Pre=text"Pre"|operatorText BinL=text"BinL"|operatorText BinR=text"BinR"|operatorText Post=text"Post"
 fun unparseName value=F.defer(fn()=>case force value of Name chars=>chars|OperatorName(chars,precedence,kind)=>
    textConcat[text"{",chars,text" ",operatorText kind,text" ",integerText precedence,text"}"])
 fun unparseBinder LambdaB=byte 236|unparseBinder ForallB=byte 177|unparseBinder ExistsB=byte 178
   |unparseBinder PiB=byte 208|unparseBinder SigmaB=byte 211|unparseBinder ChooseB=byte 229|unparseBinder DeltaB=byte 196
   |unparseBinder _=raise Match
 fun unparseBinary OrB=byte 180|unparseBinary AndB=byte 179|unparseBinary EqualB=text"="|unparseBinary IsSubtypeB=byte 172
 fun unparseConstant Truth=text"True"|unparseConstant Falsehood=text"False"|unparseConstant BoolType=text"Bool"
   |unparseConstant(Universe i)=F.append(text"U")(integerText i)
 fun declarationName attrs=D.delay(fn()=>case force(attributeValue NameStyle attrs)of SymbolName value=>force value
    |DatatypeName _=>Name(text" Unexpected Datatype ")|_=>raise Match)
 fun basicName value=F.defer(fn()=>case force value of Name chars=>chars|OperatorName(chars,_,_)=>chars)
 fun constructorName names index=F.defer(fn()=>case force names of F.Nil=>text" Constructor not found "
   |F.Cons(n,rest)=>if less(int 0)index then constructorName rest(subtract index(int 1))
      else if equalInt index(int 0)then basicName n else raise Match)
 fun printedSymbol signatureValue first second constructor=F.defer(fn()=>case force signatureValue of
    Extend(declaration,parent,_)=>if equalInt first(int 0)then lookupDeclaration declaration(F.empty())second constructor
       else if less(int 0)first then printedSymbol parent(subtract first(int 1))second constructor else text"symbol not found "
   |_=>text"symbol not found ")
 and lookupDeclaration declaration stack index constructor=F.defer(fn()=>
   let fun next()=case force stack of F.Cons(dec,rest)=>if less(int 0)index then
          lookupDeclaration dec rest(subtract index(int 1))constructor else text" symbol not found "
         |F.Nil=>text" symbol not found "
   in case force declaration of
       SymbolDec(_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |AxiomDec(_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |Def(_,_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |Data(_,_,attrs)=>if equalInt index(int 0)then
          let val names=F.defer(fn()=>case force(attributeValue NameStyle attrs)of
               SymbolName value=>singleton value|DatatypeName values=>values|_=>raise Match)
          in constructorName names constructor end else next()
      |DecPair(first,second,attrs)=>if less(int 0)index then
         (case force(attributeValue DecStyle attrs)of Grouped=>lookupDeclaration first(F.cons(second,stack))(subtract index(int 1))constructor
          |Ungrouped=>lookupDeclaration first(F.cons(second,stack))(subtract index(int 1))constructor|_=>raise Match)
        else next()end)
 fun unparseITerm signatureValue term=F.defer(fn()=>case force term of
    Sym(i,j,_,attrs)=>(case force(attributeValue SymbolStyle attrs)of
       Named=>printedSymbol signatureValue i j(int ~1)
      |Indexed=>textConcat[byte 168,integerText i,text",",integerText j,byte 169]|_=>raise Match)
   |Const(i,j,k,_,_)=>printedSymbol signatureValue i j k
   |App(a,b,_,_)=>textConcat[text"(",unparseITerm signatureValue a,text" ",unparseITerm signatureValue b,text")"]
   |PairTerm(a,b,c,_,_)=>textConcat[text"((",unparseITerm signatureValue a,text" , ",unparseITerm signatureValue b,
        text") : ",unparseITerm signatureValue c,text")"]
   |Binder(SubtypeB,dec,body,_,_)=>textConcat[text"{",unparseDeclaration signatureValue dec,text" | ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body,text"}"]
   |Binder(ImpB,dec,body,_,_)=>textConcat[text" [",unparseDeclaration signatureValue dec,text"] ",byte 182,text" ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body]
   |Binder(kind,dec,body,_,_)=>textConcat[text"(",unparseBinder kind,unparseDeclaration signatureValue dec,text". ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body,text")"]
   |Constant(kind,_,_)=>unparseConstant kind
   |Unary(_,body,_,_)=>textConcat[text" ",byte 181,unparseITerm signatureValue body]
   |Binary(kind,a,b,_,_)=>textConcat[text"(",unparseITerm signatureValue a,text" ",unparseBinary kind,text" ",unparseITerm signatureValue b,text")"]
   |Cond(dec,a,b,_,_)=>let val extended=cell(Extend(dec,signatureValue,F.empty()))
      in textConcat[text" if [",unparseDeclaration signatureValue dec,text"] then ",unparseITerm extended a,
            text" else ",unparseITerm extended b]end
   |Recurse(terms,ty,_,_)=>textConcat[text"\nrecurse\n\t",flatMap(fn term=>F.append(unparseITerm signatureValue term)(text"\n\t"))terms,
        text"\nend typed ",unparseITerm signatureValue ty]
   |TagId(tag,args)=>let val(name,_,_)=force tag
        fun arg value=F.defer(fn()=>case force value of TagTerm term=>unparseWrappedTerm term
            |TagTheorem theorem=>unparseWrappedTheorem theorem
            |TagInt indices=>textConcat[byte 168,flatMap(fn index=>F.append(text",")(integerText index))indices,byte 169])
      in textConcat[text"( ",name,flatMap(fn value=>F.append(text" ")(arg value))args,text" )"]end
   |ITermError message=>message)
 and unparseDeclaration signatureValue declaration=F.defer(fn()=>case force declaration of
    SymbolDec(term,attrs)=>textConcat[unparseName(declarationName attrs),text" : ",unparseITerm signatureValue term]
   |AxiomDec(term,attrs)=>textConcat[unparseName(declarationName attrs),text" :a: ",unparseITerm signatureValue term]
   |Def(term,_,attrs)=>textConcat[unparseName(declarationName attrs),text" ",byte 189,text" ",unparseITerm signatureValue term]
   |DecPair(first,second,_)=>textConcat[text" ( ",unparseDeclaration signatureValue first,text" ; ",
        unparseDeclaration(cell(Extend(first,signatureValue,F.empty())))second,text" ) "]
   |Data(declarations,constructors,attrs)=>
      let val names=F.defer(fn()=>case force(attributeValue NameStyle attrs)of SymbolName _=>singleton(cell(Name(text" Unexpected Symbol ")))
            |DatatypeName names=>names|_=>raise Match)
          val n=head names
          val arguments=flatMap(fn dec=>textConcat[text"(",unparseDeclaration signatureValue dec,text") "])declarations
          fun extend signatureValue declarations=case force declarations of F.Nil=>signatureValue
            |F.Cons(dec,rest)=>extend(cell(Extend(dec,signatureValue,F.empty())))rest
          val universe=bareConstant(Universe(int 0))
          val typeDeclaration=cell(SymbolDec(universe,singleton(symbolName n)))
          val extended=cell(Extend(typeDeclaration,extend signatureValue(reverse declarations),F.empty()))
          fun constructorRows names rows=F.defer(fn()=>case(force names,force rows)of(F.Nil,F.Nil)=>F.empty()
            |(F.Cons(n,names),F.Cons(args,rows))=>textConcat[unparseName n,text" ",
               flatMap(fn arg=>F.append(unparseITerm extended arg)(text" "))args,text" | ",constructorRows names rows]|_=>raise Match)
      in textConcat[text"datatype ",unparseName n,text" ",arguments,text" = ",constructorRows(tail names)constructors]end)
 and unparseSignature signatureValue=F.defer(fn()=>case force signatureValue of EmptySig _=>F.empty()
   |Extend(dec,parent,_)=>textConcat[unparseDeclaration(cell(EmptySig(F.empty())))dec,text" ;\n",unparseSignature parent]
   |_=>raise Match)
 and unparseWrappedTheorem theorem=F.defer(fn()=>case force theorem of TH(body,sg)=>textConcat[text"Theorem: ",unparseITerm sg body,text"\n"]
   |TheoremError message=>textConcat[text"Invalid theorem: ",message,text"\n"])
 and unparseWrappedTerm term=F.defer(fn()=>case force term of TM(body,ty,sg)=>textConcat[text"Term: ",unparseITerm sg body,
       text"\nType: ",unparseITerm sg ty,text"\nSig: ",unparseSignature sg,text"\n"]
   |TermError message=>textConcat[text"\nTerm formation error\n",message,text"\n"])
 fun unparseFlagged signatureValue flagged=F.defer(fn()=>case force flagged of ParseError message=>F.append message(text"\n")
   |Operand operand=>(case force operand of ITerm term=>unparseITerm signatureValue term
       |IDec dec=>unparseDeclaration signatureValue dec|TypeApp value=>F.append(text"Unparse TypApp: ")(unparseFlagged signatureValue value)
       |_=>text"unparse unknown")
   |Operator(operator,kind,precedence)=>(case force operator of
       TermOperator term=>textConcat[unparseITerm signatureValue term,text"{tpe",operatorText kind,text"prc",integerText precedence,text"}\n"]
      |SpecialOperator name=>if equalText name(text"")then text"unparse operator"else
          if equalText name(text"typed")then text"Unparse 'typed'"else text"unparse unknown"
      |_=>text"unparse unknown"))
 fun displayToken token=F.defer(fn()=>case force token of Reserved value=>value|Clear value=>value|BinderToken kind=>unparseBinder kind
   |InfixBinderToken value=>value|InfixOperatorToken value=>value|ScanError message=>F.append(text"Invalid token: ")message)


 fun parseError message=cell(ParseError message)
 fun operandTerm term=cell(Operand(cell(ITerm term)))
 fun operandDeclaration dec=cell(Operand(cell(IDec dec)))
 fun readInteger chars=case Int.fromString(string chars)of SOME value=>int value|NONE=>raise Fail"Prelude.read: no parse"
 fun digitString chars=all(fn c=>Char.isDigit(force c))chars
 fun indexedSymbol first second:flagged=D.delay(fn()=>if digitString first andalso digitString second then
     force(operandTerm(cell(Sym(readInteger first,readInteger second,F.empty(),singleton symbolIndexed))))
   else ParseError(F.append(if digitString first then second else first)(text" is not an integer ")))
 fun indexedConstructor first second third=operandTerm(cell(Const(readInteger first,readInteger second,readInteger third,F.empty(),singleton symbolIndexed)))
 fun flaggedBinder kind declaration body:flagged=D.delay(fn()=>case(force declaration,force body)of
    (Operand dec,Operand term)=>(case(force dec,force term)of(IDec dec,ITerm body)=>
        force(operandTerm(cell(Binder(kind,dec,body,F.empty(),singleton prefixBinder))))|_=>raise Match)
   |(ParseError _,_)=>force declaration|(_,ParseError _)=>force body|_=>raise Match)
 fun flaggedConditional declaration first second:flagged=D.delay(fn()=>case force declaration of ParseError _=>force declaration
   |_=>case force first of ParseError _=>force first
   |_=>case force second of ParseError _=>force second
   |_=>case(force declaration,force first,force second)of(Operand dec,Operand first,Operand second)=>
      (case(force dec,force first,force second)of(IDec dec,ITerm first,ITerm second)=>
          force(operandTerm(cell(Cond(dec,first,second,F.empty(),F.empty()))))|_=>raise Match)|_=>raise Match)
 fun flaggedLet declaration first second:flagged=D.delay(fn()=>case force declaration of ParseError _=>force declaration
   |_=>case force first of ParseError _=>force first
   |_=>case force second of ParseError _=>force second
   |_=>case(force declaration,force first,force second)of(Operand dec,Operand first,Operand second)=>
      (case(force dec,force first,force second)of(IDec dec,ITerm first,ITerm second)=>
          let val function=bareBinder LambdaB dec second
          in force(operandTerm(cell(App(function,first,F.empty(),singleton letStyle))))end|_=>raise Fail"let' operand")
      |_=>raise Fail"let' operator")
 fun flaggedApplication first second:flagged=D.delay(fn()=>
   let fun bad()=raise Fail("app' y: "^string(unparseFlagged(cell(EmptySig(F.empty())))second)^"\nx: "^
          string(unparseFlagged(cell(EmptySig(F.empty())))first))
       fun special value wanted=case force value of Operator(opr,_,_)=>
          (case force opr of SpecialOperator actual=>equalText actual(text wanted)|_=>false)|_=>false
       fun result term=force(operandTerm term)
   in if special first""then force second else if special second""then force first
      else if special first"typed"then Operand(cell(TypeApp second))
      else case(force first,force second)of
       (Operator(operator,_,_),Operand operand)=>(case(force operator,force operand)of
          (BinderOperator kind,IDec dec)=>Operand(cell(PartialApp(kind,dec,cell false)))
         |(BinderOperator kind,ITerm sort)=>
             let val dec=cell(SymbolDec(sort,singleton(symbolName(cell(Name(text"_"))))))
             in Operand(cell(PartialApp(kind,dec,cell true)))end
         |(InfixOperator kind,ITerm term)=>Operand(cell(PartialInfix(kind,term)))
         |(TermOperator operator,ITerm term)=>
             let val style=case force first of Operator(_,kind,_)=>operatorStyle kind|_=>raise Match
             in result(cell(App(operator,term,F.empty(),singleton style)))end
         |_=>if special first","then(case force operand of ITerm term=>Operand(cell(PairApp term))|_=>bad())
             else if special first"typed"then Operand(cell(TypeApp second))
             else if special first"Not"then(case force operand of ITerm term=>result(cell(Unary(NotU,term,F.empty(),F.empty())))|_=>bad())
             else if special first":"then(case force operand of ITerm term=>Operand(cell(PartialColon term))|_=>bad())
             else bad())
      |(Operand first,Operand second)=>(case(force first,force second)of
          (PartialApp(kind,dec,anonymous),ITerm body)=>result(cell(Binder(kind,dec,
              D.delay(fn()=>force(if force anonymous then shiftTerm(F.empty())(int 1)body else body)),F.empty(),singleton infixBinder)))
         |(PartialInfix(kind,first),ITerm second)=>result(bareBinary kind first second)
         |(PairApp first,ITerm second)=>result(cell(PairTerm(first,second,bareConstant(Universe(int ~1)),F.empty(),singleton pairUntyped)))
         |(TypeApp value,ITerm sort)=>(case force value of Operand operand=>(case force operand of ITerm term=>
              (case force term of PairTerm(first,second,_,types,_)=>result(cell(PairTerm(first,second,sort,types,singleton pairTyped)))|_=>bad())
              |_=>bad())|_=>bad())
         |(PartialColon first,ITerm second)=>result(addType first second)
         |(ITerm first,ITerm second)=>result(makeApplication first second)|_=>bad())
      |(Operand operand,Operator(operator,_,_))=>(case(force operand,force operator)of(ITerm term,TermOperator operator)=>
          result(makeApplication term operator)|_=>bad())
      |(Operator(first,kind,_),Operator(second,_,_))=>(case(force first,force second)of(TermOperator a,TermOperator b)=>
          result(cell(App(a,b,F.empty(),singleton(operatorStyle kind))))|_=>bad())
      |(ParseError _,_)=>force first|(_,ParseError _)=>force second end)
 fun flaggedDeclarationPair attrs first second:flagged=D.delay(fn()=>case(force first,force second)of
    (ParseError _,_)=>force first|(_,ParseError _)=>force second
   |(Operand a,Operand b)=>(case(force a,force b)of(IDec a,IDec b)=>force(operandDeclaration(cell(DecPair(a,b,attrs))))|_=>raise Match)
   |_=>raise Match)
 fun flaggedSymbolDeclaration term name attrs:flagged=D.delay(fn()=>case force term of ParseError _=>force term
   |Operand operand=>(case force operand of ITerm term=>force(operandDeclaration(cell(SymbolDec(term,F.cons(symbolName name,attrs)))))
      |_=>raise Match)|_=>raise Match)
 fun flaggedRecurse terms sort:flagged=D.delay(fn()=>case force sort of ParseError _=>force sort
   |Operand operand=>(case force operand of ITerm sort=>
      let fun clear acc terms=L.delay(fn()=>case force terms of F.Nil=>Ok acc|F.Cons(term,rest)=>
           case force term of ParseError message=>Bad message
             |Operand operand=>(case force operand of ITerm term=>L.force(clear(F.cons(term,acc))rest)|_=>raise Match)
             |_=>raise Match)
      in case L.force(clear(F.empty())terms)of Ok terms=>force(operandTerm(cell(Recurse(terms,sort,F.empty(),singleton recursiveStyle))))
        |Bad message=>ParseError message end|_=>raise Match)|_=>raise Match)
 fun flaggedTag tag arguments:flagged=D.delay(fn()=>
   let fun check arguments=case force arguments of F.Nil=>NONE|F.Cons(arg,rest)=>case force arg of
        TagTerm term=>(case force term of TM _=>check rest|TermError message=>SOME message)
       |TagTheorem theorem=>(case force theorem of TH _=>check rest|TheoremError message=>SOME message)
       |TagInt _=>check rest
   in case check arguments of NONE=>force(operandTerm(cell(TagId(tag,arguments))))|SOME message=>ParseError message end)


 fun attachTermInformation term types attrs:term=D.delay(fn()=>case force term of TermError _=>force term
   |_=>case force types of F.Nil=>force(setTermInformation term(F.empty())attrs)
     |F.Cons(sort,_)=>let val(_,ty,_)=L.force(internalTerm term)
       in if equalTerm ty sort then force(setTermInformation term(F.empty())attrs)
          else force(termError"Invalid type specification")end)
 fun buildTerm signatureValue flagged:term=D.delay(fn()=>
   let fun invalid()=raise Fail("Error: "^string(unparseFlagged(internalSignature signatureValue)flagged)^"|\n")
   in case force flagged of Operand operand=>
    (case force operand of ITerm term=>force(buildITerm signatureValue term)|_=>invalid())|_=>invalid()end)
 and buildITerm signatureValue term:term=D.delay(fn()=>case force term of
    Sym(i,j,types,attrs)=>force(attachTermInformation(symbol signatureValue i j)types attrs)
   |App(first,second,types,attrs)=>force(attachTermInformation(application(buildITerm signatureValue first)(buildITerm signatureValue second))types attrs)
   |PairTerm(first,second,third,types,attrs)=>
       let val first=buildITerm signatureValue first
           val second=buildITerm signatureValue second
           val third=D.delay(fn()=>case force third of Constant(Universe n,_,_)=>if equalInt n(int ~1)then
                 let val dec=symbolDeclaration(wrappedTermType first)
                     val extended=extendSignature dec signatureValue
                     val shifted=shiftWrappedTerm(int 1)extended(wrappedTermType second)
                 in force(sigmaFormation shifted)end
                else force(buildITerm signatureValue third)
              |_=>force(buildITerm signatureValue third))
       in force(attachTermInformation(pairFormation first second third)types attrs)end
   |Binder(kind,dec,body,types,attrs)=>
       let val declaration=buildDeclaration signatureValue dec
           fun expanded()=buildITerm(extendSignature declaration signatureValue)body
           val term=case kind of LambdaB=>lambdaFormation(expanded())|ForallB=>universal(expanded())
             |ImpB=>implication(expanded())|ExistsB=>existential(expanded())|PiB=>piFormation(expanded())
             |SigmaB=>sigmaFormation(expanded())|SubtypeB=>subtypeFormation(expanded())
             |DeltaB=>termError("Invalid occurance of "^String.str(Char.chr 196))
             |ChooseB=>termError("Invalid occurance of "^String.str(Char.chr 229))
       in force(attachTermInformation term types attrs)end
   |Constant(kind,types,attrs)=>
       let val term=case kind of BoolType=>boolean signatureValue|Truth=>truth signatureValue
              |Falsehood=>falsehood signatureValue|Universe i=>universe signatureValue i
       in force(attachTermInformation term types attrs)end
   |Binary(kind,first,second,types,attrs)=>
       let val first=buildITerm signatureValue first
           val second=buildITerm signatureValue second
           val term=case kind of AndB=>conjunction first second|OrB=>disjunction first second
              |EqualB=>equality first second|IsSubtypeB=>isSubtype first second
       in force(attachTermInformation term types attrs)end
   |Unary(NotU,body,types,attrs)=>force(attachTermInformation(negation(buildITerm signatureValue body))types attrs)
   |Cond(dec,first,second,types,attrs)=>
       let val firstDec=buildDeclaration signatureValue dec
           val secondDec=symbolDeclaration(negation(wrappedDeclarationType firstDec))
           val first=buildITerm(extendSignature firstDec signatureValue)first
           val second=buildITerm(extendSignature secondDec signatureValue)second
       in force(attachTermInformation(conditional first second)types attrs)end
   |Const(i,j,k,types,attrs)=>force(attachTermInformation(constructor signatureValue i j k)types attrs)
   |Recurse(terms,sort,types,attrs)=>
       force(attachTermInformation(recurse(map(buildITerm signatureValue)terms)(buildITerm signatureValue sort))types attrs)
   |TagId(tag,arguments)=>
       let val(name,_,functions)=force tag
           fun find functions=case force functions of F.Nil=>force(termError("cannot convert tag "^string name^" to term"))
             |F.Cons(function,rest)=>case force function of TermFunction function=>force(function arguments)|_=>find rest
       in find functions end
   |_=>let val sg=internalSignature signatureValue
       in raise Fail("Unimplemented construction: "^string(unparseITerm sg term)^"|\n")end)
 and buildDeclaration signatureValue dec:declaration=D.delay(fn()=>case force dec of SymbolDec(term,attrs)=>
       let val sg=internalSignature signatureValue
           val declaration=case force(termType sg term)of Constant(BoolType,_,_)=>axiomDeclaration(buildITerm signatureValue term)
              |_=>symbolDeclaration(buildITerm signatureValue term)
       in force(setDeclarationInformation declaration attrs)end
   |AxiomDec(term,attrs)=>force(setDeclarationInformation(axiomDeclaration(buildITerm signatureValue term))attrs)
   |DecPair(first,second,attrs)=>
       let val first=buildDeclaration signatureValue first
           val second=buildDeclaration(extendSignature first signatureValue)second
       in force(setDeclarationInformation(declarationPair second)attrs)end
   |_=>raise Fail"Only symbol_dec so far implemented")
 fun buildSignature signatureValue:signatureValue=D.delay(fn()=>case force signatureValue of
    EmptySig _=>force emptySignature
   |Extend(dec,parent,_)=>let val parent=buildSignature parent in force(extendSignature(buildDeclaration parent dec)parent)end
   |_=>raise Fail"unimplemented signature constructor")


 type parseState=tagData F.seq*signatureValue
 type parseResult=(flagged*tokenStream)L.delay
 fun tokenHead tokens=case L.force tokens of C.Nil=>NONE|C.Cons(value,_)=>SOME(L.force value)
 fun tokenTail tokens=C.defer(fn()=>case L.force tokens of C.Nil=>raise Empty|C.Cons(_,rest)=>rest)
 fun tokenKind tokens=case tokenHead tokens of NONE=>NONE|SOME token=>SOME(force token)
 fun reserved value=cell(Reserved(text value))
 fun equalToken first second=case(force first,force second)of
    (Reserved a,Reserved b)=>equalText a b|(Clear a,Clear b)=>equalText a b
   |(BinderToken a,BinderToken b)=>a=b|(InfixBinderToken a,InfixBinderToken b)=>equalText a b
   |(InfixOperatorToken a,InfixOperatorToken b)=>equalText a b|(ScanError a,ScanError b)=>equalText a b|_=>false
 fun terminates tokens token=any(equalToken token)tokens
 val dummyTokens:tokenStream=tokenCons(reserved"")(C.empty())
 fun operatorValue operator kind precedence=cell(Operator(cell operator,kind,int precedence))
 fun makeInfixBinder chars=
   let val(kind,precedence)=case string chars of
       s=>case Char.ord(String.sub(s,0))of 167=>(LambdaB,5)|183=>(PiB,80)|184=>(SigmaB,90)|182=>(ImpB,20)|187=>(DeltaB,10)|_=>raise Match
   in operatorValue(BinderOperator kind)BinR precedence end
 fun makeInfixOperator chars=if equalText chars(text":")then operatorValue(SpecialOperator chars)BinL 15 else
   let val(kind,precedence)=case string chars of"="=>(EqualB,15)|s=>case Char.ord(String.sub(s,0))of
          179=>(AndB,40)|180=>(OrB,30)|172=>(IsSubtypeB,70)|_=>raise Match
   in operatorValue(InfixOperator kind)BinR precedence end
 fun swapOperator operator operands=F.defer(fn()=>case force operands of F.Nil=>singleton operator
   |F.Cons(top,rest)=>F.cons(flaggedApplication operator top,rest))
 fun addOperator operator kind operands=F.defer(fn()=>case kind of Post=>operands
   |_=>case force operands of F.Cons(argument,rest)=>(case force rest of F.Cons(function,tail)=>
         F.cons(flaggedApplication function argument,tail)|_=>singleton(parseError(text" Insufficient arguments for operator")))
     |_=>singleton(parseError(text" Insufficient arguments for operator")))
 fun flushOperators operands operators previous compare=L.delay(fn()=>case force operators of F.Nil=>(operands,F.empty())
   |F.Cons(operator,rest)=>case force operator of Operator(kind,style,precedence)=>
       if less precedence previous orelse compare operator then(operands,operators)
       else L.force(flushOperators(addOperator kind style operands)rest previous compare)|_=>raise Match)
 fun prioritize values=
   let fun loop operands operators wasOperand values=F.defer(fn()=>case force values of F.Nil=>
          let val(result,_)=L.force(flushOperators operands operators(int ~1)(fn _=>false))in result end
        |F.Cons(value,rest)=>case force value of ParseError _=>singleton value
          |Operand _=>if wasOperand then
               loop operands operators true(F.cons(operatorValue(SpecialOperator(text""))BinL 100,values))
             else loop(F.cons(value,operands))operators true rest
          |Operator(_,Pre,_)=>loop(F.cons(value,operands))(F.cons(value,operators))false rest
          |Operator(_,style,precedence)=>
             let fun compare operator=case force operator of Operator(_,BinR,other)=>leq other precedence|_=>false
                 val(result,remaining)=L.force(flushOperators operands operators precedence
                    (if style=BinR then compare else fn _=>false))
                 val changed=swapOperator value result
             in if style=Post then loop changed remaining wasOperand rest
                else loop changed(F.cons(value,remaining))false rest end)
       val result=loop(F.empty())(F.empty())false values
   in F.defer(fn()=>if null result then singleton(parseError(text"Empty term"))else result)end
 fun foldedApplication values=foldLeft flaggedApplication(head values)(tail values)
 fun isSingletonList values=case force values of F.Cons(_,rest)=>null rest|_=>false
 fun lookupParsedName name signatureValue=
   let fun signatureAt sg i:flagged=D.delay(fn()=>case force sg of EmptySig _=>ParseError(F.append(text" Undefined symbol: ")name)
         |Extend(dec,parent,_)=>let val(found,value)=declarationAt dec(F.empty())i(int 0)
             in if found then force(L.force value)else force(signatureAt parent(add i(int 1)))end|_=>raise Match)
       and declarationAt dec stack i j=
         let val(found,value)=declarationHere dec stack i j
         in if found then(found,value)else case force stack of F.Nil=>(false,L.delay(fn()=>raise Fail""))
           |F.Cons(next,rest)=>declarationAt next rest i(add j(int 1))end
       and declarationHere dec stack i j=case force dec of DecPair(a,b,_)=>declarationAt a(F.cons(b,stack))i(add j(int 1))
         |SymbolDec(_,attrs)=>namedAttribute attrs i j
         |AxiomDec(_,attrs)=>namedAttribute attrs i j
         |Def(_,_,attrs)=>if isSingletonList attrs then namedAttribute attrs i j else raise Match
         |Data(_,_,attrs)=>if isSingletonList attrs then
             (case force(#2(force(head attrs)))of DatatypeName names=>constructorNames names i j(int 0)|_=>raise Match)
            else raise Match
       and namedAttribute attrs i j=case force attrs of F.Nil=>raise Match|F.Cons(attribute,_)=>
          (case force(#2(force attribute))of SymbolName declared=>named declared i j|_=>raise Match)
       and named declared i j=
         let val term=cell(Sym(i,j,F.empty(),singleton symbolNamed))
         in case force declared of Name actual=>if equalText name actual then
              (true,L.delay(fn()=>operandTerm term))else(false,L.delay(fn()=>raise Fail""))
           |OperatorName(actual,precedence,kind)=>if equalText name actual then
              (true,L.delay(fn()=>cell(Operator(cell(TermOperator term),kind,precedence))))
             else(false,L.delay(fn()=>raise Fail""))end
       and constructorNames names i j k=case force names of F.Nil=>(false,L.delay(fn()=>raise Fail""))
         |F.Cons(declared,rest)=>
           let val term=cell(Const(i,j,k,F.empty(),singleton symbolNamed))
               val(actual,operator)=case force declared of Name actual=>(actual,NONE)
                  |OperatorName(actual,precedence,kind)=>(actual,SOME(precedence,kind))
           in if not(equalText actual name)then constructorNames rest i j(add k(int 1))
              else(true,L.delay(fn()=>case operator of NONE=>operandTerm term
                    |SOME(precedence,kind)=>cell(Operator(cell(TermOperator term),kind,precedence))))end
   in signatureAt(internalSignature signatureValue)(int 0)end
 fun extendParseState flagged(tags,sg):parseState=case force flagged of Operand operand=>
    (case force operand of IDec dec=>(tags,extendSignature(buildDeclaration sg dec)sg)|_=>raise Match)|_=>raise Match
 fun fetchTag name tags=case force tags of F.Nil=>(false,cell(text"",F.empty(),F.empty()))
   |F.Cons(tag,rest)=>let val(actual,_,_)=force tag in if equalText actual name then(true,tag)else fetchTag name rest end


 fun reservedHead tokens value=case tokenKind tokens of SOME(Reserved actual)=>equalText actual(text value)|_=>false
 fun byteHead tokens value=case tokenKind tokens of SOME(Reserved actual)=>equalText actual(byte value)|_=>false
 fun parseOperatorType tokens=case tokenKind tokens of SOME(Reserved chars)=>
    (case string chars of"Pre"=>(Pre,tokenTail tokens)|"BinL"=>(BinL,tokenTail tokens)|"BinR"=>(BinR,tokenTail tokens)
      |"Post"=>(Post,tokenTail tokens)|_=>(BinL,tokens))|_=>(BinL,tokens)
 fun parsePrecedence tokens=case tokenKind tokens of SOME(Clear chars)=>
    if digitString chars then(readInteger chars,tokenTail tokens)else(int 1,tokens)|_=>(int 1,tokens)
 fun parseName tokens=L.delay(fn()=>case tokenKind tokens of
    SOME(Reserved chars)=>if equalText chars(text"{")then
       let val after=tokenTail tokens
       in case tokenKind after of SOME(Clear identifier)=>
          let val(kind,after)=parseOperatorType(tokenTail after)
              val(precedence,after)=parsePrecedence after
          in if reservedHead after"}"then(Ok(cell(OperatorName(identifier,precedence,kind))),tokenTail after)
             else(Bad(text"missing '}'"),dummyTokens)end
         |_=>unexpected tokens end
      else unexpected tokens
   |SOME(Clear identifier)=>(Ok(cell(Name identifier)),tokenTail tokens)
   |SOME _=>unexpected tokens|NONE=>(Bad(text"empty identifier"),dummyTokens))
 and unexpected tokens=case tokenHead tokens of NONE=>raise Match|SOME token=>
    (Bad(textConcat[text" unexpected '",displayToken token,text"' (name)"]),dummyTokens)
 fun makeDeclarationFlags names sort typed:flagged=D.delay(fn()=>case force sort of ParseError _=>force sort
   |Operand operand=>(case force operand of ITerm sort=>
       let fun declarations count names=F.defer(fn()=>case force names of F.Nil=>F.empty()|F.Cons(name,rest)=>
              let val dec=cell(SymbolDec(shiftTerm(F.empty())count sort,fromNative[symbolName name,typed]))
              in F.cons(operandDeclaration dec,declarations(add count(int 1))rest)end)
           val declarations=declarations(int 0)names
       in if null declarations then ParseError(text"empty declaration")
          else force(foldRightOne(flaggedDeclarationPair(singleton grouped))declarations)end
      |_=>raise Fail"unexpected term in make_dc")|_=>raise Fail"unexpected term in make_dc")
 fun tryIndexed tokens=if not(byteHead tokens 168)then NONE else
   let val one=tokenTail tokens
   in case tokenKind one of SOME(Clear first)=>
       let val comma=tokenTail one
       in if not(reservedHead comma",")then NONE else
          let val two=tokenTail comma
          in case tokenKind two of SOME(Clear second)=>
             let val after=tokenTail two
             in if byteHead after 169 then SOME(indexedSymbol first second,tokenTail after)
                else if reservedHead after","then
                   let val three=tokenTail after
                   in case tokenKind three of SOME(Clear third)=>
                       let val closing=tokenTail three
                       in if byteHead closing 169 then SOME(indexedConstructor first second third,tokenTail closing)else NONE end
                     |_=>NONE end
                else NONE end
            |_=>NONE end end
     |_=>NONE end


 fun parseTerm (state:parseState)terminators tokens:parseResult=L.delay(fn()=>
   let val parsed=parseTermParts state terminators tokens
       val(values,remaining)=L.force parsed
   in(foldedApplication(prioritize values),remaining)end)
 and parseTermParts (state:parseState)terminators tokens=L.delay(fn()=>
   let val(tags,sg)=state
       fun more value after=
         let val future=parseTermParts state terminators after
             val values=F.defer(fn()=> #1(L.force future))
             val remaining=C.defer(fn()=> #2(L.force future))
         in(F.cons(value,values),remaining)end
       fun one value remaining=(singleton value,remaining)
       fun afterTerm (parsed:parseResult)=C.defer(fn()=>tokenTail(#2(L.force parsed)))
       fun parsedValue (parsed:parseResult)=D.delay(fn()=>force(#1(L.force parsed)))
       fun ordinaryReserved chars=
         if equalText chars(text"if")then
           let val hyp=parseHypothesis state(singleton(reserved"then"))(tokenTail tokens)
               val declaration=parsedValue hyp val extended=extendParseState declaration state
               val yes=parseTerm extended(singleton(reserved"else"))(afterTerm hyp)
               val no=parseTerm extended terminators(afterTerm yes)
           in one(flaggedConditional declaration(parsedValue yes)(parsedValue no))(C.defer(fn()=> #2(L.force no)))end
         else if equalText chars(text"let")then
           let val dec=parseAbbreviatedDeclaration state(singleton(cell(InfixOperatorToken(text"="))))(tokenTail tokens)
               val value=parseTerm state(singleton(reserved"in"))(afterTerm dec)
               val declaration=parsedValue dec
               val body=parseTerm(extendParseState declaration state)terminators(afterTerm value)
           in one(flaggedLet declaration(parsedValue value)(parsedValue body))(C.defer(fn()=> #2(L.force body)))end
         else if equalText chars(text"recurse")then
           let val clauses=parseRecurseClauses state(F.empty())(tokenTail tokens)
               val(values,after)=L.force clauses
               val result=parseTerm state terminators after
           in one(flaggedRecurse values(parsedValue result))(C.defer(fn()=> #2(L.force result)))end
         else if equalText chars(byte 185)then
           let val argument=parseTerm state(singleton(cell(Reserved(byte 176))))(tokenTail tokens)
               val(values,remaining)=L.force(parseTermParts state terminators(afterTerm argument))
           in(F.cons(operatorValue(SpecialOperator(text""))BinR 100,F.cons(parsedValue argument,values)),remaining)end
         else if equalText chars(text",")then
           let val(values,remaining)=L.force(parseTermParts state(F.cons(reserved"typed",terminators))(tokenTail tokens))
           in(F.cons(operatorValue(SpecialOperator(text","))BinR 20,values),remaining)end
         else if equalText chars(text"typed")then
           let val result=parseTerm state terminators(tokenTail tokens)
           in(fromNative[operatorValue(SpecialOperator(text"typed"))BinL 1,parsedValue result],C.defer(fn()=> #2(L.force result)))end
         else if equalText chars(byte 168)then
           (case tryIndexed tokens of SOME(value,after)=>more value after|NONE=>unexpectedReserved chars)
         else if equalText chars(text"{")then
           let val declaration=parseDeclaration state(singleton(reserved"|"))(tokenTail tokens)
               val decl=parsedValue declaration
               val body=parseTerm(extendParseState decl state)(singleton(reserved"}"))(afterTerm declaration)
           in more(flaggedBinder SubtypeB decl(parsedValue body))(afterTerm body)end
         else if equalText chars(text"[")then
           let val declaration=parseDeclaration state(singleton(reserved"]"))(tokenTail tokens)
               val value=parsedValue declaration
               val(values,after)=L.force(parseTermParts(extendParseState value state)terminators(afterTerm declaration))
           in(F.cons(value,values),after)end
         else if equalText chars(byte 181)then more(operatorValue(SpecialOperator(text"Not"))Pre 60)(tokenTail tokens)
         else if equalText chars(text"(")then
           let val result=parseTerm state(singleton(reserved")"))(tokenTail tokens)
           in more(parsedValue result)(afterTerm result)end
         else if equalText chars(text"@")then one(parseError(text"@ not implemented "))dummyTokens
         else case tokenHead tokens of SOME token=>if terminates terminators token then(F.empty(),tokens)else unexpectedReserved chars|_=>raise Match
       and unexpectedReserved chars=one(parseError(textConcat[text" unexpected '",chars,text"' (term) tmnl: ",
           flatMap displayToken terminators,text"|"]))dummyTokens
   in case tokenKind tokens of NONE=>(F.empty(),C.empty())
     |SOME(Reserved chars)=>ordinaryReserved chars
     |SOME(BinderToken kind)=>
         let val declaration=parseDeclaration state(singleton(reserved"."))(tokenTail tokens)
             val value=parsedValue declaration
             val body=parseTerm(extendParseState value state)terminators(afterTerm declaration)
         in one(flaggedBinder kind value(parsedValue body))(C.defer(fn()=> #2(L.force body)))end
     |SOME(InfixBinderToken chars)=>more(makeInfixBinder chars)(tokenTail tokens)
     |SOME(InfixOperatorToken chars)=>more(makeInfixOperator chars)(tokenTail tokens)
     |SOME(ScanError message)=>one(parseError message)dummyTokens
     |SOME(Clear chars)=>
         let val native=string chars
         in if size native>1 andalso String.sub(native,0)= #"U"andalso digitString(tail chars)then
               more(operandTerm(bareConstant(Universe(readInteger(tail chars)))))(tokenTail tokens)
            else if List.exists(fn value=>value=native)["true","false","bool"]then
               more(operandTerm(bareConstant(case native of"true"=>Truth|"false"=>Falsehood|_=>BoolType)))(tokenTail tokens)
            else let val(found,tag)=fetchTag chars tags
                 in if found then
                      let val(_,kinds,_)=force tag
                          val parsed=parseTagArguments state(F.empty())kinds(tokenTail tokens)
                          val(arguments,after)=L.force parsed
                      in more(flaggedTag tag arguments)after end
                    else more(lookupParsedName chars sg)(tokenTail tokens)end end
   end)
 and parseHypothesis state terminators tokens:parseResult=L.delay(fn()=>
   if reservedHead tokens"["then
     let val result=parseDeclaration state(singleton(reserved"]"))(tokenTail tokens)
         val(declaration,after)=L.force result val after=tokenTail after
     in case tokenHead after of SOME token=>if terminates terminators token then(declaration,after)
          else(parseError(textConcat[text"Unexpected token '",displayToken token,text"'"]),dummyTokens)
        |NONE=>(parseError(text"Unexpected end of file"),dummyTokens)end
   else let val(term,after)=L.force(parseTerm state terminators tokens)
        in(flaggedSymbolDeclaration term(cell(Name(text"_")))(singleton nondependent),after)end)
 and parseDeclaration state terminators tokens:parseResult=L.delay(fn()=>
   let val first=parseOneDeclaration state terminators tokens
       val(value,after)=L.force first
   in if reservedHead after";"then
         let val extended=extendParseState value state
             val(rest,remaining)=L.force(parseDeclaration extended terminators(tokenTail after))
         in(flaggedDeclarationPair(singleton ungrouped)value rest,remaining)end
      else case tokenHead after of SOME token=>if terminates terminators token then(value,after)
           else raise Fail("Bdec: "^string(tokenTexts after)^"\ntmnl: "^string(flatMap displayToken terminators)^"|")
         |NONE=>raise Fail("Bdec: \ntmnl: "^string(flatMap displayToken terminators)^"|")end)
 and tokenTexts tokens=F.defer(fn()=>case L.force tokens of C.Nil=>F.empty()
    |C.Cons(token,rest)=>F.append(displayToken(L.force token))(tokenTexts rest))
 and parseOneDeclaration state terminators tokens:parseResult=L.delay(fn()=>if reservedHead tokens"("then
       let val(value,after)=L.force(parseDeclaration state(singleton(reserved")"))(tokenTail tokens))
       in(value,tokenTail after)end
     else L.force(parseDeclarationNames state(F.cons(reserved";",terminators))(F.empty())tokens))
 and parseDeclarationNames state terminators names tokens:parseResult=L.delay(fn()=>
   let val(result,after)=L.force(parseName tokens)
   in case result of Bad message=>(parseError message,dummyTokens)|Ok name=>
      if reservedHead after","then L.force(parseDeclarationNames state terminators(F.cons(name,names))(tokenTail after))
      else case tokenKind after of SOME(InfixOperatorToken chars)=>if equalText chars(text":")then
          let val(sort,remaining)=L.force(parseTerm state(F.cons(reserved";",terminators))(tokenTail after))
          in(makeDeclarationFlags(reverse(F.cons(name,names)))sort declarationTyped,remaining)end
         else(makeDeclarationFlags(reverse(F.cons(name,names)))(operandTerm(bareConstant(Universe(int 0))))declarationUntyped,after)
       |_ =>(makeDeclarationFlags(reverse(F.cons(name,names)))(operandTerm(bareConstant(Universe(int 0))))declarationUntyped,after)
   end)
 and parseAbbreviatedDeclaration state terminators tokens:parseResult=L.delay(fn()=>if reservedHead tokens"("then
       let val(value,after)=L.force(parseDeclaration state(singleton(reserved")"))(tokenTail tokens))
       in(value,tokenTail after)end
     else let val(result,after)=L.force(parseName tokens)
          in case result of Ok name=>(flaggedSymbolDeclaration(operandTerm(bareConstant(Universe(int 0))))name(F.empty()),after)
             |Bad message=>(parseError message,dummyTokens)end)
 and parseRecurseClauses state clauses tokens=L.delay(fn()=>
   let val(value,after)=L.force(parseAtomicTerm state(singleton(reserved"end"))tokens)
   in if reservedHead after"end"then
        if reservedHead(tokenTail after)"typed"then(F.cons(value,clauses),tokenTail(tokenTail after))
           else(singleton(parseError(text" recurse must be typed ")),dummyTokens)
      else L.force(parseRecurseClauses state(F.cons(value,clauses))after)end)
 and parseAtomicTerm state terminators tokens:parseResult=L.delay(fn()=>
   let val(_,sg)=state
       fun wrong()=case tokenHead tokens of SOME token=>
          (parseError(textConcat[text" unexpected '",displayToken token,text"' (aterm -- no tmnl check)"]),dummyTokens)
         |NONE=>raise Match
   in case tryIndexed tokens of SOME value=>value|NONE=>case tokenKind tokens of
       SOME(Reserved chars)=>if equalText chars(text"{")then
           let val(dec,after)=L.force(parseDeclaration state(singleton(reserved"|"))(tokenTail tokens))
               val(body,after)=L.force(parseTerm(extendParseState dec state)(singleton(reserved"}"))(tokenTail after))
           in(flaggedBinder SubtypeB dec body,after)end
         else if equalText chars(text"(")then
           let val(value,after)=L.force(parseTerm state(singleton(reserved")"))(tokenTail tokens))
           in(value,tokenTail after)end
         else wrong()
      |SOME(Clear chars)=>
         let val native=string chars
             val value=if size native>1 andalso String.sub(native,0)= #"U"andalso digitString(tail chars)then
                   operandTerm(bareConstant(Universe(readInteger(tail chars))))
                else if List.exists(fn s=>native=s)["true","false","bool"]then
                   operandTerm(bareConstant(case native of"true"=>Truth|"false"=>Falsehood|_=>BoolType))
                else lookupParsedName chars sg
         in(value,tokenTail tokens)end
      |_=>wrong()end)
 and parseTagArguments state arguments kinds tokens=L.delay(fn()=>case force kinds of F.Nil=>(reverse arguments,tokens)
   |F.Cons(kind,rest)=>
      let val(_,sg)=state
          val(arg,after)=case force kind of IntArg=>L.force(parseIntegerList tokens)
            |other=>let val(value,after)=L.force(parseAtomicTerm state(F.empty())tokens)
                    in(case other of TermArg=>cell(TagTerm(buildTerm sg value))
                        |DerivArg=>cell(TagTheorem(parseDerivation state value))|_=>raise Match,after)end
      in L.force(parseTagArguments state(F.cons(arg,arguments))rest after)end)
 and parseIntegerList tokens=L.delay(fn()=>if byteHead tokens 168 then L.force(parseIntegerItems(F.empty())(tokenTail tokens))
    else(cell(TagTerm(termError"Malformed integer list")),dummyTokens))
 and parseIntegerItems values tokens=L.delay(fn()=>case tokenKind tokens of SOME(Clear chars)=>
       if digitString chars then L.force(parseIntegerSeparator(F.cons(readInteger chars,values))(tokenTail tokens))else invalidInteger values tokens
   |SOME(Reserved chars)=>if equalText chars(byte 169)then(cell(TagInt values),tokenTail tokens)else invalidInteger values tokens
   |_=>invalidInteger values tokens)
 and invalidInteger values tokens=case tokenHead tokens of SOME token=>
       (cell(TagTerm(termError("Malformed item in integer list: "^string(displayToken token)))),dummyTokens)
      |NONE=>(cell(TagTerm(termError"Unexpected end of input")),dummyTokens)
 and parseIntegerSeparator values tokens=L.delay(fn()=>if byteHead tokens 169 then(cell(TagInt values),tokenTail tokens)
    else if reservedHead tokens","then L.force(parseIntegerItems values(tokenTail tokens))
    else(cell(TagTerm(termError(" ',' or '"^String.str(Char.chr 169)^"' expected "))),dummyTokens))
 and parseDerivation state flagged:theorem=D.delay(fn()=>case force flagged of Operand operand=>
       (case force operand of ITerm term=>force(derive state term)|_=>force(theoremError"unimplemented feature"))
      |_=>force(theoremError"unimplemented feature"))
 and derive(state:parseState)term:theorem=D.delay(fn()=>
   let val(tags,sg)=state
   in case force term of TagId(tag,arguments)=>
       let val(name,_,functions)=force tag
           fun find values=case force values of F.Nil=>force(theoremError("cannot convert tag "^string name^" to theorem"))
             |F.Cons(function,rest)=>case force function of TheoremFunction function=>force(function arguments)|_=>find rest
       in find functions end
      |Binder(DeltaB,dec,body,_,_)=>
        let val declaration=buildDeclaration sg dec
            val extended=extendSignature declaration sg
            val proof=derive(tags,extended)body
            val(ty,_,signatureValue)=L.force(internalTerm(wrappedDeclarationType declaration))
        in case force(termType signatureValue ty)of Constant(BoolType,_,_)=>force(discharge proof)
            |Constant(Universe _,_,_)=>force(generalize proof)|_=>force(theoremError"dc type not bool or univ")end
      |App(first,second,_,_)=>
        let val proof=derive state first
            val(body,_)=L.force(internalTheorem proof)
        in case force body of Binder(ForallB,_,_,_,_)=>force(specialize proof(buildITerm sg second))
           |Binder(ImpB,_,_,_,_)=>force(modusPonens proof(derive state second))
           |_=>force(theoremError("not "^String.str(Char.chr 177)^" or "^String.str(Char.chr 182)))end
      |PairTerm(first,second,_,_,_)=>
        let val a=derive state first val b=derive state second
            val script=textConcat[byte 177,text" a:bool. ",byte 177,text" b:bool.a ",byte 182,text" b ",byte 182,text" a ",byte 179,text" b"]
            val(parsed,_)=L.force(parseTerm state(singleton(reserved""))(tokenize script))
            val proof=tautology(buildTerm sg parsed)
            val specialized=specialize(specialize proof(wrappedTheoremType a))(wrappedTheoremType b)
        in force(modusPonens(modusPonens specialized a)b)end
      |Sym(i,j,_,_)=>force(axiom sg i j)
      |_=>force(theoremError(" Invalid construction: "^string(unparseITerm(internalSignature sg)term)))end)
 fun driveParse state chars=parseTerm state(singleton(reserved""))(tokenize chars)
 fun parseIterm state chars=D.delay(fn()=>let val(value,_)=L.force(driveParse state chars)in force value end)
 fun parseTermSpec sg tags chars=
   let val value=parseIterm(tags,sg)chars
   in case force value of Operand operand=>(case force operand of ITerm term=>Ok term|_=>raise Match)
      |ParseError message=>Bad message|_=>raise Match end
 fun parseWrappedTerm state chars=let val(_,sg)=state in buildTerm sg(parseIterm state chars)end


 fun oneArgument arguments=case force arguments of F.Cons(first,rest)=>if null rest then first else raise Match|_=>raise Match
 fun twoArguments arguments=case force arguments of F.Cons(first,rest)=>
      (case force rest of F.Cons(second,rest)=>if null rest then(first,second)else raise Match|_=>raise Match)
    |_=>raise Match
 fun threeArguments arguments=case force arguments of F.Cons(first,rest)=>
      let val(second,third)=twoArguments rest in(first,second,third)end|_=>raise Match
 fun reflexTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTerm term=>force(reflexivity term)|_=>raise Match)
 fun betaTag arguments:theorem=D.delay(fn()=>let val(first,second)=twoArguments arguments
    in case(force first,force second)of(TagTheorem theorem,TagInt indices)=>force(betaRewrite theorem indices)|_=>raise Match end)
 fun etaTag arguments:theorem=D.delay(fn()=>let val(first,second)=twoArguments arguments
    in case(force first,force second)of(TagTheorem theorem,TagInt indices)=>force(etaRewrite theorem indices)|_=>raise Match end)
 fun symmetryTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTheorem theorem=>force(symmetry theorem)|_=>raise Match)
 fun tautologyTag arguments:theorem=D.delay(fn()=>case force(oneArgument arguments)of TagTerm term=>force(tautology term)|_=>raise Match)
 fun conditionalTrueTag arguments:theorem=D.delay(fn()=>let val(first,second,third)=threeArguments arguments
    in case(force first,force second,force third)of(TagTheorem first,TagTheorem second,TagInt indices)=>
        force(conditionalTrueRewrite first second indices)|_=>raise Match end)
 val defaultTags:tagData F.seq=F.fromList[
   (text"reflex",F.fromList[TermArg],F.fromList[TheoremFunction reflexTag]),
   (byte 226,F.fromList[DerivArg,IntArg],F.fromList[TheoremFunction betaTag]),
   (byte 232,F.fromList[DerivArg,IntArg],F.fromList[TheoremFunction etaTag]),
   (text"symmetry",F.fromList[DerivArg],F.fromList[TheoremFunction symmetryTag]),
   (byte 186,F.fromList[TermArg],F.fromList[TheoremFunction tautologyTag]),
   (text"if_true",F.fromList[DerivArg,DerivArg,IntArg],F.fromList[TheoremFunction conditionalTrueTag])]


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


 fun findTerms predicate function term=L.delay(fn()=>
   let fun find depth path term=F.defer(fn()=>if predicate depth term then singleton(pair depth path)else children depth path term)
       and children depth path term=F.defer(fn()=>case force term of
          App(a,b,_,_)=>F.append(find depth(appendLast path(int 0))a)(find depth(appendLast path(int 1))b)
         |PairTerm(a,b,c,_,_)=>concat(fromNative[find depth(appendLast path(int 0))a,
              find depth(appendLast path(int 1))b,find depth(appendLast path(int 2))c])
         |Binder(_,dec,body,_,_)=>F.append(declaration depth(appendLast path(int 0))dec)
              (find(add depth(int 1))(appendLast path(int 1))body)
         |Unary(_,body,_,_)=>find depth(appendLast path(int 0))body
         |Binary(_,a,b,_,_)=>F.append(find depth(appendLast path(int 0))a)(find depth(appendLast path(int 1))b)
         |Cond(dec,a,b,_,_)=>concat(fromNative[declaration depth(appendLast path(int 0))dec,
              find(add depth(int 1))(appendLast path(int 1))a,find(add depth(int 1))(appendLast path(int 2))b])
         |Recurse(terms,_,_,_)=>
              let fun loop index terms=F.defer(fn()=>case force terms of F.Nil=>F.empty()|F.Cons(term,rest)=>
                    F.append(find depth(appendLast path index)term)(loop(add index(int 1))rest))
              in loop(int 0)terms end
         |_=>F.empty())
       and declaration depth path dec=F.defer(fn()=>case force dec of SymbolDec(term,_)=>find depth(appendLast path(int 0))term
          |AxiomDec(term,_)=>find depth(appendLast path(int 0))term|_=>F.empty())
       val locations=find(int 0)(F.empty())term
       fun apply term location=let val(depth,path)=force location
           val(selected,_)=L.force(selectTerm term path)
         in replaceTerm term path(function depth selected)end
       val changed=foldLeft apply term locations
       val paths=map(fn entry=>let val(_,path)=force entry in path end)locations
   in(changed,paths)end)
 fun findBetas term=
   let fun predicate _ term=case force term of App(function,_,_,_)=>
           (case force function of Binder(LambdaB,_,_,_,_)=>true|_=>false)|_=>false
       fun reduce _ term:itr=D.delay(fn()=>case force term of App(function,argument,_,_)=>
           (case force function of Binder(LambdaB,dec,body,_,_)=>force(substituteTerm dec body argument)|_=>raise Match)|_=>raise Match)
   in findTerms predicate reduce term end
 fun repeatBeta theorem paths=foldLeft betaRewrite theorem paths
 val conjunctionSchema:itr L.delay=L.delay(fn()=>
   let fun sym n=cell(Sym(int n,int 0,F.empty(),F.empty()))
       fun dec term=cell(SymbolDec(term,F.empty()))
       val body=bareBinary AndB(sym 3)(sym 2)
       val body=bareBinder ImpB(dec(sym 1))(bareBinder ImpB(dec(sym 1))body)
   in bareBinder ForallB(dec(bareConstant BoolType))(bareBinder ForallB(dec(bareConstant BoolType))body)end)
 val disjunctionSchema:itr L.delay=L.delay(fn()=>
   let fun sym n=cell(Sym(int n,int 0,F.empty(),F.empty()))
       fun dec term=cell(SymbolDec(term,F.empty()))
       val body=sym 3
       val body=bareBinder ImpB(dec(bareBinder ImpB(dec(sym 3))(sym 3)))body
       val body=bareBinder ImpB(dec(bareBinder ImpB(dec(sym 3))(sym 2)))body
       val body=bareBinder ImpB(dec(bareBinary OrB(sym 2)(sym 1)))body
   in bareBinder ForallB(dec(bareConstant BoolType))(bareBinder ForallB(dec(bareConstant BoolType))
       (bareBinder ForallB(dec(bareConstant BoolType))body))end)
 val conjunctionTheorem:theorem L.delay=L.delay(fn()=>tautology(buildITerm emptySignature(L.force conjunctionSchema)))
 val disjunctionTheorem:theorem L.delay=L.delay(fn()=>tautology(buildITerm emptySignature(L.force disjunctionSchema)))
 fun deriveConjunction first second=
   let val signatureValue=theoremSignature first
       val specialized=specialize(weaken signatureValue(L.force conjunctionTheorem))(wrappedTheoremType first)
       val specialized=specialize specialized(wrappedTheoremType second)
   in modusPonens(modusPonens specialized first)second end
 fun deriveDisjunction first second third=
   let val signatureValue=theoremSignature first
       (* The source's local th3 shadows its third parameter. *)
       val localThird=specialize(weaken signatureValue(L.force disjunctionTheorem))(wrappedTheoremType first)
       val fourth=specialize localThird(wrappedTheoremType second)
       val fifth=specialize fourth(wrappedTheoremType localThird)
   in modusPonens(modusPonens(modusPonens fifth first)second)localThird end


 fun exactlyTwo values=case force values of F.Cons(first,rest)=>(case force rest of F.Cons(second,rest)=>
       if null rest then SOME(first,second)else NONE|_=>NONE)|_=>NONE
 fun noCompletion()=cell NoValue:completion
 fun completedTheorem theorem=cell(SomeValue(cell(TheoremDone theorem))):completion
 fun completedDeclaration declaration=cell(SomeValue(cell(DeclarationDone declaration))):completion
 fun completedTerm term=cell(SomeValue(cell(TermDone term))):completion
 fun autoValidator done values=if null values then cell(SomeValue done)else noCompletion()
 fun autoSubgoals global signatureValue lookup arguments object=L.delay(fn()=>
   let fun result done=Ok(cell(F.empty(),autoValidator done))
   in case force object of TheoremSpec _=>Bad(text"Not Applicable")
     |TermSpec term=>result(cell(TermDone(buildITerm signatureValue term)))
     |DeclarationSpec declaration=>result(cell(DeclarationDone(buildDeclaration signatureValue declaration)))
     |SignatureSpec signatureValue=>result(cell(SignatureDone(buildSignature signatureValue)))end)
 fun singletonValidator theorem values=if null values then completedTheorem theorem else noCompletion()
 fun reflexSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binary(EqualB,first,second,_,_)=>
       if equalTerm first second then
          let val theorem=reflexivity(buildITerm signatureValue first)
          in Ok(cell(F.empty(),singletonValidator theorem))end
       else Bad(text"Terms not equal")
      |_=>Bad(text"cannot apply 'reflex' to specified goal"))
   |_=>Bad(text"cannot apply 'reflex' to specified goal"))
 fun createDeclarationName prefix index dec=L.delay(fn()=>case force dec of DecPair(first,second,attrs)=>
    let val one=createDeclarationName prefix index first
        val(a,next)=L.force one
        val(b,final)=L.force(createDeclarationName prefix next second)
    in(cell(DecPair(a,b,attrs)),final)end|_=>(dec,index))
 fun orderedBinderValidator generalizeRule signatureValue values editable=L.delay(fn()=>
   let fun defaults()=(editable,fromNative[signatureValue,signatureValue],noCompletion())
   in case exactlyTwo values of NONE=>defaults()|SOME(first,second)=>
      case force first of NoValue=>defaults()|SomeValue done=>
        case force done of DeclarationDone declaration=>
           (case force second of SomeValue done=>
              (case force done of TheoremDone theorem=>
                 (editable,fromNative[signatureValue,extendSignature declaration signatureValue],
                  completedTheorem(generalizeRule theorem))|_=>defaults())
            |NoValue=>if Option.isSome(exactlyTwo editable)then
                (F.fromList[true,true],fromNative[signatureValue,extendSignature declaration signatureValue],noCompletion())
               else defaults())
          |_=>defaults() end)
 fun generalizeSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ForallB,dec,body,_,_)=>
       let val(named,_)=L.force(createDeclarationName(text"xxx")(int 0)dec)
       in Ok(cell(F.fromList[DeclarationSpec named,TheoremSpec body],fromNative[lookup,lookup],F.fromList[true,false],
            orderedBinderValidator generalize signatureValue))end
      |_=>Bad(text"Cannot apply tactic to given goal"))
   |_=>Bad(text"Cannot apply tactic to given goal"))
 fun dischargeSubgoals global signatureValue lookup arguments object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ImpB,dec,body,_,_)=>
       let val(named,_)=L.force(createDeclarationName(text"hhh")(int 0)dec)
       in Ok(cell(F.fromList[DeclarationSpec named,TheoremSpec body],fromNative[lookup,lookup],F.fromList[true,false],
            orderedBinderValidator discharge signatureValue))end
      |_=>Bad(text"Cannot apply 'Disch' to specified goal"))
   |_=>Bad(text"Cannot apply 'Disch' to specified goal"))
 val autoTactic=Tactic(text"Auto",nullArguments,autoSubgoals)
 val reflexTactic=Tactic(text"Reflex",nullArguments,reflexSubgoals)
 val generalizeTactic=OrderedTactic(text"Gen",nullArguments,generalizeSubgoals)
 val dischargeTactic=OrderedTactic(text"Disch",nullArguments,dischargeSubgoals)


 fun argumentValues arguments=
   let fun collect values=case force values of F.Nil=>[]|F.Cons(x,rest)=>x::collect rest
   in case force arguments of NoValue=>NONE|SomeValue values=>SOME(collect values)end
 fun oneTheorem values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone theorem=>
       if null rest then SOME theorem else NONE|_=>NONE
 fun twoTheorems values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone first=>
       (case oneTheorem rest of SOME second=>SOME(first,second)|NONE=>NONE)|_=>NONE
 fun threeTheorems values=case force values of F.Nil=>NONE|F.Cons(first,rest)=>
    case force first of NoValue=>NONE|SomeValue done=>case force done of TheoremDone first=>
       (case twoTheorems rest of SOME(second,third)=>SOME(first,second,third)|NONE=>NONE)|_=>NONE
 fun parsedTheorem global signatureValue chars=parseDerivation(getGlobalTags global,signatureValue)
       (parseIterm(getGlobalTags global,signatureValue)chars)
 fun argumentForm descriptors expected global lookup object=case force object of TheoremSpec _=>
    bindAction(form true descriptors)(fn delayed=>case L.force delayed of NONE=>returnAction(fn()=>cell NoValue:tacticArguments)
      |SOME values=>
        let val fields=List.map force(controlItems values)
            fun strings []=[]|strings(OutText x::rest)=x::strings rest|strings(OutRadio x::rest)=x::strings rest|strings _=raise Match
            val args=strings fields
        in if List.length args=expected then returnAction(fn()=>cell(SomeValue(fromNative args))):tacticArguments action
           else raise Match end)
   |_=>raise Match
 fun completeSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[derivation],TheoremSpec goal)=>
       let val theorem=parsedTheorem global signatureValue derivation
       in if not(validTheorem theorem)then(case force theorem of TheoremError message=>Bad message|_=>raise Match)
          else let val(body,_)=L.force(internalTheorem theorem)
               in if equalTerm body goal then Ok(cell(F.empty(),singletonValidator theorem))
                  else Bad(textConcat[text"Derivation does not prove given goal\nproves: ",objectText signatureValue(cell(TheoremSpec body))])end end
   |_=>Bad(text"Goal is not a theorem"))
 val completeTactic=Tactic(text"Complete",
     argumentForm(F.fromList[FormComment(text"Complete Theorem"),MultiText(text"Derivation",text"")])1,completeSubgoals)
 fun conjunctionValidator values=case twoTheorems values of SOME(first,second)=>completedTheorem(deriveConjunction first second)|NONE=>noCompletion()
 fun conjunctionSubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec term=>
    (case force term of Binary(AndB,first,second,_,_)=>Ok(cell(F.fromList[TheoremSpec first,TheoremSpec second],conjunctionValidator))
      |_=>Bad(text"cannot apply tactic to specified goal"))
   |_=>Bad(text"cannot apply tactic to specified goal"))
 val conjunctionTactic=Tactic(text"Conjunction",nullArguments,conjunctionSubgoals)
 fun disjunctionValidator given values=case twoTheorems values of SOME(first,second)=>completedTheorem(deriveDisjunction given first second)|NONE=>noCompletion()
 fun disjunctionTermValidator values=case threeTheorems values of SOME(first,second,third)=>completedTheorem(deriveDisjunction third first second)|NONE=>noCompletion()
 fun disjunctionSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[kind,input],TheoremSpec goal)=>
      let fun result term validator=case force term of Binary(OrB,first,second,_,_)=>
           let val shifted=shiftTerm(F.empty())(int 1)goal
               val a=bareBinder ImpB(cell(AxiomDec(first,F.empty())))shifted
               val b=bareBinder ImpB(cell(AxiomDec(second,F.empty())))shifted
           in Ok(cell(F.fromList[TheoremSpec a,TheoremSpec b],validator))end|_=>Bad(text"Goal is not a disjunction")
      in if equalText kind(text"Derivation")then
           let val theorem=parsedTheorem global signatureValue input
           in if validTheorem theorem then
                let val(body,_)=L.force(internalTheorem theorem)in result body(disjunctionValidator theorem)end
              else case force theorem of TheoremError message=>Bad message|_=>raise Match end
         else if equalText kind(text"Specification")then
           (case parseTermSpec signatureValue(getGlobalTags global)input of Bad message=>Bad message|Ok term=>
              case force term of Binary(OrB,first,second,_,_)=>
                let val shifted=shiftTerm(F.empty())(int 1)goal
                    val a=bareBinder ImpB(cell(AxiomDec(first,F.empty())))shifted
                    val b=bareBinder ImpB(cell(AxiomDec(second,F.empty())))shifted
                in Ok(cell(F.fromList[TheoremSpec a,TheoremSpec b,TheoremSpec term],disjunctionTermValidator))end
               |_=>Bad(text"Specification  is not a disjunction"))
         else Bad(text"No selection")end
   |_=>Bad(text"Cannot apply 'disjunction'"))
 val disjunctionTactic=Tactic(text"Disjunction",argumentForm(F.fromList[FormComment(text"Disjunction"),
      Radio(text"Argument Type",int 0,F.fromList(List.map(fn s=>force(text s))["Derivation","Specification"])),MultiText(text"",text"")])2,
      disjunctionSubgoals)
 fun tautologySubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec term=>
    let val theorem=tautology(buildITerm signatureValue term)
    in if validTheorem theorem then Ok(cell(F.empty(),singletonValidator theorem))
       else case force theorem of TheoremError message=>Bad message|_=>raise Match end
   |_=>Bad(text"goal is not a theorem specification"))
 val tautologyTactic=Tactic(text"Taut",nullArguments,tautologySubgoals)
 fun axiomSubgoals global signatureValue lookup args object=L.delay(fn()=>case argumentValues args of SOME[name]=>
    (case force(lookupParsedName name signatureValue)of Operand operand=>(case force operand of ITerm term=>
       (case force term of Sym(i,j,_,_)=>
          let val theorem=axiom signatureValue i j
          in if validTheorem theorem then Ok(cell(F.empty(),singletonValidator theorem))
             else Bad(textConcat[text"Axiom: ",integerText i,text" ",integerText j])end
        |_=>Bad(F.append(text"No Such Axiom Name: ")name))|_=>raise Match)
      |_=>Bad(F.append(text"No Such Axiom Name: ")name))
   |_=>Bad(text"Hmm: it's failed, no name supplied perhaps?"))
 val axiomTactic=Tactic(text"Axiom",argumentForm(F.fromList[FormComment(text"Tactic: Axiom"),SingleText(text"Name Of Axiom",text"")])1,axiomSubgoals)
 fun hypotheses signatureValue sg i=F.defer(fn()=>case force sg of EmptySig _=>F.empty()
   |Extend(dec,parent,_)=>let val(_,current)=L.force(hypothesisDeclarations signatureValue dec i(int 0))
      in F.append current(hypotheses signatureValue parent(add i(int 1)))end|_=>F.empty())
 and hypothesisDeclarations signatureValue dec i j=L.delay(fn()=>case force dec of
    AxiomDec _=>(j,singleton(axiom signatureValue i j))|Def _=>(j,singleton(axiom signatureValue i j))
   |DecPair(a,b,_)=>let val(next,first)=L.force(hypothesisDeclarations signatureValue a i(add j(int 1)))
        val(final,second)=L.force(hypothesisDeclarations signatureValue b i(add next(int 1)))
     in(final,F.append first second)end|_=>(j,F.empty()))
 fun hypothesisSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    let val matches=filter(fn theorem=>let val(body,_)=L.force(internalTheorem theorem)in equalTerm goal body end)
          (hypotheses signatureValue(internalSignature signatureValue)(int 0))
    in if null matches then Bad(text"Can't find match")else Ok(cell(F.empty(),singletonValidator(head matches)))end
   |_=>Bad(text"goal is not a theorem specification"))
 val hypothesisTactic=Tactic(text"Hyp",nullArguments,hypothesisSubgoals)
 fun lemmaValidator values=case twoTheorems values of SOME(first,second)=>completedTheorem(modusPonens first second)|NONE=>noCompletion()
 fun lemmaSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of(SOME[name,specification],TheoremSpec goal)=>
    (case parseTermSpec signatureValue(getGlobalTags global)specification of Bad message=>Bad message|Ok lemma=>
       let val dec=cell(AxiomDec(lemma,singleton(symbolName(cell(Name name)))))
           val implication=bareBinder ImpB dec(shiftTerm(F.empty())(int 1)goal)
       in Ok(cell(F.fromList[TheoremSpec implication,TheoremSpec lemma],lemmaValidator))end)
   |_=>Bad(text"Goal is not a theorem specification"))
 val lemmaTactic=Tactic(text"Lemma",argumentForm(F.fromList[FormComment(text"Add lemma"),SingleText(text"Name ",text""),MultiText(text"Lemma",text"")])2,lemmaSubgoals)
 fun parsedProof global signatureValue input=parsedTheorem global signatureValue(textConcat input)
 fun equalityValidator global signatureValue first second values=case twoTheorems values of NONE=>noCompletion()|SOME(a,b)=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.",byte 177,text"b:bool.(a",byte 182,text"b)",
          byte 182,text"(b",byte 182,text"a)",byte 182,text"(a=b))"]
        val specialized=specialize(specialize proof first)second
    in completedTheorem(modusPonens(modusPonens specialized a)b)end
 fun equalitySubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec goal=>
    (case force goal of Binary(EqualB,first,second,_,_)=>
       let val a=buildITerm signatureValue first val b=buildITerm signatureValue second
           val(ty1,_,_)=L.force(internalTerm(wrappedTermType a))
           val(ty2,_,_)=L.force(internalTerm(wrappedTermType b))
       in if equalTerm ty1 ty2 andalso equalTerm ty1(bareConstant BoolType)then
           let val x=bareBinder ImpB(cell(AxiomDec(first,F.empty())))(shiftTerm(F.empty())(int 1)second)
               val y=bareBinder ImpB(cell(AxiomDec(second,F.empty())))(shiftTerm(F.empty())(int 1)first)
           in Ok(cell(F.fromList[TheoremSpec x,TheoremSpec y],equalityValidator global signatureValue a b))end
          else Bad(text"Equality not on booleans")end
      |_=>Bad(text"Cannot apply tactic to given goal"))
   |_=>Bad(text"Cannot apply tactic to given goal"))
 val equalityTactic=Tactic(text"Eq",nullArguments,equalitySubgoals)
 fun orValidator global signatureValue first second values=case oneTheorem values of NONE=>noCompletion()|SOME theorem=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.",byte 177,text"b:bool.(",
           byte 181,text"a",byte 182,text"b)=(a",byte 180,text"b))"]
        val specialized=specialize(specialize proof first)second
    in completedTheorem(subtermRewrite theorem specialized(F.empty()))end
 fun orSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    (case force goal of Binary(OrB,first,second,_,_)=>
       let val dec=cell(AxiomDec(cell(Unary(NotU,first,F.empty(),F.empty())),F.empty()))
           val sub=bareBinder ImpB dec(shiftTerm(F.empty())(int 1)second)
       in Ok(cell(singleton(cell(TheoremSpec sub)),orValidator global signatureValue(buildITerm signatureValue first)(buildITerm signatureValue second)))end
      |_=>Bad(text"Goal is not a disjunction"))
   |_=>Bad(text"Goal is not a disjunction"))
 val orTactic=Tactic(text"Or",nullArguments,orSubgoals)
 fun notValidator global signatureValue term values=case oneTheorem values of NONE=>noCompletion()|SOME theorem=>
    let val proof=parsedProof global signatureValue[byte 186,text"(",byte 177,text"a:bool.a=",byte 181,byte 181,text"a)"]
        val specialized=specialize proof term
    in completedTheorem(subtermRewrite theorem specialized(F.empty()))end
 fun notSubgoals global signatureValue lookup args object=L.delay(fn()=>case(force args,force object)of(NoValue,TheoremSpec goal)=>
    (case force goal of Unary(NotU,inner,_,_)=>(case force inner of Unary(NotU,term,_,_)=>
        Ok(cell(singleton(cell(TheoremSpec term)),notValidator global signatureValue(buildITerm signatureValue term)))
          |_=>Bad(text"cannot apply 'Not' to given goal"))
      |_=>Bad(text"cannot apply 'Not' to given goal"))
   |_=>Bad(text"cannot apply 'Not' to given goal"))
 val notTactic=Tactic(text"Not",nullArguments,notSubgoals)


 fun existsSubgoals global signatureValue lookup args object=L.delay(fn()=>case(argumentValues args,force object)of
    (SOME[input,kind],TheoremSpec goal)=>
      let fun make term extra validator=case force term of Binder(ExistsB,dec,condition,_,_)=>
           let val implication=bareBinder ImpB(cell(AxiomDec(condition,F.empty())))(shiftTerm(F.empty())(int 2)goal)
               val quantified=bareBinder ForallB dec implication
               val objects=if extra then F.fromList[TheoremSpec quantified,TheoremSpec term]else singleton(cell(TheoremSpec quantified))
           in Ok(cell(objects,validator))end
          |_=>Bad(text"term is not an existential")
          fun known given values=case oneTheorem values of SOME theorem=>completedTheorem(existsElimination given theorem)|NONE=>noCompletion()
          fun pair values=case twoTheorems values of SOME(a,b)=>completedTheorem(existsElimination a b)|NONE=>noCompletion()
      in if equalText kind(text"Derivation")then
           let val proof=parsedTheorem global signatureValue input
           in if validTheorem proof then let val(body,_)=L.force(internalTheorem proof)in make body false(known proof)end
              else case force proof of TheoremError message=>Bad message|_=>raise Match end
         else if equalText kind(text"Specification")then
           (case parseTermSpec signatureValue(getGlobalTags global)input of Ok term=>make term true pair|Bad message=>Bad message)
         else Bad(text"Invalid application of 'ExistsElim'")end
   |_=>Bad(text"Invalid application of 'ExistsElim'"))
 val existsEliminationTactic=Tactic(text"ExistsElim",argumentForm(F.fromList[FormComment(text"Exists Elimination"),
     MultiText(text"Existential Object",text""),
     Radio(text"Type of Object",int 0,F.fromList(List.map(fn s=>force(text s))["Derivation","Specification"]))])2,existsSubgoals)
 fun reduceInduction term=F.defer(fn()=>case force term of Binder(ImpB,dec,body,_,_)=>
       F.cons(declarationType dec,reduceInduction(shiftTerm(F.empty())(int ~1)body))|_=>F.empty())
 fun inductionValidator theorem paths values:completion=D.delay(fn()=>
   let val count=subtract(length values)(int 1)
       val first=take count values
       val last=head(drop count values)
       val term=case force last of SomeValue done=>(case force done of TermDone term=>term|_=>raise Match)|_=>raise Match
       val initial=repeatBeta(specialize theorem term)paths
       fun step theorem value:theorem=D.delay(fn()=>case force value of SomeValue done=>
             (case force done of TheoremDone other=>force(modusPonens theorem other)|_=>raise Match)|_=>raise Match)
       val proof=foldLeft step initial first
   in SomeValue(cell(TheoremDone proof))end)
 fun inductionSubgoals global signatureValue lookup args object=L.delay(fn()=>case force object of TheoremSpec body=>
    (case force body of Binder(ForallB,dec,condition,_,attrs)=>
       let val dataType=case force dec of SymbolDec(dataType,_)=>dataType|_=>raise Match
           val(i,j,parameters,_,_)=L.force(datatypeInformation(internalSignature signatureValue)dataType)
           val specialized=foldLeft specialize(induction(constructor signatureValue i j(int 0)))(map(buildITerm signatureValue)parameters)
           val(theoremBody,_)=L.force(internalTheorem specialized)
           val(formal,result)=case force theoremBody of Binder(_,dec,result,_,_)=>(dec,result)|_=>raise Match
           val function=cell(Binder(LambdaB,dec,condition,F.empty(),attrs))
           val(reduced,paths)=L.force(findBetas(substituteTerm formal result function))
           val subgoals=F.append(map(fn body=>cell(TheoremSpec body))(reduceInduction reduced))(singleton(cell(TermSpec function)))
       in Ok(cell(subgoals,inductionValidator specialized paths))end
      |_=>Bad(text"Goal is not universally quantified"))
   |_=>Bad(text"Goal is not universally quantified"))
 val inductionTactic=Tactic(text"Induction",nullArguments,inductionSubgoals)
 fun stripTactic state=
   let val choices=List.map(fn tactic=> #2(liftTactic tactic))[reflexTactic,hypothesisTactic]
       val choices=choices@[#2(liftOrderedTactic generalizeTactic),#2(liftOrderedTactic dischargeTactic)]
          @List.map(fn tactic=> #2(liftTactic tactic))[conjunctionTactic,orTactic,notTactic,equalityTactic,autoTactic]
       fun combine [last]=last|combine(first::rest)=tacticOrElse first(combine rest)|combine[]=raise Empty
   in repeatTactic(combine choices)state end
 fun trivialTactic state=
   let val choices=List.map(fn tactic=> #2(liftTactic tactic))[reflexTactic,hypothesisTactic,autoTactic,tautologyTactic]
       fun combine []=(fn state=>returnAction(fn()=>state))
         |combine(first::rest)=tacticOrElse first(combine rest)
   in combine choices state end

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


 type input=char F.seq
 fun input raw=text raw
 fun benchmark input=
   let fun loop hash chars=case force chars of F.Nil=>hash
         |F.Cons(c,rest)=>loop(Word64.+(Word64.*(hash,0w31),Word64.fromInt(Char.ord(force c))))rest
   in loop 0w0(program input)end
 fun signedHash word=
   let val magnitude=Word64.toLargeInt word
       val negative=Word64.andb(word,0wx8000000000000000)<>0w0
       val value=if negative then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end

end
