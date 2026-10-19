functor BenchHpgFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure R=BenchHpgRandomFn(D)
 structure C=R.C
 type text=char C.seq
 datatype numkind=IntType|IntegerType|FloatType|DoubleType
 datatype basetype=NumType of numkind|BoolType|CharType
 datatype argnode=NameType of string D.t|BasicType of basetype D.t
   |ListType of argnode D.t|TupleType of argnode F.seq|ArrayType of argnode D.t*argnode D.t
 type argtype=argnode D.t
 type htype=(string D.t*argnode F.seq)F.seq
 type typedecl=string D.t*htype
 datatype valnode=NumVal of numkind*int D.t|BoolVal of bool D.t|CharVal of char D.t
   |ListVal of valnode F.seq|TupleVal of valnode F.seq|TaggedVal of string D.t*valnode F.seq
   |ArrayVal of (valnode D.t*valnode D.t)*(valnode D.t*valnode D.t)F.seq
 type value=valnode D.t
 datatype expnode=ApplyExp of expnode D.t*expnode D.t|IdExp of string D.t|ValExp of value
   |TaggedExp of string D.t*expnode F.seq|ListExp of expnode F.seq|TupleExp of expnode F.seq
   |LambdaExp of string D.t*expnode D.t|ArrayExp of expnode D.t*expnode D.t
 type expression=expnode D.t
 type output=text->unit
 datatype env=Env of real D.t C.seq*string C.seq*string C.seq*string C.seq*
   typedecl F.seq*(string D.t*value)F.seq*(string D.t*value)F.seq*output
 fun force value=D.force value
 fun scalar x=D.delay(fn()=>x)
 fun empty()=F.empty()
 fun singleton x=F.cons(x,F.empty())
 fun head xs=case force xs of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null xs=case force xs of F.Nil=>true|_=>false
 fun map f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(D.delay(fn()=>force(f x)),map f rest))
 fun flatMap f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(f x)(flatMap f rest))
 fun zip xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()|F.Cons(x,xt)=>
   case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>F.cons(D.delay(fn()=>(x,y)),zip xt yt))
 fun pairs xs ys=map(fn p=>let val(x,y)=force p in D.delay(fn()=>(x,y))end)(zip xs ys)
 fun listPairs xs ys=map(fn p=>let val(x,y)=force p in scalar(x,force y)end)(zip xs ys)
 fun nth xs n=case force xs of F.Nil=>raise Subscript|F.Cons(x,rest)=>if n=0 then x else nth rest(n-1)
 fun last xs=case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>if null rest then x else last rest
 fun length xs=case force xs of F.Nil=>0|F.Cons(_,rest)=>1+length rest
 fun repeat x=let val root=ref NONE
     fun node()=case !root of SOME xs=>xs|NONE=>
       let val xs=BenchNeed.delay(fn()=>C.Cons(L.delay(fn()=>x),node()))
       in root:=SOME xs;xs end
   in node()end
 fun rep n x=let
     fun take n xs=F.defer(fn()=>if n<=0 then F.empty()else case BenchNeed.force xs of
        C.Nil=>F.empty()|C.Cons(v,rest)=>F.cons(D.delay(fn()=>L.force v),take(n-1)rest))
   in take n(repeat x)end
 fun cmap xcs k env=case force xcs of F.Nil=>k(F.empty())env|F.Cons(xc,rest)=>
   force xc(fn x=>cmap rest(fn xs=>k(F.cons(x,xs))))env
 fun names prefix n=C.defer(fn()=>C.cons(L.delay(fn()=>prefix^Int.toString n),names prefix(n+1)))
 fun makeEnv seeds opn=Env(R.random seeds,names "Cons" 1,names "Type" 1,names "val" 1,
       F.empty(),F.empty(),F.empty(),opn)
 fun upto n k(Env(rs,cs,ts,vs,te,ve,le,out))=case BenchNeed.force rs of
   C.Nil=>raise Empty|C.Cons(r,rest)=>let val value=R.upto n(L.force r)
     in k(scalar value)(Env(rest,cs,ts,vs,te,ve,le,out))end
 fun choose xs k=upto(length xs-1)(fn n=>k(nth xs(force n)))
 fun choosew ps k=let
     fun sum xs=case force xs of F.Nil=>0|F.Cons(p,rest)=> #1(force p)+sum rest
     fun select xs n=let val(i,x)=force(head xs)
       in if n<i then k x else select(tail xs)(n-i)end
   in upto(sum ps-1)(fn n=>select ps(force n))end
 fun takeNames 0 xs=F.empty()|takeNames n xs=F.defer(fn()=>case BenchNeed.force xs of
   C.Nil=>F.empty()|C.Cons(x,rest)=>F.cons(D.delay(fn()=>L.force x),takeNames(n-1)rest))
 fun getConstructors n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n cs)(Env(rs,C.drop n cs,ts,vs,te,ve,le,out))
 fun getTypeNames n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n ts)(Env(rs,cs,C.drop n ts,vs,te,ve,le,out))
 fun getValNames n k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(takeNames n vs)(Env(rs,cs,ts,C.drop n vs,te,ve,le,out))
 fun allTypeNames k(e as Env(_,_,_,_,te,_,_,_))=k(map(fn p=> #1(force p))te)e
 fun allTypes k(e as Env(_,_,_,_,te,_,_,_))=k te e
 fun allValues k(e as Env(_,_,_,_,_,ve,_,_))=k ve e
 fun allLambdas k(e as Env(_,_,_,_,_,_,le,_))=k le e
 fun getType name k(e as Env(_,_,_,_,te,_,_,_))=
   k(#2(force(head(F.filter(fn(n,_)=>force n=force name)te))))e
 fun getOutput k(e as Env(_,_,_,_,_,_,_,out))=k out e
 fun extendTypes tds k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,F.append tds te,ve,le,out))
 fun extendValues vds k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,te,F.append vds ve,le,out))
 fun pushLambda v k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(Env(rs,cs,ts,vs,te,ve,F.cons(scalar v,le),out))
 fun popLambda k(Env(rs,cs,ts,vs,te,ve,le,out))=
   k(force(head le))(Env(rs,cs,ts,vs,te,ve,tail le,out))
 fun text str=C.fromList(String.explode str)
 fun append a b=C.append a b
 fun string xs=String.implode(C.toList xs)
 fun number n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun base b=scalar(BasicType(scalar b))
 fun numeric k n=scalar(NumVal(k,scalar n))
 fun tuple vs=scalar(TupleVal vs)
 fun intVal n=numeric IntType n
 fun valExp v=scalar(ValExp v)
 fun idExp name=scalar(IdExp(scalar name))
 fun apply a b=scalar(ApplyExp(a,b))
 fun tagged name vs=scalar(TaggedVal(name,vs))
 fun list values=F.fromList values
 (* Prefix-consumed index producers retain memoized control spines even
    when finite AST attributes use the strict evaluation policy. *)
 fun controlFromFinite values=C.defer(fn()=>case force values of F.Nil=>C.empty()
   |F.Cons(x,rest)=>C.cons(L.delay(fn()=>x),controlFromFinite rest))
 fun finiteFromControl values=F.defer(fn()=>case BenchNeed.force values of C.Nil=>F.empty()
   |C.Cons(x,rest)=>F.cons(L.force x,finiteFromControl rest))
 fun controlFlatMap f values=C.defer(fn()=>
   let fun seek values=case BenchNeed.force values of C.Nil=>C.empty()
     |C.Cons(x,rest)=>(case BenchNeed.force(f(L.force x))of C.Nil=>seek rest
       |C.Cons(y,ys)=>C.cons(y,C.append ys(controlFlatMap f rest)))
   in seek values end)
 fun range a b=C.defer(fn()=>if a>b then C.empty()
   else C.cons(L.delay(fn()=>a),range(a+1)b))
 fun vrange(a,b)=C.defer(fn()=>case(force a,force b)of
   (NumVal(IntType,n),NumVal(IntType,m))=>C.map(intVal)(range(force n)(force m))
  |(NumVal(IntegerType,n),NumVal(IntegerType,m))=>C.map(numeric IntegerType)(range(force n)(force m))
  |(BoolVal n,BoolVal m)=>C.map(fn x=>scalar(BoolVal(scalar(x=1))))
      (range(if force n then 1 else 0)(if force m then 1 else 0))
  |(CharVal n,CharVal m)=>C.map(fn x=>scalar(CharVal(scalar(Char.chr x))))
      (range(Char.ord(force n))(Char.ord(force m)))
  |(TupleVal ns,TupleVal ms)=>let
      fun product xs=C.defer(fn()=>case BenchNeed.force xs of C.Nil=>C.fromList[C.empty()]
       |C.Cons(x,rest)=>controlFlatMap(fn v=>C.map(fn vs=>C.cons(L.delay(fn()=>v),vs))
          (product rest))(L.force x))
      val choices=C.map(fn p=>let val(n,m)=force p in vrange(n,m)end)
        (controlFromFinite(zip ns ms))
     in C.map(fn xs=>scalar(TupleVal(finiteFromControl xs)))(product choices)end
  |_=>raise Fail"Error: vrange called on non-index values")
 (* Candidate continuations are control: constructing an unchosen callback
    must not execute the callback or build its following generator. *)
 fun chooseCont options=choose(list options)(fn selected=>fn env=>force selected()env)
 fun genTypes vnts flds n dp k=
   getTypeNames n(fn names=>allTypeNames(fn old=>
   cmap(rep n(genType vnts flds(F.append old names)dp))
   (fn types=>extendTypes(listPairs names types)k)))
 and genType vnts flds names dp k=upto(vnts-1)(fn count=>
   getConstructors(force count+1)(fn cs=>
   cmap(rep(force count)(genArgtypes flds names dp))
   (fn fields=>k(scalar(listPairs cs(F.cons(scalar(F.empty()),fields)))))))
 and genArgtypes flds names dp k=upto flds(fn count=>
   cmap(rep(force count)(genArgtype names dp))(fn args=>k(scalar args)))
 and genArgtype names dp k=if dp<=1 then genBase k else
   chooseCont[
     fn()=>upto(length names-1)(fn n=>k(scalar(NameType(nth names(force n))))),
     fn()=>genBase k,
     fn()=>genArgtype names(dp-1)(fn a=>k(scalar(ListType a))),
     fn()=>upto 4(fn n=>cmap(rep(force n)(genArgtype names(dp-1)))(fn ats=>k(scalar(TupleType ats)))),
     fn()=>genIxType names(dp-1)(fn a=>genArgtype names(dp-1)(fn b=>k(scalar(ArrayType(a,b)))))]
 and genBase k=chooseCont[
     fn()=>choose(list[IntType,IntegerType,FloatType,DoubleType])(fn kind=>k(base(NumType(force kind)))),
     fn()=>k(base BoolType),fn()=>k(base CharType)]
 and genIxType names dp k=if dp<=1 then genIxBase k else
     chooseCont[fn()=>genIxBase k,fn()=>upto 4(fn n=>
       cmap(rep(force n)(genIxType names(dp-1)))(fn ats=>k(scalar(TupleType ats))))]
 and genIxBase k=chooseCont[
     fn()=>choose(list[IntType,IntegerType])(fn kind=>k(base(NumType(force kind)))),
     fn()=>k(base BoolType),fn()=>k(base CharType)]
 fun genValues n dp k=allTypeNames(fn names=>
   cmap(rep n(fn vc=>upto(length names-1)(fn r=>genValue(nth names(force r))dp vc)))
   (fn values=>getValNames n(fn names=>extendValues(pairs names values)k)))
 and genValue name dp k=if dp<=1 then getType name(fn ty=>k(tagged(#1(force(head ty)))(F.empty())))
   else getType name(fn ty=>upto(length ty-1)(fn r=>
     let val(c,args)=force(nth ty(force r))
     in cmap(map(fn a=>scalar(genIdValue(dp-1)a))args)(fn vs=>k(tagged c vs))end))
 and genIdValue dp arg k=case force arg of NameType name=>genValue name dp k
   |BasicType bt=>genBasicValue(force bt)k
   |ListType id=>upto 5(fn r=>cmap(rep(force r)(genIdValue(dp-1)id))(fn vs=>k(scalar(ListVal vs))))
   |TupleType ids=>cmap(map(fn id=>scalar(genIdValue(dp-1)id))ids)(fn vs=>k(tuple vs))
   |ArrayType(id,element)=>cmap(rep 2(genIdValue(dp-1)id))(fn bounds=>
      let val a=head bounds val b=head(tail bounds)
      in upto 4(fn r=>let val vrng=finiteFromControl(C.take(force r+1)(vrange(a,b)))
           val bound=D.delay(fn()=>force(if null vrng then b else last vrng))
         in cmap(rep(length vrng)(genIdValue(dp-1)element))
           (fn vs=>k(scalar(ArrayVal((a,bound),pairs vrng vs))))end)end)
 and genBasicValue(NumType kind)k=upto 256(fn n=>k(scalar(NumVal(kind,n))))
   |genBasicValue BoolType k=choose(list[true,false])(fn b=>k(scalar(BoolVal b)))
   |genBasicValue CharType k=upto 127(fn n=>k(scalar(CharVal(D.delay(fn()=>Char.chr(force n))))))
 fun pickExp fs dp x k=choosew fs(fn selected=>
   let val(f,p)=selected in if p x then f dp x k else pickExp fs dp x k end)
 fun genExpressions dp k=allValues(fn values=>
   cmap(map(fn pair=>let val(name,value)=force pair
     in scalar(fn xc=>genExp dp value(fn e=>xc(scalar(name,e))))end)values)k)
 and genExp dp value k=if dp<=1 then k(valExp value)else
   pickExp(list[(1,(genExpPrime,fn _=>true)),(1,(genLambda,fn _=>true))])dp value k
 and genExpPrime dp value k=case force value of
     NumVal(kind,_)=>let val choices=case kind of FloatType=>floatFns()|DoubleType=>floatFns()|_=>intFns()
       in pickExp choices dp value k end
    |BoolVal b=>pickExp(list[(1,(genNot,fn _=>true)),(1,(genAnd,fn _=>true)),
         (1,(genOr,fn _=>true)),(1,(genLess,fn _=>true))])dp b k
    |CharVal c=>pickExp(list[(1,(genDecode,fn _=>true))])dp c k
    |ListVal values=>pickExp(list[(8,(genList,fn _=>true)),
         (1,(genDrop,fn _=>true)),(1,(genTake,fn _=>true))])dp values k
    |TupleVal values=>pickExp(list[(1,(genTuple,fn _=>true))])dp values k
    |TaggedVal(name,values)=>pickExp(list[(1,(genTagged,fn _=>true))])dp(name,values)k
    |ArrayVal(bounds,pairs)=>pickExp(list[(1,(genArray,fn _=>true))])dp(bounds,pairs)k
 and genDecode dp c k=unary "chr"(dp-1)(intVal(Char.ord(force c)))k
 and genTuple dp values k=cmap(map(fn v=>scalar(genExp dp v))values)(fn es=>k(scalar(TupleExp es)))
 and genTagged dp(name,values)k=cmap(map(fn v=>scalar(genExp dp v))values)(fn es=>k(scalar(TaggedExp(name,es))))
 and genArray dp((a,b),pairs)k=genExp(dp-1)(tuple(F.cons(a,F.cons(b,F.empty()))))(fn e=>
       cmap(map(fn p=>let val(x,y)=force p in scalar(binary ":="(dp-1)x y)end)pairs)
       (fn es=>k(scalar(ArrayExp(e,scalar(ListExp es))))))
 and genPlus dp value k=case force value of NumVal(kind,n)=>
      binary "+"(dp-1)(numeric kind 1)(numeric kind(force n-1))k|_=>raise Match
 and genMinus dp value k=case force value of NumVal(kind,n)=>
      binary "-"(dp-1)(numeric kind(force n+1))(numeric kind 1)k|_=>raise Match
 and genMult dp value k=case force value of NumVal(kind,n)=>
      binary "*"(dp-1)value(numeric kind 1)k|_=>raise Match
 and genDiv dp value k=case force value of NumVal(kind,n)=>
      binary "div"(dp-1)value(numeric kind 1)k|_=>raise Match
 and genNegative dp value k=case force value of NumVal(kind,n)=>
      unary "negate"(dp-1)(numeric kind(~(force n)))k|_=>raise Match
 and genIntId dp value k=case force value of NumVal(kind,n)=>allLambdas(fn values=>
     if null values then genPlus dp value k else choose values(fn pair=>
       let val(name,other)=force pair
           val m=case force other of NumVal(IntType,m)=>m|_=>raise Match
       in genExp(dp-1)(intVal(force n-force m))(fn e=>k(apply(apply(idExp "+")(scalar(IdExp name)))e))end))
   |_=>raise Match
 and intFns()=list[(1,(genPlus,fn _=>true)),(1,(genMinus,fn _=>true)),
       (1,(genMult,fn _=>true)),(1,(genDiv,fn v=>case force v of NumVal(_,n)=>force n<>0|_=>raise Match)),
       (1,(genNegative,fn _=>true)),(1,(genIntId,fn _=>true))]
 and floatFns()=list[(1,(genPlus,fn _=>true)),(1,(genMinus,fn _=>true)),
       (1,(genMult,fn _=>true)),(1,(genNegative,fn _=>true)),(1,(genIntId,fn _=>true))]
 and genNot dp b k=unary "not"(dp-1)(scalar(BoolVal(scalar(not(force b)))))k
 and genAnd dp b k=binary "&&"(dp-1)(scalar(BoolVal(scalar true)))(scalar(BoolVal b))k
 and genOr dp b k=binary "||"(dp-1)(scalar(BoolVal(scalar false)))(scalar(BoolVal b))k
 and genLess dp b k=binary "<"(dp-1)(intVal(if force b then 0 else 1))(intVal 1)k
 and genList dp values k=cmap(map(fn v=>scalar(genExp(dp-1)v))values)(fn es=>k(scalar(ListExp es)))
 and genDrop dp values k=binary "drop"(dp-1)(intVal(length values))(scalar(ListVal(F.append values values)))k
 and genTake dp values k=binary "take"(dp-1)(intVal(length values))(scalar(ListVal(F.append values values)))k
 and genLambda dp value k=getValNames 1(fn names=>
   let val name=head names
   in genIdValue(dp-1)(base(NumType IntType))(fn argument=>
      pushLambda(name,argument)(
       genExp(dp-1)value(fn e=>
       popLambda(fn _=>chooseCont[
          fn()=>extendValues(singleton(scalar(name,argument)))
             (k(apply(scalar(LambdaExp(name,e)))(scalar(IdExp name)))),
          fn()=>genExp(dp-1)argument(fn arg=>k(apply(scalar(LambdaExp(name,e)))arg))]))))end)
 and unary name dp value k=genExp dp value(fn e=>k(apply(idExp name)e))
 and binary name dp a b k=unary name dp a(fn e=>genExp dp b(fn e'=>k(apply e e')))
 structure B=struct
   type builder=text->text
   fun id rest=rest
   fun literal s rest=append(text s)rest
   fun cat a b rest=a(C.defer(fn()=>b rest))
   fun pieces []=id|pieces(x::xs)=cat x(pieces xs)
   fun delayed f rest=C.defer(fn()=>f()rest)
   fun bracket b=pieces[literal"(",b,literal")"]
   fun output b=b(C.empty())
 end
 fun sep separator printer values=B.delayed(fn()=>
   case force values of F.Nil=>B.id|F.Cons(x,rest)=>
     B.cat(printer x)(B.delayed(fn()=>if null rest then B.id
       else B.cat(B.literal separator)(sep separator printer rest))))
 fun showNumber d n=B.delayed(fn()=>let val value=force n
   val shown=B.literal(number value)
   in if value<0 andalso d>6 then B.bracket shown else shown end)
 fun showKind kind=B.literal(case kind of IntType=>"Int"|IntegerType=>"Integer"|FloatType=>"Float"|DoubleType=>"Double")
 fun showBase bt=case bt of NumType kind=>showKind kind|BoolType=>B.literal"Bool"|CharType=>B.literal"Char"
 fun showArg d arg=B.delayed(fn()=>case force arg of NameType name=>B.literal(force name)
   |BasicType bt=>showBase(force bt)
   |ListType id=>B.pieces[B.literal"[",showArg 0 id,B.literal"]"]
   |TupleType ids=>B.pieces[B.literal"(",sep ", "(showArg 0)ids,B.literal")"]
   |ArrayType(a,b)=>let val body=B.pieces[B.literal"Array ",showArg 10 a,B.literal" ",showArg 10 b]
     in if d>=10 then B.bracket body else body end)
 fun showTypeDecl pair=B.delayed(fn()=>let val(name,variants)=force pair
     fun variant p=B.delayed(fn()=>let val(name,args)=force p
       in B.pieces[B.literal(force name),B.literal" ",sep " "(showArg 10)args]end)
   in B.pieces[B.literal"data ",B.literal(force name),B.literal" = ",sep " | " variant variants,
        B.literal" deriving (Eq)"]end)
 val asciiNames=["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL","BS","HT","LF","VT",
   "FF","CR","SO","SI","DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB","CAN","EM",
   "SUB","ESC","FS","GS","RS","US","SP"]
 fun charLiteral c=let val n=Char.ord c
    val value=case c of #"'"=>"\\'"| #"\\"=>"\\\\"| #"\a"=>"\\a"| #"\b"=>"\\b"
       | #"\f"=>"\\f"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"| #"\v"=>"\\v"
       |_=>if n=127 then "\\DEL"else if n<32 then "\\"^List.nth(asciiNames,n)else String.str c
   in "'"^value^"'"end
 fun showValue d v=B.delayed(fn()=>case force v of
   NumVal(kind,n)=>(case kind of IntType=>showNumber d n|IntegerType=>showNumber d n
      |_=>let val value=force n val b=B.literal(number value^".0")
          in if d>6 andalso value<0 then B.bracket b else b end)
  |BoolVal b=>B.literal(if force b then "True"else"False")
  |CharVal c=>B.literal(charLiteral(force c))
  |ListVal vs=>B.pieces[B.literal"[",sep ", "(showValue 0)vs,B.literal"]"]
  |TupleVal vs=>B.pieces[B.literal"(",sep ", "(showValue 0)vs,B.literal")"]
  |TaggedVal(name,vs)=>let val b=B.pieces[B.literal(force name),B.literal" ",sep " "(showValue 10)vs]
       in if d>=10 then B.bracket b else b end
  |ArrayVal((lo,hi),assocs)=>let
       fun association p=B.delayed(fn()=>let val(a,b)=force p
         in B.pieces[B.literal"(",showValue 0 a,B.literal",",showValue 0 b,B.literal")"]end)
       val b=B.pieces[B.literal"array ",showValue 10(tuple(F.cons(lo,F.cons(hi,F.empty())))),
         B.literal" [",sep ","association assocs,B.literal"]"]
     in if d>=10 then B.bracket b else b end)
 fun showValDecl pair=B.delayed(fn()=>let val(name,value)=force pair
   in B.pieces[B.literal(force name),B.literal" = ",showValue 0 value]end)
 fun showExpression d e=B.delayed(fn()=>case force e of
   ApplyExp(a,b)=>let val body=B.pieces[showExpression 10 a,B.literal" ",showExpression 11 b]
       in if d>10 then B.bracket body else body end
  |IdExp name=>let val name=force name val body=B.literal name
      in if not(Char.isAlpha(String.sub(name,0)))then B.bracket body else body end
  |ValExp v=>showValue d v
  |TaggedExp(name,es)=>let val body=B.pieces[B.literal(force name),B.literal" ",sep " "(showExpression 11)es]
     in if d>10 then B.bracket body else body end
  |ListExp es=>B.pieces[B.literal"[",sep ", "(showExpression 0)es,B.literal"]"]
  |TupleExp es=>B.pieces[B.literal"(",sep ", "(showExpression 0)es,B.literal")"]
  |LambdaExp(name,e)=>B.pieces[B.literal"(\\",B.literal(force name),B.literal" -> ",showExpression 0 e,B.literal")"]
  |ArrayExp(a,b)=>let val body=B.pieces[B.literal"array ",showExpression 11 a,B.literal" ",showExpression 11 b]
     in if d>10 then B.bracket body else body end)
 (* Source split_num returns both halves lazily; preserve the shared split. *)
 fun splitNum n chars=if n=0 then(C.empty(),chars)else
   case BenchNeed.force chars of C.Nil=>(C.empty(),C.empty())
    |C.Cons(c,rest)=>if L.force c= #"\n"then(C.empty(),C.cons(L.delay(fn()=> #" "),rest))
     else let val split=L.delay(fn()=>splitNum(n-1)rest)
          in(C.cons(c,C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
 fun span predicate chars=case BenchNeed.force chars of C.Nil=>(C.empty(),C.empty())
   |C.Cons(c,rest)=>if predicate(L.force c)then
       let val split=L.delay(fn()=>span predicate rest)
       in(C.cons(c,C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
     else(C.empty(),chars)
 fun dropWhile predicate chars=C.defer(fn()=>case BenchNeed.force chars of C.Nil=>C.empty()
    |C.Cons(c,rest)=>if predicate(L.force c)then dropWhile predicate rest else chars)
 fun splitStr n chars=C.defer(fn()=>case BenchNeed.force chars of C.Nil=>C.empty()
    |_=>let val(start,rest1)=splitNum n chars val(next,rest)=span(not o Char.isSpace)rest1
      in append start(append next(append(text"\n")(splitStr n(dropWhile Char.isSpace rest))))end)
 fun finish env=()
 fun printStr chars k=getOutput(fn out=>fn env=>(out chars;k env))
 fun printTest expressions=let
     fun pair p=B.delayed(fn()=>let val(name,e)=force p
       in B.pieces[B.literal(force name),B.literal" == ",showExpression 0 e]end)
     val out=B.output(B.pieces[B.literal"main = print [",sep ", "pair expressions,B.literal"]\n}"])
   in printStr(splitStr 70 out)finish end
 fun printProgram expressions=allTypes(fn types=>allValues(fn values=>
   let val builders=F.append(map(fn t=>scalar(showTypeDecl t))types)(map(fn v=>scalar(showValDecl v))values)
       val out=B.output(B.cat(sep ";\n"force builders)(B.literal";\n"))
   in printStr(splitStr 70 out)(printTest expressions)end))
 fun generate seeds nt dt nv dv de moduleName output=
   let val(a,b,c)=seeds
       val shownSeeds="("^number a^","^number b^","^number c^")"
       val header=B.output(B.pieces[
         B.literal"-- HPG version 1.20 dated 92/07/20\n-- Output from hpg ",
         B.literal(String.concatWith " "[shownSeeds,number nt,number dt,number nv,number dv,number de]),
         B.literal"\n-- Random number generator seeds: ",B.literal shownSeeds,
         B.literal"\n-- ",B.literal(number nt),B.literal" types, of depth ",B.literal(number dt),
         B.literal"\n-- ",B.literal(number nv),B.literal" values, of depth ",B.literal(number dv),
         B.literal"\n-- Expression depth: ",B.literal(number de),
         B.literal"\n\nmodule ",B.literal moduleName,B.literal" (main) where {\n\n"])
   in printStr header(genTypes 6 4 nt dt
         (genValues nv dv(genExpressions de printProgram)))(makeEnv seeds output)end
 fun hash chars=let fun loop h chars=case BenchNeed.force chars of C.Nil=>h
      |C.Cons(c,rest)=>loop(Word64.+(Word64.*(h,0w31),Word64.fromInt(Char.ord(L.force c))))rest
   in loop 0w0 chars end
 fun signedHash word=let val n=Word64.toLargeInt word
     val n=if Word64.andb(word,0wx8000000000000000)=0w0 then n else n-18446744073709551616
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString n)end
end
