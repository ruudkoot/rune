(* Veritas's pinned pure proof-editor protocol and core representations.
   Selected native indices are bounded signed 31-bit values; output hashes
   explicitly retain the original 64-bit modular arithmetic. *)
functor BenchVeritasFn(D:BENCH_SUSPEND)=struct
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
