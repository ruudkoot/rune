(* prefix: portable source translation. *)
(* Direct portable representation of Anna 0.400's source datatypes.
   Machine Int computations retain the pinned GHC 64-bit arithmetic. *)
functor BenchNofibAnnaFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure C=BenchIdaFiniteFn(BenchNeed)
 structure W=Word64
 structure S=BenchSigned64
 type integer=W.word D.t
 type nameNode=char F.node
 type name=char F.seq
 datatype ('a,'b)treeNode=ALeaf
   |ABranch of ('a,'b)treeNode D.t*'a D.t*'b D.t*('a,'b)treeNode D.t*integer
 datatype ('a,'b)replyNode=Ok of 'a D.t|Failed of 'b D.t
 datatype 'a setNode=MkSet of 'a F.seq
 datatype 'a maybeNode=Nothing|Just of 'a D.t
 datatype flagNode=Typecheck|Simp|NoCaseOpt|ShowHExpr|NoPretty|NoFormat|NoBaraki|SimpleInv
   |PolyLim of integer|MonoLim of integer|ForceAll|DryRun|LowerLim of integer
   |UpperLim of integer|ScaleUp of integer
 type flags=flagNode F.seq
 datatype tdefNode=TDefVar of name|TDefCons of name*tdefNode F.seq
 type typeDef=name*nameNode F.seq*(name*tdefNode F.seq)F.seq
 datatype 'a coreNode=EVar of name|ENum of integer|EConstr of name
   |EAp of 'a coreNode D.t*'a coreNode D.t
   |ELet of bool D.t*('a D.t*'a coreNode D.t)F.seq*'a coreNode D.t
   |ECase of 'a coreNode D.t*(name*('a F.seq*'a coreNode D.t)D.t)F.seq
   |ELam of 'a F.seq*'a coreNode D.t
 datatype eqnNode=EqnNVC of name*nameNode setNode D.t*nameNode setNode D.t
 type core=nameNode coreNode D.t
 type coreProgram=typeDef F.seq*(name*(nameNode F.seq*core)D.t)F.seq
 type atomicProgram=typeDef F.seq*core
 datatype ('a,'b)annNode=AVar of name|ANum of integer|AConstr of name
   |AAp of ('a,'b)ann*('a,'b)ann
   |ALet of bool D.t*('a D.t*('a,'b)ann)F.seq*('a,'b)ann
   |ACase of ('a,'b)ann*(name*('a F.seq*('a,'b)ann)D.t)F.seq
   |ALam of 'a F.seq*('a,'b)ann
 withtype ('a,'b)ann=('b D.t*('a,'b)annNode D.t)D.t
 type tvname=W.word F.seq*W.word F.seq
 datatype typeNode=TVar of tvname D.t|TArr of typeNode D.t*typeNode D.t
   |TCons of name*typeNode F.seq
 type texpr=typeNode D.t
 datatype schemeNode=Scheme of tvname F.seq*texpr
 type typeEnv=(name*schemeNode D.t)F.seq
 type subst=(tvname D.t*texpr)F.seq
 type fullTypeEnv=(name*texpr)F.seq
 datatype domainNode=Two|Lift1 of domainNode F.seq|Lift2 of domainNode F.seq
   |Func of domainNode F.seq*domainNode D.t
 type domain=domainNode D.t
 datatype routeNode=Zero|One|Stop1|Up1 of routeNode F.seq|Stop2|Up2
   |UpUp2 of routeNode F.seq|Rep of repNode D.t
 and repNode=RepTwo of frontierNode D.t|Rep1 of frontierNode D.t*repNode F.seq
   |Rep2 of frontierNode D.t*frontierNode D.t*repNode F.seq
 and frontierNode=Min1Max0 of integer*frontierElemNode F.seq*frontierElemNode F.seq
 and frontierElemNode=MkFrel of routeNode F.seq
 type route=routeNode D.t
 type representation=repNode D.t
 type frontier=frontierNode D.t
 type frontierElem=frontierElemNode D.t
 type point=domain*route
 datatype dexprNode=DXTwo|DXLift1 of dexprNode F.seq|DXLift2 of dexprNode F.seq
   |DXFunc of dexprNode F.seq*dexprNode D.t|DXVar of name
 type dexpr=dexprNode D.t
 datatype constructorNode=ConstrRec|ConstrVar of integer
 datatype acMode=Safe|Live
 datatype appInfoNode=A2|ALo1|AHi1 of integer*integer*domain
   |ALo2|AMid2|AHi2 of integer*integer*domain
 datatype 'a hexprNode=HApp of 'a hexprNode D.t*'a hexprNode D.t
   |HVAp of 'a hexprNode D.t*'a hexprNode F.seq
   |HLam of 'a F.seq*'a hexprNode D.t|HVar of 'a D.t
   |HMeet of 'a hexprNode F.seq|HPoint of route
   |HTable of(route*'a hexprNode D.t)F.seq
 type hexpr=nameNode hexprNode D.t
 datatype 'a exceptionIntNode=MkExInt of integer*'a F.seq
 type domainInt=domainNode exceptionIntNode D.t
 type oneFuncSize=integer*domainNode F.seq
 datatype infoNode=SAResult of name*domain*route
   |SASearch of acMode*name*integer*integer
   |SASizes of name*oneFuncSize F.seq*oneFuncSize F.seq
   |SAHExpr of name*hexpr|SASL of routeNode F.seq*routeNode F.seq
   |SAGiveUp of nameNode F.seq
 type token=integer*name
 datatype 'a parseNode=PFail of token C.seq|POk of 'a D.t*token C.seq
 type 'a parser=token C.seq->'a parseNode L.delay
 datatype partialNode=NoOp|FoundOp of name*core
 type limits=integer*integer*integer*integer*integer
 type static=(name*dexpr)F.seq*(name*domain)F.seq*(name*constructorNode F.seq)F.seq*
    (name*nameNode F.seq)F.seq*flags*limits*(domain*integer)F.seq
 fun force value=D.force value
 fun cell value=D.delay(fn()=>value)
 fun int n=cell(W.fromInt n)
 fun add a b=D.delay(fn()=>W.+(force a,force b))
 fun subtract a b=D.delay(fn()=>W.-(force a,force b))
 fun multiply a b=D.delay(fn()=>W.*(force a,force b))
 fun divide a b=D.delay(fn()=>S.divide(force a,force b))
 fun quotient a b=D.delay(fn()=>S.quotient(force a,force b))
 fun modulo a b=D.delay(fn()=>S.modulo(force a,force b))
 fun negative a=D.delay(fn()=>S.negate(force a))
 fun less a b=S.less(force a,force b)
 fun leq a b=S.leq(force a,force b)
 fun equalInt a b=force a=force b
 fun signed n=let val word=force n val magnitude=W.toLargeInt word
       val value=if S.negative word then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString value)end
 fun small n=let val word=force n
   in if S.negative word then ~(W.toInt(S.magnitude word))else W.toInt word end
 fun name s=F.fromList(String.explode s)
 fun string s=String.implode(F.toList s)
 fun empty()=F.empty()
 fun head xs=case force xs of F.Nil=>raise Empty|F.Cons(x,_)=>x
 fun tail xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(_,rest)=>rest)
 fun null xs=case force xs of F.Nil=>true|_=>false
 fun singleton value=F.cons(value,F.empty())
 fun map f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(D.delay(fn()=>force(f x)),map f rest))
 fun flatMap f xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.append(f x)(flatMap f rest))
 fun pair a b=cell(a,b)
 fun triple a b c=cell(a,b,c)
 fun length xs=D.delay(fn()=>let
       fun loop n xs=case force xs of F.Nil=>n|F.Cons(_,rest)=>loop(W.+(n,0w1))rest
   in loop 0w0 xs end)
 fun compareLists compare xs ys=case(force xs,force ys)of
    (F.Nil,F.Nil)=>EQUAL|(F.Nil,_)=>LESS|(_,F.Nil)=>GREATER
   |(F.Cons(x,xt),F.Cons(y,yt))=>(case compare x y of EQUAL=>compareLists compare xt yt|answer=>answer)
 fun equalLists equal xs ys=case force xs of F.Nil=>null ys|F.Cons(x,xt)=>
   case force ys of F.Nil=>false|F.Cons(y,yt)=>equal x y andalso equalLists equal xt yt
 fun compareInt a b=if equalInt a b then EQUAL else if less a b then LESS else GREATER
 fun compareName xs ys=compareLists(fn a=>fn b=>Char.compare(force a,force b))xs ys
 fun equalName xs ys=equalLists(fn a=>fn b=>force a=force b)xs ys
 fun myFail message=raise Fail("\n"^message^"\n")
 fun panic message=raise Fail("\nPanic! (the "^String.str(Char.chr 96)^"impossible' happened):\n"^message^"\n")

(* compare: portable source translation. *)
 fun thenCompare EQUAL next=next()|thenCompare answer _=answer
 fun domainTag Two=0|domainTag(Lift1 _)=1|domainTag(Lift2 _)=2|domainTag(Func _)=3
 fun compareDomain a b=
   let val x=force a val y=force b
   in case(x,y)of
      (Two,Two)=>EQUAL
     |(Lift1 xs,Lift1 ys)=>compareLists compareDomain xs ys
     |(Lift2 xs,Lift2 ys)=>compareLists compareDomain xs ys
     |(Func(xs,x),Func(ys,y))=>thenCompare(compareLists compareDomain xs ys)(fn()=>compareDomain x y)
     |_=>Int.compare(domainTag x,domainTag y)end
 fun equalDomain a b=compareDomain a b=EQUAL
 fun routeTag Zero=0|routeTag One=1|routeTag Stop1=2|routeTag(Up1 _)=3
   |routeTag Stop2=4|routeTag Up2=5|routeTag(UpUp2 _)=6|routeTag(Rep _)=7
 fun repTag(RepTwo _)=0|repTag(Rep1 _)=1|repTag(Rep2 _)=2
 fun compareRoute a b=
   let val x=force a val y=force b
   in case(x,y)of(Zero,Zero)=>EQUAL|(One,One)=>EQUAL|(Stop1,Stop1)=>EQUAL
     |(Stop2,Stop2)=>EQUAL|(Up2,Up2)=>EQUAL
     |(Up1 xs,Up1 ys)=>compareLists compareRoute xs ys
     |(UpUp2 xs,UpUp2 ys)=>compareLists compareRoute xs ys
     |(Rep x,Rep y)=>compareRep x y
     |_=>Int.compare(routeTag x,routeTag y)end
 and compareRep a b=
   let val x=force a val y=force b
   in case(x,y)of
      (RepTwo x,RepTwo y)=>compareFrontier x y
     |(Rep1(x,xs),Rep1(y,ys))=>thenCompare(compareFrontier x y)(fn()=>compareLists compareRep xs ys)
     |(Rep2(x,z,xs),Rep2(y,w,ys))=>thenCompare(compareFrontier x y)(fn()=>
          thenCompare(compareFrontier z w)(fn()=>compareLists compareRep xs ys))
     |_=>Int.compare(repTag x,repTag y)end
 and compareFrontier a b=
   let val Min1Max0(n,xs,ys)=force a val Min1Max0(m,zs,ws)=force b
   in thenCompare(compareInt n m)(fn()=>thenCompare(compareLists compareFrel xs zs)
       (fn()=>compareLists compareFrel ys ws))end
 and compareFrel a b=let val MkFrel xs=force a val MkFrel ys=force b
   in compareLists compareRoute xs ys end
 fun equalRoute a b=compareRoute a b=EQUAL
 fun equalRep a b=compareRep a b=EQUAL
 fun equalFrontier a b=compareFrontier a b=EQUAL
 fun equalFrel a b=compareFrel a b=EQUAL
 fun equalType a b=case(force a,force b)of
    (TVar x,TVar y)=>let val(a,b)=force x val(c,d)=force y
      in equalLists equalInt a c andalso equalLists equalInt b d end
   |(TArr(a,b),TArr(c,d))=>equalType a c andalso equalType b d
   |(TCons(name,xs),TCons(other,ys))=>equalName name other andalso equalLists equalType xs ys
   |_=>false
 fun equalDexpr a b=case(force a,force b)of
    (DXTwo,DXTwo)=>true|(DXLift1 xs,DXLift1 ys)=>equalLists equalDexpr xs ys
   |(DXLift2 xs,DXLift2 ys)=>equalLists equalDexpr xs ys
   |(DXFunc(xs,x),DXFunc(ys,y))=>equalLists equalDexpr xs ys andalso equalDexpr x y
   |(DXVar x,DXVar y)=>equalName x y|_=>false
 fun compareConstructor a b=case(force a,force b)of
    (ConstrRec,ConstrRec)=>EQUAL|(ConstrRec,_)=>LESS|(_,ConstrRec)=>GREATER
   |(ConstrVar x,ConstrVar y)=>compareInt x y
 fun equalFlag a b=
   let fun tag Typecheck=0|tag Simp=1|tag NoCaseOpt=2|tag ShowHExpr=3
        |tag NoPretty=4|tag NoFormat=5|tag NoBaraki=6|tag SimpleInv=7
        |tag(PolyLim _)=8|tag(MonoLim _)=9|tag ForceAll=10|tag DryRun=11
        |tag(LowerLim _)=12|tag(UpperLim _)=13|tag(ScaleUp _)=14
       val x=force a val y=force b
   in case(x,y)of(PolyLim x,PolyLim y)=>equalInt x y
      |(MonoLim x,MonoLim y)=>equalInt x y|(LowerLim x,LowerLim y)=>equalInt x y
      |(UpperLim x,UpperLim y)=>equalInt x y|(ScaleUp x,ScaleUp y)=>equalInt x y
      |_=>tag x=tag y end

(* lists: portable source translation. *)
 fun filter predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,filter predicate rest)else filter predicate rest)
 fun zipWith f xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()|F.Cons(x,xt)=>
   case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>F.cons(D.delay(fn()=>force(f x y)),zipWith f xt yt))
 fun zip xs ys=zipWith pair xs ys
 fun zipExact f xs ys=F.defer(fn()=>case(force xs,force ys)of(F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(y,yt))=>F.cons(D.delay(fn()=>force(f x y)),zipExact f xt yt)
   |_=>panic"myZipWith2: unequal lists")
 fun zip3Exact f xs ys zs=F.defer(fn()=>case(force xs,force ys,force zs)of(F.Nil,F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(y,yt),F.Cons(z,zt))=>F.cons(D.delay(fn()=>force(f x y z)),zip3Exact f xt yt zt)
   |_=>panic"myZipWith3: unequal lists")
 fun foldLeft f initial xs=D.delay(fn()=>
   let fun loop acc xs=case force xs of F.Nil=>force acc
        |F.Cons(x,rest)=>loop(D.delay(fn()=>force(f acc x)))rest
   in loop initial xs end)
 fun foldRight f initial xs=D.delay(fn()=>case force xs of F.Nil=>force initial
   |F.Cons(x,rest)=>force(f x(foldRight f initial rest)))
 fun all predicate xs=case force xs of F.Nil=>true|F.Cons(x,rest)=>predicate x andalso all predicate rest
 fun any predicate xs=case force xs of F.Nil=>false|F.Cons(x,rest)=>predicate x orelse any predicate rest
 fun take n xs=F.defer(fn()=>if leq n(int 0)then F.empty()else case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>F.cons(x,take(subtract n(int 1))rest))
 fun drop n xs=F.defer(fn()=>if leq n(int 0)then xs else case force xs of F.Nil=>F.empty()
   |F.Cons(_,rest)=>drop(subtract n(int 1))rest)
 fun nth xs index=case force xs of F.Nil=>panic"(##) (1)"
   |F.Cons(x,rest)=>if equalInt index(int 0)then x else nth rest(subtract index(int 1))
 fun reverse xs=F.defer(fn()=>let
      fun loop xs acc=case force xs of F.Nil=>acc|F.Cons(x,rest)=>loop rest(F.cons(x,acc))
   in loop xs(F.empty())end)
 fun last xs=case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>if null rest then x else last rest
 fun init xs=F.defer(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then F.empty()else F.cons(x,init rest))
 fun repeat value=let val slot=ref NONE
      fun node()=case !slot of SOME root=>root|NONE=>
        let val root=L.delay(fn()=>C.Cons(L.delay(fn()=>value),node()))
        in slot:=SOME root;root end
   in node()end
 fun fromControl xs=F.defer(fn()=>case L.force xs of C.Nil=>F.empty()
   |C.Cons(x,rest)=>F.cons(L.force x,fromControl rest))
 fun copy n value=fromControl(C.take(Int.max(0,small n))(repeat value))
 fun intsFrom n=C.defer(fn()=>C.cons(L.delay(fn()=>n),intsFrom(add n(int 1))))
 fun intsFromTo lo hi=F.defer(fn()=>if less hi lo then F.empty()
   else F.cons(lo,intsFromTo(add lo(int 1))hi))
 fun listVariants xs alternatives=F.defer(fn()=>case(force xs,force alternatives)of(F.Nil,F.Nil)=>F.empty()
   |(F.Cons(x,xt),F.Cons(rs,rst))=>
      F.append(map(fn replacement=>F.cons(replacement,xt))rs)
        (map(fn suffix=>F.cons(x,suffix))(listVariants xt rst))
   |_=>panic"myListVariants: unequal lists")
 (* Source enumerates the first list fastest within each suffix. *)
 fun cartesianProduct xss=F.defer(fn()=>case force xss of F.Nil=>singleton(F.empty())
   |F.Cons(xs,rest)=>flatMap(fn suffix=>map(fn x=>F.cons(x,suffix))xs)(cartesianProduct rest))
 fun mySeq equal value next=if equal value value then next()else raise Match
 fun insertionSort compare xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>
     let fun insert xs=F.defer(fn()=>case force xs of F.Nil=>singleton x
           |F.Cons(y,yt)=>if compare x y<>GREATER then F.cons(x,xs)else F.cons(y,insert yt))
     in insert(insertionSort compare rest)end)
 fun removeDuplicates equal xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>(case force rest of F.Nil=>singleton x|F.Cons(y,yt)=>
       if equal x y then removeDuplicates equal rest else F.cons(x,removeDuplicates equal rest)))
 fun unzip values=
   let val result=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
        |F.Cons(pair,rest)=>let val(a,b)=force pair val(xs,ys)=unzip rest
          in(F.cons(a,xs),F.cons(b,ys))end)
   in(F.defer(fn()=> #1(L.force result)),F.defer(fn()=> #2(L.force result)))end
 fun mapFirst f values=map(fn value=>let val(a,b)=force value in pair(f a)b end)values
 fun mapSecond f values=map(fn value=>let val(a,b)=force value in pair a(f b)end)values
 fun mapAccumulate(f:'a D.t->'b D.t->'a D.t*'c D.t)initial values=L.delay(fn()=>case force values of F.Nil=>(initial,F.empty())
   |F.Cons(x,rest)=>let val step=L.delay(fn()=>f initial x)
       val restResult=mapAccumulate f(D.delay(fn()=>force(#1(L.force step))))rest
       val result=F.defer(fn()=> #2(L.force restResult))
     in(D.delay(fn()=>force(#1(L.force restResult))),F.cons(D.delay(fn()=>force(#2(L.force step))),result))end)
 fun interleave separator lists=F.defer(fn()=>case force lists of F.Nil=>F.empty()
   |F.Cons(xs,rest)=>if null rest then xs
     else F.append xs(F.append separator(interleave separator rest)))
 fun set values=cell(MkSet values)
 fun setValues value=case force value of MkSet xs=>xs
 fun setEmpty()=set(F.empty())
 fun setSingleton value=set(singleton value)
 fun setFromList compare values=set(removeDuplicates(fn a=>fn b=>compare a b=EQUAL)(insertionSort compare values))
 fun setUnion compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>ys
       |F.Cons(x,xt)=>(case force ys of F.Nil=>xs|F.Cons(y,yt)=>
          case compare x y of LESS=>F.cons(x,merge xt ys)
           |EQUAL=>F.cons(x,merge xt yt)|GREATER=>F.cons(y,merge xs yt)))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setIntersection compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
       |F.Cons(x,xt)=>(case force ys of F.Nil=>F.empty()|F.Cons(y,yt)=>
          case compare x y of LESS=>merge xt ys|EQUAL=>F.cons(x,merge xt yt)|GREATER=>merge xs yt))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setSubtract compare left right=D.delay(fn()=>
   let fun merge xs ys=F.defer(fn()=>case force xs of F.Nil=>F.empty()
       |F.Cons(x,xt)=>(case force ys of F.Nil=>xs|F.Cons(y,yt)=>
          case compare x y of LESS=>F.cons(x,merge xt ys)|EQUAL=>merge xt yt|GREATER=>merge xs yt))
   in MkSet(merge(setValues left)(setValues right))end)
 fun setMember compare value collection=
   let fun seek xs=case force xs of F.Nil=>false|F.Cons(x,rest)=>
        case compare value x of EQUAL=>true|GREATER=>seek rest|LESS=>false
   in seek(setValues collection)end
 fun setSubset compare left right=all(fn value=>setMember compare value right)(setValues left)
 fun setUnionList compare values=foldLeft(setUnion compare)(setEmpty())values

(* parser-control: portable source translation. *)
 type chars=char C.seq
 fun input source=C.fromList(String.explode source)
 fun charUncons values=case L.force values of C.Nil=>NONE|C.Cons(x,rest)=>SOME(L.force x,rest)
 fun charSpan predicate chars=case charUncons chars of NONE=>(C.empty(),C.empty())
   |SOME(c,rest)=>if predicate c then let val split=L.delay(fn()=>charSpan predicate rest)
       in(C.cons(L.delay(fn()=>c),C.defer(fn()=> #1(L.force split))),C.defer(fn()=> #2(L.force split)))end
     else(C.empty(),chars)
 fun charsToName chars=F.defer(fn()=>case charUncons chars of NONE=>F.empty()
   |SOME(c,rest)=>F.cons(cell c,charsToName rest))
 fun prefixChars prefix chars=
   let fun loop [] chars=SOME chars|loop(c::cs)chars=case charUncons chars of
        SOME(d,rest)=>if c=d then loop cs rest else NONE|NONE=>NONE
   in loop(String.explode prefix)chars end
 fun token line text rest=C.cons(L.delay(fn()=>(line,text)),rest)
 val endTokens:token C.seq=C.fromList[(int 999999,name"$$$")]
 fun lex line chars=C.defer(fn()=>
   let fun ordinary()=case charUncons chars of NONE=>endTokens
         |SOME(c,rest)=>if c= #"{"then comment line rest
           else if c= #"\n"then lex(add line(int 1))rest
           else if c= #" "orelse c= #"\t"then lex line rest
           else if Char.isDigit c then let val(digits,tail)=charSpan Char.isDigit rest
             in token line(F.cons(cell c,charsToName digits))(lex line tail)end
           else if Char.isAlpha c then let val(identifier,tail)=charSpan
                  (fn c=>Char.isAlpha c orelse Char.isDigit c orelse c= #"_")rest
             in token line(F.cons(cell c,charsToName identifier))(lex line tail)end
           else token line(name(String.str c))(lex line rest)
       fun two()=case charUncons chars of NONE=>ordinary()|SOME(c,rest)=>
         case L.force rest of C.Nil=>ordinary()|C.Cons(d,tail)=>
           if not(List.exists(fn x=>x=c)[#"=",#">",#"<",#"-",#";"])then ordinary()
           else let val d=L.force d
           in if List.exists(fn s=>s=String.implode[c,d])["==",">=","<=","->",";;"]
              then token line(name(String.implode[c,d]))(lex line tail)else ordinary()end
   in case prefixChars"::="chars of SOME tail=>token line(name"::=")(lex line tail)|NONE=>two()end)
 and comment line chars=C.defer(fn()=>case charUncons chars of NONE=>lex line(C.empty())
   |SOME(c,rest)=>if c= #"}"then lex line rest else
      comment(if c= #"\n"then add line(int 1)else line)rest)
 fun failed result=case L.force result of PFail _=>true|POk _=>false
 fun parsedItem result=case L.force result of POk(value,_)=>value|_=>raise Match
 fun parsedRest result=case L.force result of PFail rest=>rest|POk(_,rest)=>rest
 fun paLiteral literal tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,rest)=>let val(_,text)=L.force tok
      in if equalName literal text then POk(literal,rest)else PFail tokens end)
 fun paAlts alternatives tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,_)=>let val(_,text)=L.force tok
       fun choose []=PFail(C.empty())
         |choose((predicate,parser)::rest)=if predicate text then L.force(parser tokens)else choose rest
     in choose alternatives end)
 fun paThen2 combine p q tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest|POk(b,rest)=>POk(combine a b,rest))
 fun paThen3 combine p q r tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest
     |POk(b,rest)=>case L.force(r rest)of PFail rest=>PFail rest
       |POk(c,rest)=>POk(combine a b c,rest))
 fun paThen4 combine p q r s tokens=L.delay(fn()=>case L.force(p tokens)of PFail rest=>PFail rest
   |POk(a,rest)=>case L.force(q rest)of PFail rest=>PFail rest
     |POk(b,rest)=>case L.force(r rest)of PFail rest=>PFail rest
       |POk(c,rest)=>case L.force(s rest)of PFail rest=>PFail rest
         |POk(d,rest)=>POk(combine a b c d,rest))
 fun paZeroOrMore parser tokens=L.delay(fn()=>case L.force(parser tokens)of
   PFail _=>POk(F.empty(),tokens)
  |POk(value,rest)=>case L.force(paZeroOrMore parser rest)of
     PFail _=>POk(singleton value,rest)
    |POk(values,rest)=>POk(F.cons(value,values),rest))
 fun paOneOrMore parser=paThen2(fn x=>fn xs=>F.cons(x,xs))parser(paZeroOrMore parser)
 fun paOneOrMoreSep parser separator tokens=L.delay(fn()=>case L.force(parser tokens)of
    PFail _=>PFail tokens
   |POk(value,rest)=>(case L.force(separator rest)of PFail _=>POk(singleton value,rest)
     |POk(_,after)=>case L.force(paOneOrMoreSep parser separator after)of
       PFail _=>POk(singleton value,rest)|POk(values,rest)=>POk(F.cons(value,values),rest)))
 fun paApply parser f tokens=L.delay(fn()=>case L.force(parser tokens)of
   PFail rest=>PFail rest|POk(value,rest)=>POk(f value,rest))
 fun paSatisfy predicate tokens=L.delay(fn()=>case L.force tokens of C.Nil=>PFail(C.empty())
   |C.Cons(tok,rest)=>let val(_,text)=L.force tok
     in if predicate text then POk(text,rest)else PFail rest end)
 fun paEmpty value tokens=L.delay(fn()=>POk(value,tokens))
 fun literal s=paLiteral(name s)
 fun tokenIs s text=equalName(name s)text
 fun numericValue chars=
   let val digits=map(fn c=>int(Char.ord(force c)-48))(reverse chars)
       fun powers scale digits=F.defer(fn()=>case force digits of F.Nil=>F.empty()
         |F.Cons(d,rest)=>F.cons(multiply scale d,powers(multiply(int 10)scale)rest))
   in foldLeft add(int 0)(powers(int 1)digits)end

(* read-table: portable source translation. *)
 fun paNumber tokens=paApply(paSatisfy(fn text=>case force text of F.Nil=>false
   |F.Cons(c,_)=>Char.isDigit(force c)))numericValue tokens
 fun tableLex line chars=C.defer(fn()=>case charUncons chars of NONE=>C.empty()
   |SOME(c,rest)=>if c= #"\n"then tableLex(add line(int 1))rest
      else if c= #" "orelse c= #"\t"then tableLex line rest
      else if List.exists(fn x=>x=c)[#"(",#")",#"[",#"]",#","]
        then token line(name(String.str c))(tableLex line rest)
      else let
          fun keyword []=NONE
            |keyword((source,target)::more)=case prefixChars source chars of
               SOME tail=>SOME(target,tail)|NONE=>keyword more
        in case keyword[("Two","T"),("Func","F"),("Lift1","L"),("Lift2","M")]of
          SOME(text,tail)=>token line(name text)(tableLex line tail)
         |NONE=>if Char.isDigit c then
             let val(digits,tail)=charSpan Char.isDigit rest
             in token line(F.cons(cell c,charsToName digits))(tableLex line tail)end
           else myFail("Illegal character "^String.str c^" in lattice table, line "^signed line^".")end)
 fun tableComma parser=paThen2(fn a=>fn _=>a)parser(literal",")
 fun tableListMain parser tokens=paAlts[
     (tokenIs"]",paApply(literal"]")(fn _=>F.empty())),
     (fn _=>true,paThen3(fn xs=>fn x=>fn _=>F.append xs(singleton x))
        (paZeroOrMore(tableComma parser))parser(literal"]"))]tokens
 fun tableList parser=paThen2(fn _=>fn values=>values)(literal"[")(tableListMain parser)
 val tableDomainSlot:domainNode parser option ref=ref NONE
 fun tableDomain tokens=
   let val parser=case !tableDomainSlot of SOME p=>p|NONE=>
       let val p=paAlts[
         (tokenIs"(",paThen3(fn _=>fn d=>fn _=>d)(literal"(")tableDomain(literal")")),
         (tokenIs"T",paApply(literal"T")(fn _=>cell Two)),
         (tokenIs"L",paThen2(fn _=>fn ds=>cell(Lift1 ds))(literal"L")(tableList tableDomain)),
         (tokenIs"M",paThen2(fn _=>fn ds=>cell(Lift2 ds))(literal"M")(tableList tableDomain)),
         (tokenIs"F",paThen3(fn _=>fn ds=>fn d=>cell(Func(ds,d)))
             (literal"F")(tableList tableDomain)tableDomain)]
       in tableDomainSlot:=SOME p;p end
   in parser tokens end
 fun tablePair first second=paThen4(fn _=>fn a=>fn _=>fn b=>pair a b)
    (literal"(")first(literal",")(paThen2(fn b=>fn _=>b)second(literal")"))
 val tableParser:(domain*integer)F.node parser=tableList(tablePair tableDomain paNumber)
 fun readTable chars=
   case L.force(tableParser(tableLex(int 1)chars))of
      PFail rest=>(case L.force rest of C.Nil=>myFail"Unexpected end of lattice table"
        |C.Cons(tok,_)=>let val(line,_)=L.force tok
            in myFail("Syntax error in lattice table, line "^signed line^".")end)
     |POk(values,rest)=>(case L.force rest of C.Nil=>values
        |C.Cons(tok,_)=>let val(line,_)=L.force tok
            in myFail("Syntax error in lattice table, line "^signed line^".")end)

(* core-parser: portable source translation. *)
 fun cached slot build tokens=
   let val parser=case !slot of SOME p=>p|NONE=>let val p=build()in slot:=SOME p;p end
   in parser tokens end
 fun inNames choices text=List.exists(fn s=>tokenIs s text)choices
 val keywords=["let","letrec","case","in","of","end"]
 fun firstChar text=force(head text)
 fun isName text=Char.isAlpha(firstChar text)andalso not(inNames keywords text)
 fun isConstructor text=firstChar text>= #"A"andalso firstChar text<= #"Z"andalso not(inNames keywords text)
 val paName=paSatisfy isName
 val paConstructorName=paSatisfy isConstructor
 val relations=["<=","<",">=",">","==","~="]
 val paRelation=paSatisfy(inNames relations)
 fun trailingSemi parser=paThen2(fn a=>fn _=>a)parser(literal";")
 type scDefinition=name*(nameNode F.seq*core)D.t
 type coreBinding=name*core
 type constructorAlt=name*tdefNode F.seq
 val programSlot:coreProgram parser option ref=ref NONE
 val typeDefsSlot:typeDef F.node parser option ref=ref NONE
 val typeDefSlot:typeDef parser option ref=ref NONE
 val constructorAltsSlot:constructorAlt F.node parser option ref=ref NONE
 val constructorAltSlot:constructorAlt parser option ref=ref NONE
 val typeExprSlot:tdefNode parser option ref=ref NONE
 val scDefsSlot:scDefinition F.node parser option ref=ref NONE
 val scSlot:scDefinition parser option ref=ref NONE
 val exprSlot:nameNode coreNode parser option ref=ref NONE
 val letSlot:nameNode coreNode parser option ref=ref NONE
 val letrecSlot:nameNode coreNode parser option ref=ref NONE
 val bindingsSlot:coreBinding F.node parser option ref=ref NONE
 val bindingSlot:coreBinding parser option ref=ref NONE
 val caseSlot:nameNode coreNode parser option ref=ref NONE
 val alternativesSlot:scDefinition F.node parser option ref=ref NONE
 val alternativeSlot:scDefinition parser option ref=ref NONE
 val lambdaSlot:nameNode coreNode parser option ref=ref NONE
 val expr1Slot:nameNode coreNode parser option ref=ref NONE
 val expr2Slot:nameNode coreNode parser option ref=ref NONE
 val expr3Slot:nameNode coreNode parser option ref=ref NONE
 val expr4Slot:nameNode coreNode parser option ref=ref NONE
 val expr5Slot:nameNode coreNode parser option ref=ref NONE
 val expr6Slot:nameNode coreNode parser option ref=ref NONE
 val expr1cSlot:partialNode parser option ref=ref NONE
 val expr2cSlot:partialNode parser option ref=ref NONE
 val expr3cSlot:partialNode parser option ref=ref NONE
 val expr4cSlot:partialNode parser option ref=ref NONE
 val expr5cSlot:partialNode parser option ref=ref NONE
 val atomicSlot:nameNode coreNode parser option ref=ref NONE
 fun assembleOp left partial=D.delay(fn()=>case force partial of NoOp=>force left
   |FoundOp(opname,right)=>EAp(cell(EAp(cell(EVar opname),left)),right))
 fun paProgram tokens=cached programSlot(fn()=>paThen3(fn a=>fn _=>fn c=>pair a c)
      paTypeDefs(literal";;")paScDefs)tokens
 and paTypeDefs tokens=cached typeDefsSlot(fn()=>paZeroOrMore(trailingSemi paTypeDefinition))tokens
 and paTypeDefinition tokens=cached typeDefSlot(fn()=>paThen4(fn a=>fn b=>fn _=>fn d=>triple a b d)
      paName(paZeroOrMore paName)(literal"::=")paConstructorAlts)tokens
 and paConstructorAlts tokens=cached constructorAltsSlot(fn()=>paOneOrMoreSep paConstructorAlt(literal"|"))tokens
 and paConstructorAlt tokens=cached constructorAltSlot(fn()=>paThen2 pair paConstructorName(paZeroOrMore paTypeExpr))tokens
 and paTypeExpr tokens=cached typeExprSlot(fn()=>paAlts[
      (tokenIs"(",paThen3(fn _=>fn e=>fn _=>e)(literal"(")
        (paThen2(fn n=>fn args=>cell(TDefCons(n,args)))paName(paZeroOrMore paTypeExpr))(literal")")),
      (isName,paApply paName(fn n=>cell(TDefVar n)))])tokens
 and paScDefs tokens=cached scDefsSlot(fn()=>paOneOrMore(trailingSemi paSc))tokens
 and paSc tokens=cached scSlot(fn()=>paThen4(fn n=>fn args=>fn _=>fn body=>pair n(pair args body))
      paName(paZeroOrMore paName)(literal"=")paExpr)tokens
 and paExpr tokens=cached exprSlot(fn()=>paAlts[(tokenIs"let",paLet),(tokenIs"letrec",paLetrec),
      (tokenIs"case",paCase),(tokenIs"\\",paLambda),(fn _=>true,paExpr1)])tokens
 and paLet tokens=cached letSlot(fn()=>paThen4(fn _=>fn bindings=>fn _=>fn body=>cell(ELet(cell false,bindings,body)))
      (literal"let")paBindings(literal"in")paExpr)tokens
 and paLetrec tokens=cached letrecSlot(fn()=>paThen4(fn _=>fn bindings=>fn _=>fn body=>cell(ELet(cell true,bindings,body)))
      (literal"letrec")paBindings(literal"in")paExpr)tokens
 and paBindings tokens=cached bindingsSlot(fn()=>paOneOrMoreSep paBinding(literal";"))tokens
 and paBinding tokens=cached bindingSlot(fn()=>paThen3(fn n=>fn _=>fn e=>pair n e)paName(literal"=")paExpr)tokens
 and paCase tokens=cached caseSlot(fn()=>paThen4(fn _=>fn e=>fn _=>fn alts=>cell(ECase(e,alts)))
      (literal"case")paExpr(literal"of")paAlternatives)tokens
 and paAlternatives tokens=cached alternativesSlot(fn()=>paThen2(fn a=>fn _=>a)
      (paOneOrMoreSep paAlternative(literal";"))(literal"end"))tokens
 and paAlternative tokens=cached alternativeSlot(fn()=>paThen4(fn c=>fn args=>fn _=>fn e=>pair c(pair args e))
      paConstructorName(paZeroOrMore paName)(literal"->")paExpr)tokens
 and paLambda tokens=cached lambdaSlot(fn()=>paThen4(fn _=>fn args=>fn _=>fn e=>cell(ELam(args,e)))
      (literal"\\")(paOneOrMore paName)(literal"->")paExpr)tokens
 and paExpr1 tokens=cached expr1Slot(fn()=>paThen2 assembleOp paExpr2 paExpr1c)tokens
 and paExpr2 tokens=cached expr2Slot(fn()=>paThen2 assembleOp paExpr3 paExpr2c)tokens
 and paExpr3 tokens=cached expr3Slot(fn()=>paThen2 assembleOp paExpr4 paExpr3c)tokens
 and paExpr4 tokens=cached expr4Slot(fn()=>paThen2 assembleOp paExpr5 paExpr4c)tokens
 and paExpr5 tokens=cached expr5Slot(fn()=>paThen2 assembleOp paExpr6 paExpr5c)tokens
 and paExpr6 tokens=cached expr6Slot(fn()=>paApply(paOneOrMore paAtomic)
      (fn terms=>foldLeft(fn f=>fn a=>cell(EAp(f,a)))(head terms)(tail terms)))tokens
 and paExpr1c tokens=cached expr1cSlot(fn()=>paAlts[
      (tokenIs"|",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"|")paExpr1),
      (tokenIs"#",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"#")paExpr1),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr2c tokens=cached expr2cSlot(fn()=>paAlts[
      (tokenIs"&",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"&")paExpr2),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr3c tokens=cached expr3cSlot(fn()=>paAlts[
      (inNames relations,paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))paRelation paExpr4),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr4c tokens=cached expr4cSlot(fn()=>paAlts[
      (tokenIs"+",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"+")paExpr4),
      (tokenIs"-",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"-")paExpr5),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paExpr5c tokens=cached expr5cSlot(fn()=>paAlts[
      (tokenIs"*",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"*")paExpr5),
      (tokenIs"/",paThen2(fn opn=>fn e=>cell(FoundOp(opn,e)))(literal"/")paExpr6),
      (fn _=>true,paEmpty(cell NoOp))])tokens
 and paAtomic tokens=cached atomicSlot(fn()=>paAlts[
      (isConstructor,paApply paConstructorName(fn n=>cell(EConstr n))),
      (tokenIs"(",paThen3(fn _=>fn e=>fn _=>e)(literal"(")paExpr(literal")")),
      (isName,paApply paName(fn n=>cell(EVar n))),
      (fn n=>Char.isDigit(firstChar n),paApply paNumber(fn n=>cell(ENum n)))])tokens
 fun parseSyntax tokens=
   let fun unexpected rest=case L.force rest of C.Nil=>myFail"Syntax error: Unexpected end of source text"
      |C.Cons(tok,_)=>let val(line,text)=L.force tok
        in myFail("Syntax error: unexpected token \""^string text^"\" on line "^signed line)end
   in case L.force(paProgram tokens)of PFail rest=>unexpected rest|POk(program,rest)=>
       case L.force rest of C.Nil=>raise Match|C.Cons(tok,tail)=>
         let val(line,text)=L.force tok
         in case L.force tail of C.Nil=>if equalInt line(int 999999)andalso tokenIs"$$$"text then program else raise Match
             |_=>unexpected rest end
   end

(* dependency: portable source translation. *)
 type freeAnnotation=(nameNode,nameNode setNode)ann
 fun annotationSet value=let val(free,_)=force value in free end
 fun freeVariables(expression:core):freeAnnotation=D.delay(fn()=>case force expression of
    ENum n=>(setEmpty(),cell(ANum n))
   |EVar n=>(setSingleton n,cell(AVar n))
   |EConstr n=>(setEmpty(),cell(AConstr n))
   |EAp(a,b)=>let val x=freeVariables a val y=freeVariables b
       in(setUnion compareName(annotationSet x)(annotationSet y),cell(AAp(x,y)))end
   |ELam(args,body)=>let val value=freeVariables body
       in(setSubtract compareName(annotationSet value)(setFromList compareName args),
          cell(ALam(args,value)))end
   |ECase(e,alternatives)=>
       let val value=freeVariables e
           val alternatives=map(fn alternative=>let val(tag,body)=force alternative
               val(args,e)=force body
             in pair tag(pair args(freeVariables e))end)alternatives
           val free=setUnionList compareName(map(fn alternative=>let val(_,body)=force alternative
                val(args,e)=force body
              in setSubtract compareName(annotationSet e)(setFromList compareName args)end)alternatives)
       in(setUnion compareName(annotationSet value)free,cell(ACase(value,alternatives)))end
   |ELet(recursive,bindings,body)=>
       let val binders=map(fn p=>let val(name,_)=force p in name end)bindings
           val binderSet=setFromList compareName binders
           val values=map(fn p=>let val(_,e)=force p in freeVariables e end)bindings
           val annotated=zip binders values
           val valuesFree=setUnionList compareName(map annotationSet values)
           val definitionsFree=D.delay(fn()=>force(if force recursive
             then setSubtract compareName valuesFree binderSet else valuesFree))
           val body=freeVariables body
           val bodyFree=setSubtract compareName(annotationSet body)binderSet
       in(setUnion compareName definitionsFree bodyFree,cell(ALet(recursive,annotated,body)))end)
 fun depthFirst compare relation initial vertices=
   foldLeft(fn state=>fn vertex=>D.delay(fn()=>
     let val(visited,sequence)=force state
     in if setMember compare vertex visited then(visited,sequence)else
       let val next=L.delay(fn()=>force(depthFirst compare relation
               (pair(setUnion compare visited(setSingleton vertex))sequence)(relation vertex)))
           val visited=D.delay(fn()=>force(#1(L.force next)))
           val sequence=F.defer(fn()=> #2(L.force next))
       in(visited,F.cons(vertex,sequence))end end))initial vertices
 fun spanningSearch compare relation initial vertices=
   foldLeft(fn state=>fn vertex=>D.delay(fn()=>
     let val(visited,components)=force state
     in if setMember compare vertex visited then(visited,components)else
       let val next=L.delay(fn()=>force(depthFirst compare relation
               (pair(setUnion compare visited(setSingleton vertex))(F.empty()))(relation vertex)))
           val visited=D.delay(fn()=>force(#1(L.force next)))
           val sequence=F.defer(fn()=> #2(L.force next))
       in(visited,F.cons(setFromList compare(F.cons(vertex,sequence)),components))end end))initial vertices
 fun stronglyConnected compare incoming outgoing roots=
   let val first=depthFirst compare outgoing(pair(setEmpty())(F.empty()))roots
       val ordered=F.defer(fn()=>let val(_,vertices)=force first in vertices end)
       val second=spanningSearch compare incoming(pair(setEmpty())(F.empty()))ordered
   in F.defer(fn()=>let val(_,components)=force second in components end)end

(* make-domains: portable source translation. *)
 fun concat lists=flatMap(fn values=>values)lists
 fun member equal value values=any(fn other=>equal value other)values
 fun unique equal values=let
     fun scan values seen=F.defer(fn()=>case force values of F.Nil=>F.empty()
       |F.Cons(x,rest)=>if member equal x seen then scan rest seen
         else F.cons(x,scan rest(F.cons(x,seen))))
   in scan values(F.empty())end
 fun freeTypeVariables definition=
   let val(_,parameters,alternatives)=force definition
       fun variables expression=F.defer(fn()=>case force expression of TDefVar n=>singleton n
         |TDefCons(n,args)=>F.cons(n,flatMap variables args))
       val all=flatMap(fn alt=>let val(_,types)=force alt in flatMap variables types end)alternatives
       val excluded=F.append parameters(F.fromList(List.map
           (fn s=>case force(name s)of F.Nil=>F.Nil|node=>node)["int","bool","char"]))
   in setValues(setSubtract compareName(setFromList compareName all)(setFromList compareName excluded))end
 fun typeEdges definitions=
   let val froms=map(fn definition=>let val(name,_,_)=force definition in name end)definitions
       val tos=map freeTypeVariables definitions
   in flatMap(fn edge=>let val(from,targets)=force edge
       in map(fn target=>pair from target)targets end)(zip froms tos)end
 fun typeDependency definitions=
   let val edges=typeEdges definitions
       fun incoming vertex=map(fn edge=>let val(from,_)=force edge in from end)
         (filter(fn edge=>let val(_,target)=force edge in equalName vertex target end)edges)
       fun outgoing vertex=map(fn edge=>let val(_,target)=force edge in target end)
         (filter(fn edge=>let val(from,_)=force edge in equalName vertex from end)edges)
       val roots=unique equalName(map(fn definition=>let val(name,_,_)=force definition in name end)definitions)
       fun group values=D.delay(fn()=>
         let val first=head values
         in if null(tail values)then
             let fun find definitions=case force definitions of F.Nil=>raise Match|F.Cons(definition,rest)=>
                   let val(name,_,_)=force definition in if equalName first name then definition else find rest end
             in(cell(member equalName first(freeTypeVariables(find definitions))),values)end
            else(cell true,values)end)
   in map(fn component=>group(setValues component))(stronglyConnected compareName incoming outgoing roots)end
 fun isRecursiveType groups name=case force groups of F.Nil=>raise Match|F.Cons(group,rest)=>
   let val(recursive,names)=force group
   in if member equalName name names then force recursive else isRecursiveType rest name end

(* validate-types: portable source translation. *)
 fun sureLookup equal associations context key=case force associations of F.Nil=>
      panic("utSureLookup: key not found in "^context)
   |F.Cons(entry,rest)=>let val(k,v)=force entry
       in if equal k key then v else sureLookup equal rest context key end
 fun lookupDefault equal associations key default=case force associations of F.Nil=>default
   |F.Cons(entry,rest)=>let val(k,v)=force entry
       in if equal k key then v else lookupDefault equal rest key default end
 fun validTypeDefinitions definitions groups=
   let val arities=map(fn definition=>let val(n,vars,_)=force definition in pair n(length vars)end)definitions
       val typeNames=map(fn definition=>let val(n,_,_)=force definition in n end)definitions
       val constructorNames=flatMap(fn definition=>let val(_,_,alternatives)=force definition
          in map(fn alt=>let val(n,_)=force alt in n end)alternatives end)definitions
       fun uniqueTypes()=equalInt(length typeNames)(length(unique equalName typeNames))
       fun uniqueParameters()=all(fn definition=>let val(_,vars,_)=force definition
          in equalInt(length vars)(length(unique equalName vars))end)definitions
       fun uniqueConstructors()=equalInt(length constructorNames)(length(unique equalName constructorNames))
       fun variablesOnly expr=F.defer(fn()=>case force expr of TDefVar n=>singleton n
          |TDefCons(_,args)=>flatMap variablesOnly args)
       fun balanced()=all(fn definition=>
          let val(_,vars,alternatives)=force definition
              val used=flatMap(fn alt=>let val(_,args)=force alt in flatMap variablesOnly args end)alternatives
          in equalLists equalName(setValues(setFromList compareName vars))(setValues(setFromList compareName used))end)definitions
       fun defined()=setSubset compareName(setFromList compareName(flatMap freeTypeVariables definitions))
            (setFromList compareName typeNames)
       fun rightArity expr=case force expr of TDefVar _=>true|TDefCons(n,args)=>
           equalInt(length args)(sureLookup equalName arities
             ("paVTD"^String.str(Char.chr 96)^"rA"^String.str(Char.chr 96)^"rA")n)
             andalso all rightArity args
       fun aritiesMatch()=all(fn definition=>let val(_,_,alternatives)=force definition
          in all(fn alt=>let val(_,args)=force alt in all rightArity args end)alternatives end)definitions
       fun allVariables expr=F.defer(fn()=>case force expr of TDefVar n=>singleton n
          |TDefCons(n,args)=>F.cons(n,flatMap allVariables args))
       fun groupOf name groups=case force groups of F.Nil=>raise Match|F.Cons(entry,rest)=>
           let val(recursive,names)=force entry in if member equalName name names
              then if force recursive then names else F.empty()else groupOf name rest end
       fun simple()=all(fn definition=>let val(n,vars,alternatives)=force definition
            val used=flatMap(fn alt=>let val(_,args)=force alt in flatMap allVariables args end)alternatives
          in setSubset compareName(setFromList compareName used)
             (setFromList compareName(F.append vars(groupOf n groups)))end)definitions
   in if not(uniqueTypes())then"Non-unique type names"
      else if not(uniqueParameters())then"Non-unique parameter names"
      else if not(uniqueConstructors())then"Non-unique constructor names"
      else if not(balanced())then"Declared parameters do not match used parameters"
      else if not(defined())then"Undefined types are present"
      else if not(aritiesMatch())then"Types are used at wrong arities"
      else if not(simple())then"Perverse type definitions are present"else""end
 fun programToAtomic program=D.delay(fn()=>let val(types,definitions)=force program
       val bindings=map(fn entry=>let val(n,value)=force entry val(args,body)=force value
         in pair n(cell(ELam(args,body)))end)definitions
   in(types,cell(ELet(cell true,bindings,cell(ENum(int 42)))))end)
 fun parseCore chars=
   let val program=parseSyntax(lex(int 1)chars)
       val atomic=programToAtomic program
       val types=F.defer(fn()=>let val(types,_)=force atomic in types end)
       val groups=typeDependency types
       val errors=validTypeDefinitions types groups
   in if errors=""then(groups,atomic)else myFail errors end

(* dependency-core: portable source translation. *)
 fun dependencyExpression(annotation:freeAnnotation):core=D.delay(fn()=>
   let val(_,node)=force annotation
   in case force node of ANum n=>ENum n|AVar n=>EVar n|AConstr n=>EConstr n
     |AAp(a,b)=>EAp(dependencyExpression a,dependencyExpression b)
     |ALam(args,body)=>ELam(args,dependencyExpression body)
     |ACase(e,alternatives)=>ECase(dependencyExpression e,map(fn alternative=>
        let val(tag,value)=force alternative val(args,e)=force value
        in pair tag(pair args(dependencyExpression e))end)alternatives)
     |ALet(recursive,definitions,body)=>
        let val binders=map(fn entry=>let val(n,_)=force entry in n end)definitions
            val binderSet=D.delay(fn()=>force(if force recursive then setFromList compareName binders else setEmpty()))
            val edges=flatMap(fn entry=>let val(n,annotation)=force entry
               val free=annotationSet annotation
             in map(fn target=>pair n target)(setValues(setIntersection compareName free binderSet))end)definitions
            fun incoming vertex=map(fn edge=>let val(n,_)=force edge in n end)
                (filter(fn edge=>let val(_,target)=force edge in equalName vertex target end)edges)
            fun outgoing vertex=map(fn edge=>let val(_,target)=force edge in target end)
                (filter(fn edge=>let val(n,_)=force edge in equalName vertex n end)edges)
            val components=map setValues(stronglyConnected compareName incoming outgoing binders)
            val groups=map(fn names=>map(fn n=>pair n(sureLookup equalName definitions
                ("depends"^String.str(Char.chr 96)^"defnGroups")n))names)components
            fun elet group e=D.delay(fn()=>
              let fun nonRecursive definitions=case force definitions of F.Nil=>false
                    |F.Cons(definition,rest)=>if null rest then
                      let val(n,a)=force definition in not(setMember compareName n(annotationSet a))end else false
                  val isRecursive=force recursive andalso not(nonRecursive group)
                  val definitions=map(fn entry=>let val(n,a)=force entry in pair n(dependencyExpression a)end)group
              in ELet(cell isRecursive,definitions,e)end)
        in force(foldRight elet(dependencyExpression body)groups)end
   end)
 fun depend expression=dependencyExpression(freeVariables expression)

(* lift-basic: portable source translation. *)
 fun mergeLambdas(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar n|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(mergeLambdas a,mergeLambdas b)
   |ELet(r,definitions,body)=>ELet(r,mapSecond mergeLambdas definitions,mergeLambdas body)
   |ECase(e,alternatives)=>ECase(mergeLambdas e,map(fn entry=>let val(tag,value)=force entry
       val(args,body)=force value in pair tag(pair args(mergeLambdas body))end)alternatives)
   |ELam(args,body)=>(case force body of ELam(more,e)=>force(mergeLambdas(cell(ELam(F.append args more,e))))
       |_=>ELam(args,mergeLambdas body)))
 fun nameLambdas(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar n|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(nameLambdas a,nameLambdas b)
   |ELam(args,body)=>let val n=name"_sc" val rhs=cell(ELam(args,nameLambdas body))
       in ELet(cell false,singleton(pair n rhs),cell(EVar n))end
   |ECase(e,alternatives)=>ECase(nameLambdas e,map(fn entry=>let val(tag,value)=force entry
       val(args,body)=force value in pair tag(pair args(nameLambdas body))end)alternatives)
   |ELet(r,definitions,body)=>ELet(r,map(fn entry=>let val(n,rhs)=force entry
       val fixed=D.delay(fn()=>case force rhs of ELam(args,e)=>ELam(args,nameLambdas e)
          |_=>force(nameLambdas rhs))
       in pair n fixed end)definitions,nameLambdas body))
 fun mapCore f(expression:core):core=D.delay(fn()=>case force expression of
    EVar n=>EVar(f n)|ENum n=>ENum n|EConstr n=>EConstr n
   |EAp(a,b)=>EAp(mapCore f a,mapCore f b)
   |ELam(args,e)=>ELam(map f args,mapCore f e)
   |ELet(r,definitions,e)=>ELet(r,map(fn entry=>let val(n,rhs)=force entry in pair(f n)(mapCore f rhs)end)definitions,mapCore f e)
   |ECase(e,alternatives)=>ECase(mapCore f e,map(fn entry=>let val(tag,value)=force entry
      val(args,body)=force value in pair tag(pair(map f args)(mapCore f body))end)alternatives))
 fun takeWhile predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,takeWhile predicate rest)else F.empty())
 fun dropWhile predicate xs=F.defer(fn()=>case force xs of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then dropWhile predicate rest else xs)
 fun checkUnique names=
   let fun duplicates names=F.defer(fn()=>case force names of F.Nil=>F.empty()
         |F.Cons(x,rest)=>(case force rest of F.Nil=>F.empty()|F.Cons(y,ys)=>
            if equalName x y then F.cons(x,duplicates(dropWhile(fn n=>equalName x n)ys))
              else duplicates rest))
       val duplicates=duplicates(insertionSort compareName names)
       fun showNames names="["^String.concatWith","(List.map(fn node=>
         "\""^string(cell node)^"\"")(F.toList names))^"]"
   in if null duplicates then names else myFail("Duplicate identifiers in the same scope:\n\t"^showNames duplicates)end
 fun makeName prefix supply=F.append prefix(F.append(name")")(name(signed supply)))
 fun getNames supply prefixes=
   let fun withNumbers prefixes nums=F.defer(fn()=>case force prefixes of F.Nil=>F.empty()
         |F.Cons(prefix,rest)=>case L.force nums of C.Nil=>F.empty()|C.Cons(n,nt)=>
           F.cons(makeName prefix(L.force n),withNumbers rest nt))
   in(add supply(length prefixes),withNumbers prefixes(intsFrom supply))end
 type uniqueResult=(integer*core)L.delay
 fun uniqueSupply(result:uniqueResult)=D.delay(fn()=>let val(n,_)=L.force result in force n end)
 fun uniqueBody(result:uniqueResult):core=D.delay(fn()=>let val(_,e)=L.force result in force e end)
 fun uniqueNames supply dictionary(expression:core):uniqueResult=L.delay(fn()=>case force expression of
    ENum n=>(supply,cell(ENum n))|EConstr n=>(supply,cell(EConstr n))
   |EVar n=>let fun find entries=case force entries of F.Nil=>myFail("No such variable "^String.str(Char.chr 34)^string n^String.str(Char.chr 34))
           |F.Cons(entry,rest)=>let val(k,v)=force entry
             in if equalName k n then v else find rest end
       in(supply,cell(EVar(find dictionary)))end
   |EAp(a,b)=>let val first=uniqueNames supply dictionary a
         val second=uniqueNames(uniqueSupply first)dictionary b
       in(uniqueSupply second,cell(EAp(uniqueBody first,uniqueBody second)))end
   |ELam(args,body)=>
       let val(next,names)=getNames supply(checkUnique args)
           val env=F.append(zip args names)dictionary
           val result=uniqueNames next env body
       in(uniqueSupply result,cell(ELam(names,uniqueBody result)))end
   |ECase(e,alternatives)=>
       let val selector=uniqueNames supply dictionary e
           fun alternative supply entry=
             let val(tag,value)=force entry val(args,body)=force value
                 val(next,names)=getNames supply(checkUnique args)
                 val env=F.append(zip args names)dictionary
                 val result=uniqueNames next env body
             in(uniqueSupply result,pair tag(pair names(uniqueBody result)))end
           val result=mapAccumulate alternative(uniqueSupply selector)alternatives
           val supply=D.delay(fn()=>let val(n,_)=L.force result in force n end)
           val alternatives=F.defer(fn()=>let val(_,values)=L.force result in values end)
       in(supply,cell(ECase(uniqueBody selector,alternatives)))end
   |ELet(recursive,definitions,body)=>
       let val here=checkUnique(map(fn entry=>let val(n,_)=force entry in n end)definitions)
           val(next,names)=getNames supply(checkUnique here)
           val env=F.append(zip here(map(fn n=>F.cons(cell #"_",n))names))dictionary
           fun definition supply entry=
             let val(n,rhs)=force entry
                 val result=uniqueNames supply(if force recursive then env else dictionary)rhs
             in(uniqueSupply result,pair(sureLookup equalName env"llUnique"n)(uniqueBody result))end
           val result=mapAccumulate definition next definitions
           val supply=D.delay(fn()=>let val(n,_)=L.force result in force n end)
           val final=uniqueNames supply env body
           val definitions=F.defer(fn()=>let val(_,values)=L.force result in values end)
       in(uniqueSupply final,cell(ELet(recursive,definitions,uniqueBody final)))end)

(* lift-equations: portable source translation. *)
 fun liftFreeVariables(expression:core):freeAnnotation=D.delay(fn()=>case force expression of
    ENum n=>(setEmpty(),cell(ANum n))|EVar n=>(setSingleton n,cell(AVar n))
   |EConstr n=>(setEmpty(),cell(AConstr n))
   |EAp(a,b)=>let val x=liftFreeVariables a val y=liftFreeVariables b
       in(setUnion compareName(annotationSet x)(annotationSet y),cell(AAp(x,y)))end
   |ELam(args,e)=>let val body=liftFreeVariables e
       in(setSubtract compareName(annotationSet body)(setFromList compareName args),cell(ALam(args,body)))end
   |ECase(e,alternatives)=>let val e=liftFreeVariables e
       val alternatives=map(fn entry=>let val(tag,value)=force entry val(args,body)=force value
         in pair tag(pair args(liftFreeVariables body))end)alternatives
       val free=setUnionList compareName(map(fn entry=>let val(_,value)=force entry val(args,body)=force value
         in setSubtract compareName(annotationSet body)(setFromList compareName args)end)alternatives)
       in(setUnion compareName(annotationSet e)free,cell(ACase(e,alternatives)))end
   |ELet(recursive,definitions,e)=>
       let val(binders,values)=unzip definitions val bound=setFromList compareName binders
           val values=map liftFreeVariables values
           val definitions=zip binders values
           val freeValues=setUnionList compareName(map annotationSet values)
           val definitionFree=D.delay(fn()=>force(if force recursive then setSubtract compareName freeValues bound else freeValues))
           val body=liftFreeVariables e
           val bodyFree=setSubtract compareName(annotationSet body)bound
       in(setUnion compareName definitionFree bodyFree,cell(ALet(recursive,definitions,body)))end)
 fun splitFreeSet collection=
   let fun split result value=let val(fs,vs)=force result
         in if firstChar value= #"_"then pair(F.cons(value,fs))vs else pair fs(F.cons(value,vs))end
       val result=foldLeft split(pair(F.empty())(F.empty()))(setValues collection)
       val functions=F.defer(fn()=>let val(fs,_)=force result in fs end)
       val variables=F.defer(fn()=>let val(_,vs)=force result in vs end)
   in(setFromList compareName functions,setFromList compareName variables)end
 fun liftEquations(annotation:freeAnnotation)=F.defer(fn()=>
   let val(_,node)=force annotation
   in case force node of AVar _=>F.empty()|ANum _=>F.empty()|AConstr _=>F.empty()
    |AAp(a,b)=>F.append(liftEquations a)(liftEquations b)
    |ALam(_,body)=>liftEquations body
    |ACase(e,alternatives)=>F.append(liftEquations e)(flatMap(fn entry=>
        let val(_,value)=force entry val(_,body)=force value in liftEquations body end)alternatives)
    |ALet(_,definitions,body)=>
       let val here=map(fn entry=>D.delay(fn()=>let val(n,annotation)=force entry
             val(functions,variables)=splitFreeSet(annotationSet annotation)
           in EqnNVC(n,variables,functions)end))definitions
           val inside=flatMap(fn entry=>let val(_,body)=force entry in liftEquations body end)definitions
       in F.append here(F.append inside(liftEquations body))end end)
 fun zapBuiltins builtins equation=D.delay(fn()=>
   let val EqnNVC(n,v,c)=force equation
       val names=filter(fn name=>not(member equalName name builtins))(setValues c)
   in EqnNVC(n,v,setFromList compareName names)end)
 fun equalNameSets a b=equalLists equalName(setValues a)(setValues b)
 fun equalFreeEnvironments xs ys=equalLists(fn a=>fn b=>
   let val(n,x)=force a val(m,y)=force b in equalName n m andalso equalNameSets x y end)xs ys
 fun solveLiftEquations equations=
   let val initial=map(fn equation=>let val EqnNVC(n,_,_)=force equation in pair n(setEmpty())end)equations
       fun substitute env equation=
         let val EqnNVC(n,v,c)=force equation
             val names=F.append(setValues v)(setValues c)
             val substituted=map(fn variable=>lookupDefault equalName env variable(setSingleton variable))names
             val all=setUnionList compareName substituted
             val(_,variables)=splitFreeSet all
         in pair n variables end
       fun loop env=let val next=map(substitute env)equations
         in if equalFreeEnvironments next env then next else loop next end
   in loop initial end
 fun addLiftParameters env(annotation:freeAnnotation):core=D.delay(fn()=>
   let val(_,node)=force annotation
   in case force node of ANum n=>ENum n|AConstr n=>EConstr n
    |AVar n=>let fun find env=case force env of F.Nil=>NONE|F.Cons(entry,rest)=>
          let val(k,v)=force entry in if equalName k n then SOME v else find rest end
        in case find env of NONE=>EVar n|SOME values=>
            force(foldLeft(fn f=>fn a=>cell(EAp(f,a)))(cell(EVar n))
                (map(fn n=>cell(EVar n))(setValues values)))end
    |AAp(a,b)=>EAp(addLiftParameters env a,addLiftParameters env b)
    |ALam(args,body)=>ELam(args,addLiftParameters env body)
    |ACase(e,alternatives)=>ECase(addLiftParameters env e,map(fn entry=>
        let val(tag,value)=force entry val(args,body)=force value
        in pair tag(pair args(addLiftParameters env body))end)alternatives)
    |ALet(recursive,definitions,body)=>
        let val definitions=map(fn entry=>let val(n,rhs)=force entry val(df,node)=force rhs
              val parameters=setValues(sureLookup equalName env
                   (case force node of ALam _=>"llAddParams1"|_=>"llAddParams2")n)
              val lifted=D.delay(fn()=>case force node of ALam(args,e)=>
                   ELam(F.append parameters args,addLiftParameters env e)
                |_=>ELam(parameters,addLiftParameters env(pair df node)))
            in pair n lifted end)definitions
        in ELet(recursive,definitions,addLiftParameters env body)end end)

(* lift-finish: portable source translation. *)
 type flattenResult=(coreBinding F.seq*core)L.delay
 fun flattenedBindings(result:flattenResult)=F.defer(fn()=>let val(definitions,_)=L.force result in definitions end)
 fun flattenedBody(result:flattenResult):core=D.delay(fn()=>let val(_,body)=L.force result in force body end)
 fun flattenCore(expression:core):flattenResult=L.delay(fn()=>case force expression of
    EVar n=>(F.empty(),cell(EVar n))|ENum n=>(F.empty(),cell(ENum n))
   |EConstr n=>(F.empty(),cell(EConstr n))
   |EAp(a,b)=>let val x=flattenCore a val y=flattenCore b
       in(F.append(flattenedBindings x)(flattenedBindings y),cell(EAp(flattenedBody x,flattenedBody y)))end
   |ELam(args,e)=>let val result=flattenCore e
       in(flattenedBindings result,cell(ELam(args,flattenedBody result)))end
   |ECase(e,alternatives)=>
       let val selector=flattenCore e
           val fixed=map(fn entry=>let val(tag,value)=force entry val(args,body)=force value
             in pair tag(pair args(flattenCore body))end)alternatives
           val alternatives=map(fn entry=>let val(tag,value)=force entry val(args,result)=force value
             in pair tag(pair args(flattenedBody result))end)fixed
           val bindings=flatMap(fn entry=>let val(_,value)=force entry val(_,result)=force value
             in flattenedBindings result end)fixed
       in(F.append(flattenedBindings selector)bindings,cell(ECase(flattenedBody selector,alternatives)))end
   |ELet(_,definitions,body)=>
       let val rhs=flattenCore body
           val fixed=map(fn entry=>let val(n,e)=force entry in pair n(flattenCore e)end)definitions
           val here=map(fn entry=>let val(n,result)=force entry in pair n(flattenedBody result)end)fixed
           val inside=flatMap(fn entry=>let val(_,result)=force entry in flattenedBindings result end)fixed
       in(F.append(F.append here inside)(flattenedBindings rhs),flattenedBody rhs)end)
 fun rootName n=takeWhile(fn c=>force c<> #")")n
 fun contentious names=
   let fun collisions names=F.defer(fn()=>case force names of F.Nil=>F.empty()
        |F.Cons(x,rest)=>(case force rest of F.Nil=>F.empty()|F.Cons(y,ys)=>
          if equalName(rootName x)(rootName y)then F.cons(x,F.cons(y,collisions rest))else collisions rest))
   in unique equalName(collisions(insertionSort compareName names))end
 fun prettyScName names n=if firstChar n= #"_"andalso not(member equalName n names)then rootName n else n
 fun prettyVariableName names n=if firstChar n<> #"_"andalso not(member equalName n names)then rootName n else n
 fun prettyLifted definitions freeParameters=
   let val names=map(fn entry=>let val(n,_)=force entry in n end)definitions
       val scTable=contentious names
       val scDefinitions=map(fn entry=>let val(n,e)=force entry
         in pair(prettyScName scTable n)(mapCore(prettyScName scTable)e)end)definitions
       val freeParameters=mapFirst(prettyScName scTable)freeParameters
       val lambdaTables=map(fn entry=>let val(_,e)=force entry
         in case force e of ELam(args,_)=>contentious args|_=>F.empty()end)scDefinitions
       fun fixParameters entry table=let val(n,ps)=force entry
         in pair n(map(prettyVariableName table)ps)end
       fun fixDefinition entry table=let val(n,e)=force entry
         in pair n(mapCore(prettyVariableName table)e)end
   in(zipExact fixDefinition scDefinitions lambdaTables,
      zipExact fixParameters freeParameters lambdaTables)end
 fun lambdaLift builtins expression pretty=L.delay(fn()=>
   let val builtinFunctions=filter(fn n=>firstChar n= #"_")builtins
       val initialEnv=map(fn n=>pair(tail n)n)builtinFunctions
       val depended=depend expression
       val merged=mergeLambdas depended
       val named=nameLambdas merged
       val unique=uniqueBody(uniqueNames(int 0)initialEnv named)
       val annotation=liftFreeVariables unique
       val equations=map(zapBuiltins builtinFunctions)(liftEquations annotation)
       val solution=solveLiftEquations equations
       val result=flattenCore(addLiftParameters solution annotation)
       val definitions=flattenedBindings result val body=flattenedBody result
       val parameters=mapSecond setValues solution
       val polished=if pretty then prettyLifted definitions parameters else(definitions,parameters)
       val(definitions,parameters)=polished
       val reconstituted=cell(ELet(cell true,definitions,body))
   in(depend reconstituted,parameters)end)

(* type-basic: portable source translation. *)
 fun equalTVName a b=let val(xs,ys)=force a val(zs,ws)=force b
   in equalLists equalInt xs zs andalso equalLists equalInt ys ws end
 fun compareTVName a b=let val(xs,ys)=force a val(zs,ws)=force b
   in thenCompare(compareLists compareInt xs zs)(fn()=>compareLists compareInt ys ws)end
 fun typeVariables expression=
   let fun collect expression rest=F.defer(fn()=>case force expression of TVar name=>F.cons(name,rest)
       |TArr(a,b)=>collect a(collect b rest)
       |TCons(_,args)=>force(foldRight(fn arg=>fn rest=>cell(collect arg(force rest)))(cell rest)args))
   in collect expression(F.empty())end
 fun showType expression=
   let val dictionary=unique equalTVName(typeVariables expression)
       fun position value values=case force values of F.Nil=>panic"tcShowtExpr: Type name lookup failed"
         |F.Cons(x,rest)=>if equalTVName value x then int 1 else add(int 1)(position value rest)
       fun render bracket expression=F.defer(fn()=>case force expression of
          TVar variable=>F.fromList[#" ",Char.chr(96+small(position variable dictionary))]
         |TArr(a,b)=>if bracket then F.append(name" (")(F.append(render true a)
              (F.append(name" -> ")(F.append(render false b)(name")"))))
            else F.append(render true a)(F.append(name" -> ")(render false b))
         |TCons(n,args)=>if null args andalso List.exists(fn s=>equalName n(name s))["int","bool","char"]
             then F.append(name" ")n
            else F.append(name" (")(F.append n(F.append(flatMap(render true)args)(name")"))))
   in render false expression end
 fun applySubstitution phi variable:texpr=D.delay(fn()=>
   let val value=lookupDefault equalTVName phi variable(cell(TVar variable))
   in if equalType(cell(TVar variable))value then TVar variable else force(substituteType phi value)end)
 and substituteType phi expression:texpr=D.delay(fn()=>case force expression of
      TVar variable=>force(applySubstitution phi variable)
     |TCons(n,args)=>TCons(n,map(substituteType phi)args)
     |TArr(a,b)=>TArr(substituteType phi a,substituteType phi b))
 fun composeSubstitutions second first=F.append first second
 fun deltaSubstitution variable expression=F.defer(fn()=>case force expression of TVar other=>
        (case compareTVName variable other of EQUAL=>F.empty()
          |GREATER=>singleton(pair variable(cell(TVar other)))
          |LESS=>singleton(pair other(cell(TVar variable))))
      |_=>singleton(pair variable expression))
 type substNode=(tvname D.t*texpr)F.node
 type unifyReply=(substNode,nameNode)replyNode L.delay
 fun extendSubstitution phi variable expression:unifyReply=L.delay(fn()=>
   if equalType expression(cell(TVar variable))then Ok phi
   else if not(member equalTVName variable(typeVariables expression))
     then Ok(composeSubstitutions(deltaSubstitution variable expression)phi)
   else myFail("Type error in source program:\n\nCircular substitution:\n      "^
       string(showType(cell(TVar variable)))^"\n   going to\n      "^string(showType expression)^"\n"))
 fun unify phi(a:texpr,b:texpr):unifyReply=L.delay(fn()=>case(force a,force b)of
      (TVar variable,_)=>let val resolved=applySubstitution phi variable
           val other=substituteType phi b
        in if equalType resolved(cell(TVar variable))
            then L.force(extendSubstitution phi variable other)else L.force(unify phi(resolved,other))end
     |(_,TVar _)=>L.force(unify phi(b,a))
     |(TArr(a,b),TArr(c,d))=>L.force(unifyList phi(F.cons(pair a c,singleton(pair b d))))
     |(TCons(n,args),TCons(m,others))=>if equalName n m then L.force(unifyList phi(zip args others))
        else mismatch a b
     |_=>mismatch a b)
 and mismatch a b=myFail("Type error in source program:\n\nCannot unify\n      "^
        string(showType a)^"\n   with\n      "^string(showType b)^"\n")
 and unifyList phi equations:unifyReply=L.delay(fn()=>case force equations of F.Nil=>Ok phi
      |F.Cons(equation,rest)=>case L.force(unifyList phi rest)of
         Failed message=>Failed message|Ok next=>L.force(unify next(force equation)))
 fun mapAnnotation f value=D.delay(fn()=>
   let val(annotation,node)=force value
       val mapped=D.delay(fn()=>case force node of
          AVar n=>AVar n|ANum n=>ANum n|AConstr n=>AConstr n
         |AAp(a,b)=>AAp(mapAnnotation f a,mapAnnotation f b)
         |ALam(args,e)=>ALam(args,mapAnnotation f e)
         |ALet(r,definitions,e)=>ALet(r,mapSecond(mapAnnotation f)definitions,mapAnnotation f e)
         |ACase(e,alternatives)=>ACase(mapAnnotation f e,map(fn entry=>
             let val(tag,body)=force entry val(args,e)=force body
             in pair tag(pair args(mapAnnotation f e))end)alternatives))
   in(f annotation,mapped)end)

(* type-environment: portable source translation. *)
 fun lookupAll equal associations key=F.defer(fn()=>case force associations of F.Nil=>F.empty()
   |F.Cons(entry,rest)=>let val(k,value)=force entry
     in if equal k key then F.cons(value,lookupAll equal rest key)else lookupAll equal rest key end)
 fun checkUnifier reply=case L.force reply of Ok phi=>phi
   |Failed message=>panic("tcCheckUnifier: "^string message)
 fun unifyTypeSet phi types:unifyReply=L.delay(fn()=>case force types of F.Nil=>raise Match
   |F.Cons(first,rest)=>case force rest of F.Nil=>Ok phi|F.Cons(second,tail)=>
      if null tail then L.force(unify phi(first,second))
      else let val next=case L.force(unify phi(first,second))of Ok phi=>phi
            |Failed message=>panic("tcDeOkSel: "^string message)
           in L.force(unifyTypeSet next rest)end)
 fun mergeSubstitutions phi=
   let val variables=unique equalTVName(map(fn entry=>let val(v,_)=force entry in v end)phi)
       val groups=map(lookupAll equalTVName phi)variables
       val unifiers=map(fn group=>
         let val reply=unifyTypeSet(F.empty())group in checkUnifier reply end)groups
       fun oldUnified us groups=F.defer(fn()=>case(force us,force groups)of(F.Nil,F.Nil)=>F.empty()
         |(F.Cons(u,ut),F.Cons(group,gt))=>F.cons(substituteType u(head group),oldUnified ut gt)
         |_=>raise Match)
       val newBindings=concat unifiers
       val oldBindings=zip variables(oldUnified unifiers groups)
   in if null newBindings then oldBindings else mergeSubstitutions(F.append oldBindings newBindings)end
 fun typeBar xs ys=filter(fn x=>not(member equalTVName x ys))xs
 fun schemeUnknowns scheme=let val Scheme(variables,expression)=force scheme
   in typeBar(typeVariables expression)variables end
 fun substituteScheme phi scheme=D.delay(fn()=>let val Scheme(variables,expression)=force scheme
       val filtered=filter(fn entry=>let val(n,_)=force entry
         in not(member equalTVName n variables)end)phi
   in Scheme(variables,substituteType filtered expression)end)
 fun charValue associations key=
   let fun find associations=case force associations of F.Nil=>panic("tcCharVal: no such variable: "^string key)
      |F.Cons(entry,rest)=>let val(n,value)=force entry
        in if equalName n key then value else find rest end
   in find associations end
 fun environmentUnknowns gamma=
   let val schemes=map(fn entry=>let val(_,scheme)=force entry in scheme end)gamma
   in concat(map schemeUnknowns schemes)end
 fun substituteEnvironment phi gamma=
   map(fn entry=>let val(n,scheme)=force entry in pair n(substituteScheme phi scheme)end)gamma
 val typeSupplyDoubleLimit=cell(0wx40000000:W.word)
 val typeSupplySuccessorLimit=add typeSupplyDoubleLimit(subtract typeSupplyDoubleLimit(int 1))
 fun typeSupplySuccessor values=F.defer(fn()=>case force values of F.Nil=>singleton(int 1)
   |F.Cons(n,rest)=>if less n typeSupplySuccessorLimit then F.cons(add n(int 1),rest)
       else F.cons(int 0,typeSupplySuccessor rest))
 fun typeSupplyDouble values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(n,rest)=>let
       val next=D.delay(fn()=>force(if less typeSupplyDoubleLimit n then subtract n typeSupplyDoubleLimit else n))
       val tail=F.defer(fn()=>if equalInt next n then typeSupplyDouble rest
         else typeSupplySuccessor(typeSupplyDouble rest))
     in F.cons(multiply(int 2)next,tail)end)
 fun depleteTypeSupply(f,s)=(f,typeSupplySuccessor s)
 fun splitTypeSupply(f,s)=let val doubled=typeSupplyDouble f
   in((doubled,singleton(int 0)),(typeSupplySuccessor doubled,singleton(int 0)))end
 fun typeNameSequence supply=C.defer(fn()=>C.cons(L.delay(fn()=>cell supply),typeNameSequence(depleteTypeSupply supply)))

(* type-schemes: portable source translation. *)
 fun zipTypeNames names supply=F.defer(fn()=>case force names of F.Nil=>F.empty()
   |F.Cons(n,rest)=>case L.force supply of C.Nil=>F.empty()|C.Cons(v,tail)=>
      F.cons(pair n(L.force v),zipTypeNames rest tail))
 fun newTypeInstance supply scheme=
   let val Scheme(variables,expression)=force scheme
       val association=zipTypeNames variables(typeNameSequence supply)
       val phi=mapSecond(fn variable=>cell(TVar variable))association
   in substituteType phi expression end
 fun generalizedScheme unknowns supply expression=D.delay(fn()=>
   let val variables=typeBar(unique equalTVName(typeVariables expression))unknowns
       val association=zipTypeNames variables(typeNameSequence supply)
       val mappedVariables=map(fn entry=>let val(_,v)=force entry in v end)association
       val phi=mapSecond(fn variable=>cell(TVar variable))association
   in Scheme(mappedVariables,substituteType phi expression)end)
 fun addTypeDeclarations gamma supply names types=
   let val unknowns=environmentUnknowns gamma
       val schemes=map(generalizedScheme unknowns supply)types
   in F.append(zip names schemes)gamma end
 fun newBoundVariable name variable=pair name(cell(Scheme(F.empty(),cell(TVar variable))))
 fun newBoundVariables names supply=
   map(fn entry=>let val(n,v)=force entry in newBoundVariable n v end)(zipTypeNames names(typeNameSequence supply))
 fun oldBoundVariable entry=
   let val(_,scheme)=force entry val Scheme(variables,expression)=force scheme
   in if null variables then expression else raise Match end
 fun typeDefinitionSubstitution names expression:texpr=D.delay(fn()=>case force expression of
    TDefCons(n,args)=>TCons(n,map(typeDefinitionSubstitution names)args)
   |TDefVar n=>let fun find entries=case force entries of F.Nil=>TCons(n,F.empty())
         |F.Cons(entry,rest)=>let val(k,v)=force entry
            in if equalName k n then TVar v else find rest end
     in find names end)
 fun newTypeVariables definition supply=
   let val(_,variables,_)=force definition
   in zipTypeNames variables(typeNameSequence supply)end
 fun constructorTypeSchemes supply definition=
   let val(n,variables,alternatives)=force definition
       val newVariables=newTypeVariables definition supply
       val variablesInType=map(fn entry=>let val(_,v)=force entry in v end)newVariables
       val constructorSignature=cell(TCons(n,map(fn v=>cell(TVar v))variablesInType))
       val translated=mapSecond(fn args=>map(typeDefinitionSubstitution newVariables)args)alternatives
       val curried=mapSecond(fn args=>foldRight(fn arg=>fn result=>cell(TArr(arg,result)))constructorSignature args)translated
       fun scheme expression=cell(Scheme(unique equalTVName(typeVariables expression),expression))
       fun deplete n supply=if equalInt n(int 0)then supply
         else deplete(subtract n(int 1))(depleteTypeSupply supply)
       val next=deplete(add(length variablesInType)(int 2))supply
   in(next,mapSecond scheme curried)end

(* type-case-support: portable source translation. *)
 fun equalTypeDefExpr a b=case(force a,force b)of(TDefVar n,TDefVar m)=>equalName n m
   |(TDefCons(n,xs),TDefCons(m,ys))=>equalName n m andalso equalLists equalTypeDefExpr xs ys|_=>false
 fun equalTypeDefinition a b=
   let val(n,vars,constructors)=force a val(m,others,alternatives)=force b
       fun equalAlternative a b=let val(n,xs)=force a val(m,ys)=force b
         in equalName n m andalso equalLists equalTypeDefExpr xs ys end
   in equalName n m andalso equalLists equalName vars others
       andalso equalLists equalAlternative constructors alternatives end
 fun getTypeDefinition definitions constructors=
   let val candidates=flatMap(fn definition=>let val(_,_,alternatives)=force definition
         val names=map(fn entry=>let val(n,_)=force entry in n end)alternatives
       in map(fn _=>definition)(filter(fn n=>member equalName n names)constructors)end)definitions
       val distinct=unique equalTypeDefinition candidates
   in if null distinct then myFail"Undeclared constructors in use"
      else if not(null(tail distinct))then myFail"CASE expression contains mixed constructors"else head distinct end
 fun reorderConstructors names associations=map(fn n=>
   let fun find entries=case force entries of F.Nil=>
           myFail("Error in source program: undeclared constructor '"^string n^"' in CASE")
       |F.Cons(entry,rest)=>let val(k,v)=force entry in if equalName k n then v else find rest end
   in find associations end)names
 fun constructorGamma newVariables alternative parameters=
   let val(_,args)=force alternative
       val types=map(fn expression=>cell(Scheme(F.empty(),typeDefinitionSubstitution newVariables expression)))args
   in zip parameters types end
 fun allConstructorGammas newVariables alternatives parameters=F.defer(fn()=>case(force alternatives,force parameters)of
    (F.Nil,F.Nil)=>F.empty()
   |(F.Cons(alt,at),F.Cons(args,pt))=>F.cons(constructorGamma newVariables alt args,
       allConstructorGammas newVariables at pt)
   |_=>raise Match)
 type typedAnnotation=(nameNode,typeNode)ann
 type typedAnnotationNode=typeNode D.t*(nameNode,typeNode)annNode D.t
 type typeInfo=subst*texpr*typedAnnotation
 type typeReply=(typeInfo,nameNode)replyNode L.delay
 type typeListInfo=subst*typeNode F.seq*typedAnnotationNode F.seq
 type typeListReply=(typeListInfo,nameNode)replyNode L.delay
 fun info(reply:typeReply)=case L.force reply of Ok value=>force value
    |Failed message=>panic("tcDeOkSel: "^string message)
 fun infoSubstitution reply=let val(phi,_,_)=info reply in phi end
 fun infoType reply=let val(_,t,_)=info reply in t end
 fun infoTree reply=let val(_,_,tree)=info reply in tree end
 val intType=cell(TCons(name"int",F.empty()))
 val boolType=cell(TCons(name"bool",F.empty()))

(* type-infer: portable source translation. *)
 fun infer definitions gamma supply(expression:core):typeReply=L.delay(fn()=>case force expression of
    ENum n=>Ok(triple(F.empty())intType(pair intType(cell(ANum n))))
   |EVar n=>inferVariable gamma supply n
   |EConstr n=>inferVariable gamma supply n
   |EAp(a,b)=>let val variable=cell supply
        val result=inferList definitions gamma(depleteTypeSupply supply)(F.cons(a,singleton b))
      in case L.force result of Failed message=>Failed message|Ok value=>
        let val(phi,types,trees)=force value
            val a=head types val b=head(tail types)
            val first=head trees val second=head(tail trees)
        in case L.force(unify phi(a,cell(TArr(b,cell(TVar variable)))))of
           Failed message=>Failed message|Ok phi=>
             let val t=applySubstitution phi variable
             in Ok(triple phi t(pair t(cell(AAp(first,second)))))end end end
   |ELam(args,e)=>(case force args of F.Nil=>L.force(infer definitions gamma supply e)
      |F.Cons(x,rest)=>let val body=if null rest then e else cell(ELam(rest,e))
        in L.force(inferLambda definitions gamma supply x body)end)
   |ELet(recursive,bindings,e)=>
       let val(names,values)=unzip bindings
       in if force recursive then L.force(inferLetrec definitions gamma supply names values e)
          else L.force(inferLet definitions gamma supply names values e)end
   |ECase(selector,alternatives)=>let val(constructors,bodies)=unzip alternatives
        val(parameters,expressions)=unzip bodies
      in L.force(inferCase definitions gamma supply selector constructors parameters expressions)end)
 and inferVariable gamma supply name=
   let val scheme=charValue gamma name
       val t=newTypeInstance supply scheme
   in Ok(triple(F.empty())t(pair t(cell(AVar name))))end
 and inferList definitions gamma supply expressions:typeListReply=L.delay(fn()=>case force expressions of
    F.Nil=>Ok(triple(F.empty())(F.empty())(F.empty()))
   |F.Cons(e,rest)=>let val(ns0,ns1)=splitTypeSupply supply
     in case L.force(infer definitions gamma ns1 e)of Failed message=>Failed message|Ok value=>
        let val(phi,t,tree)=force value
        in case L.force(inferList definitions(substituteEnvironment phi gamma)ns0 rest)of
           Failed message=>Failed message|Ok values=>
             let val(psi,types,trees)=force values
             in Ok(triple(composeSubstitutions psi phi)(F.cons(substituteType psi t,types))(F.cons(tree,trees)))end end end)
 and inferLambda definitions gamma supply x e:typeReply=L.delay(fn()=>
   let val variable=cell supply
       val env=F.cons(newBoundVariable x variable,gamma)
   in case L.force(infer definitions env(depleteTypeSupply supply)e)of
      Failed message=>Failed message|Ok value=>let val(phi,t,tree)=force value
         val t=cell(TArr(applySubstitution phi variable,t))
       in Ok(triple phi t(pair t(cell(ALam(singleton x,tree)))))end end)
 and inferLet definitions gamma supply names values e:typeReply=L.delay(fn()=>
   let val(ns0,ns1)=splitTypeSupply supply
   in case L.force(inferList definitions gamma ns1 values)of Failed message=>Failed message|Ok value=>
      let val(phi,types,trees)=force value
          val gamma=substituteEnvironment phi gamma
          val(ns0,ns1)=splitTypeSupply ns0
          val env=addTypeDeclarations gamma ns0 names types
      in L.force(finishLet phi names false(infer definitions env ns1 e)trees)end end)
 and finishLet phi names recursive(reply:typeReply)trees:typeReply=L.delay(fn()=>case L.force reply of
    Failed message=>Failed message|Ok value=>let val(psi,t,tree)=force value
       in Ok(triple(composeSubstitutions psi phi)t(pair t(cell(ALet(cell recursive,zip names trees,tree)))))end)
 and inferLetrec definitions gamma supply names values e:typeReply=L.delay(fn()=>
   let val(ns0,ns)=splitTypeSupply supply val(ns1,ns2)=splitTypeSupply ns
       val variables=newBoundVariables names ns2
   in case L.force(inferList definitions(F.append variables gamma)ns1 values)of
      Failed message=>Failed message|Ok value=>
       let val(phi,types,trees)=force value
           val vars=substituteEnvironment phi variables
           val gamma=substituteEnvironment phi gamma
           val oldTypes=map oldBoundVariable vars
       in case L.force(unifyList phi(zip types oldTypes))of Failed message=>Failed message|Ok phi=>
          let val vars=substituteEnvironment phi vars
              val gamma=substituteEnvironment phi gamma
              val types=map oldBoundVariable vars
              val(ns0,ns1)=splitTypeSupply ns0
              val env=addTypeDeclarations gamma ns0(map(fn entry=>let val(n,_)=force entry in n end)variables)types
          in L.force(finishLet phi names true(infer definitions env ns1 e)trees)end end end)
 and inferCase definitions gamma supply selector constructors parameters expressions:typeReply=L.delay(fn()=>
   let val definition=getTypeDefinition definitions constructors
       val(n,variables,alternatives)=force definition
       val expectedConstructors=map(fn entry=>let val(n,_)=force entry in n end)alternatives
       val(ns1,ns2)=splitTypeSupply supply
       val newVariables=newTypeVariables definition ns2
       val combined=zip constructors(zip parameters expressions)
       val(reorderedParameters,reorderedExpressions)=unzip(reorderConstructors expectedConstructors combined)
   in if not(equalInt(length expectedConstructors)(length(unique equalName constructors)))
        then myFail"Error in source program: missing alternatives in CASE"
      else
       let val(ns1,ns2)=splitTypeSupply ns1
           val gammas=allConstructorGammas newVariables alternatives reorderedParameters
           fun rightSides supply gammas expressions=F.defer(fn()=>case(force gammas,force expressions)of
              (F.Nil,F.Nil)=>F.empty()
             |(F.Cons(g,gt),F.Cons(e,et))=>let val(s1,s2)=splitTypeSupply supply
                in F.cons(cell(infer definitions(F.append g gamma)s1 e),rightSides s2 gt et)end
             |_=>raise Match)
           val results=rightSides ns1 gammas reorderedExpressions
           val substitutions=map(fn reply=>infoSubstitution(force reply))results
           val types=map(fn reply=>infoType(force reply))results
           val rhsPhi=checkUnifier(unifyTypeSet(F.empty())types)
           val selectorReply=infer definitions gamma ns2 selector
           val selectorPhi=infoSubstitution selectorReply
           val selectorType=infoType selectorReply
           val selectorTree=infoTree selectorReply
           val phi=mergeSubstitutions(F.append(concat substitutions)(F.append rhsPhi selectorPhi))
           val typeVariables=map(fn entry=>let val(_,v)=force entry in v end)newVariables
           val signatureType=cell(TCons(n,map(fn v=>cell(TVar v))typeVariables))
           val expected=substituteType phi signatureType
           val lhs=checkUnifier(unify(F.empty())(expected,selectorType))
           val bigPhi=mergeSubstitutions(F.append lhs phi)
           val finalType=substituteType bigPhi(head types)
           val trees=map(fn reply=>infoTree(force reply))results
           val alternatives=zip expectedConstructors(zip reorderedParameters trees)
       in Ok(triple bigPhi finalType(pair finalType(cell(ACase(selectorTree,alternatives)))))end
   end)

(* type-check: portable source translation. *)
 fun typedTreeEnvironment(tree:typedAnnotation)=
   let fun nodeEntries node=F.defer(fn()=>case force node of
          AVar _=>F.empty()|ANum _=>F.empty()|AConstr _=>F.empty()
         |AAp(a,b)=>F.append(entries a)(entries b)
         |ALam(_,body)=>entries body
         |ACase(e,alternatives)=>F.append(entries e)(concat(map(fn entry=>
              let val(_,body)=force entry val(_,e)=force body in entries e end)alternatives))
         |ALet(_,definitions,body)=>F.append(concat(map definitionEntries definitions))(entries body))
       and entries tree=let val(_,node)=force tree in nodeEntries node end
       and definitionEntries definition=let val(n,tree)=force definition val(t,node)=force tree
         in F.cons(pair n t,nodeEntries node)end
   in entries tree end
 fun prettyTypeBinding entry=F.defer(fn()=>
   let val(n,t)=force entry val label=F.append n(name" :: ")
       val padded=F.append label(copy(subtract(int 25)(length label))(cell #" "))
   in F.append(name"\n   ")(F.append padded(showType t))end)
 type checkedReply=(typedAnnotation*fullTypeEnv,nameNode)replyNode L.delay
 val builtinTypeDefinitions:typeDef F.seq=
   singleton(triple(name"bool")(F.empty())(F.cons(pair(name"True")(F.empty()),singleton(pair(name"False")(F.empty())))))
 fun checkTypes baseTypes supply program=
   let val(definitions,expression)=force program
       val definitions=F.append definitions builtinTypeDefinitions
       fun constructors supply definition=
         let val(next,schemes)=constructorTypeSchemes(force supply)definition
         in(cell next,schemes)end
       val accumulated=mapAccumulate constructors(cell supply)definitions
       val finalSupply=let val(final,_)=L.force accumulated in force final end
       val constructorGroups=F.defer(fn()=>let val(_,groups)=L.force accumulated in groups end)
       val constructorTypes=concat constructorGroups
       val result=infer definitions(F.append baseTypes constructorTypes)finalSupply expression
       val checked:checkedReply=L.delay(fn()=>case L.force result of Failed _=>Failed(name"No type")
         |Ok value=>let val(phi,t,tree)=force value
             val root=mapAnnotation(substituteType phi)tree
             val fromTree=typedTreeEnvironment root
             val constructorEnvironment=map(fn entry=>let val(n,scheme)=force entry
                val Scheme(_,t)=force scheme in pair n t end)constructorTypes
             val environment=F.append fromTree constructorEnvironment
           in Ok(pair root environment)end)
       val words=F.defer(fn()=>case L.force checked of Failed _=>F.empty()
         |Ok value=>let val(_,environment)=force value
           in concat(map prettyTypeBinding environment)end)
   in(words,checked)end

(* base-types: portable source translation. *)
 val baseTypes:typeEnv=
   let val intBinary=cell(TArr(intType,cell(TArr(intType,intType))))
       val comparison=cell(TArr(intType,cell(TArr(intType,boolType))))
       val boolBinary=cell(TArr(boolType,cell(TArr(boolType,boolType))))
       val boolUnary=cell(TArr(boolType,boolType))
       val items=[("_not",boolUnary),("_+",intBinary),("_-",intBinary),("_*",intBinary),
          ("_/",intBinary),("_%",intBinary),("_<",comparison),("_<=",comparison),
          ("_==",comparison),("_~=",comparison),("_>=",comparison),("_>",comparison),
          ("_|",boolBinary),("_&",boolBinary),("_#",boolBinary)]
   in F.fromList(List.map(fn(n,t)=>(name n,cell(Scheme(F.empty(),t))))items)end

(* eta: portable source translation. *)
 fun curryType result types:texpr=D.delay(fn()=>case force types of F.Nil=>force result
   |F.Cons(arg,rest)=>TArr(arg,curryType result rest))
 fun uncurryType expression=L.delay(fn()=>case force expression of
    TVar variable=>(F.empty(),cell(TVar variable))
   |TCons(n,args)=>(F.empty(),cell(TCons(n,args)))
   |TArr(arg,result)=>let val rest=uncurryType result
       val arguments=F.defer(fn()=>let val(args,_)=L.force rest in args end)
       val final=D.delay(fn()=>let val(_,result)=L.force rest in force result end)
     in(F.cons(arg,arguments),final)end)
 fun etaNewArguments count names=
   let val leading=filter(fn name=>not(null name))(map(takeWhile(fn c=>force c= #"v"))names)
       val root=F.append(last(insertionSort compareName(F.cons(F.empty(),leading))))(name"v")
   in map(fn n=>F.append root(name(signed n)))(intsFromTo(int 1)count)end
 fun etaMain entry argumentTypes resultType=
   let val(n,tree)=force entry val(tau,node)=force tree
       val(args,body)=case force node of ALam(args,body)=>(args,body)|_=>raise Match
       val actual=length args val required=length argumentTypes
       val newArgs=etaNewArguments(subtract required actual)args
       val newTypes=zipExact pair newArgs(drop actual argumentTypes)
       val appArgs=map(fn n=>drop n argumentTypes)(intsFromTo actual(subtract required(int 1)))
       val appTypes=map(curryType resultType)appArgs
       val specs=zipExact pair newTypes appTypes
       fun chain specs tree=case force specs of F.Nil=>tree|F.Cons(spec,rest)=>
         let val(vtype,aptype)=force spec val(v,t)=force vtype
         in chain rest(pair aptype(cell(AAp(tree,pair t(cell(AVar v))))))end
       val newBody=chain specs body
   in pair n(pair tau(cell(ALam(F.append args newArgs,newBody))))end
 fun etaAbstract(tree:typedAnnotation):typedAnnotation=D.delay(fn()=>
   let val(tau,node)=force tree
   in case force node of AVar _=>force tree|ANum _=>force tree|AConstr _=>force tree
      |AAp(a,b)=>(tau,cell(AAp(etaAbstract a,etaAbstract b)))
      |ALam(args,e)=>(tau,cell(ALam(args,etaAbstract e)))
      |ACase(e,alternatives)=>(tau,cell(ACase(etaAbstract e,map(fn entry=>
          let val(n,value)=force entry val(args,e)=force value
          in pair n(pair args(etaAbstract e))end)alternatives)))
      |ALet(recursive,definitions,body)=>
         let val info=map(fn entry=>let val(_,tree)=force entry val(t,_)=force tree
               in cell(uncurryType t)end)definitions
             fun merge tree=D.delay(fn()=>let val(t,node)=force tree
               in case force node of ALam(args,body)=>let val(_,inner)=force body
                    in case force inner of ALam(more,e)=>force(merge(pair t(cell(ALam(F.append args more,e)))))
                      |_=>force tree end|_=>force tree end)
             val merged=mapSecond merge definitions
             fun fix entry info=
               let val(_,tree)=force entry val(t,node)=force tree val(args,result)=L.force(force info)
               in case force node of ALam(parameters,_)=>
                   if equalInt(length parameters)(length args)then entry
                   else if less(length args)(length parameters)then panic"eaEtaAbstract"
                   else etaMain entry args result
                  |_=>if null args then entry else
                     let val(n,_)=force entry
                     in etaMain(pair n(pair t(cell(ALam(F.empty(),tree)))))args result end
               end
             val fixed=zipExact fix merged info
         in(tau,cell(ALet(recursive,fixed,etaAbstract body)))end end)

(* abstract-bounds: portable source translation. *)
 fun makeFrontier arity ones zeros=cell(Min1Max0(arity,ones,zeros))
 fun uncurryDomain arguments domain=D.delay(fn()=>case force domain of
   Func(more,result)=>Func(F.append arguments more,result)|_=>Func(arguments,domain))
 fun topRoute domain:route=D.delay(fn()=>case force domain of
    Two=>One|Lift1 ds=>Up1(map topRoute ds)|Lift2 ds=>UpUp2(map topRoute ds)
   |Func _=>Rep(topRepresentation domain))
 and topFrontier arguments=makeFrontier(length arguments)
     (singleton(cell(MkFrel(map bottomRoute arguments))))(F.empty())
 and topRepresentation domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,result)=>(case force result of
      Two=>RepTwo(topFrontier arguments)
     |Lift1 ds=>let val low=topFrontier arguments
        in Rep1(low,map topRepresentation(map(uncurryDomain arguments)ds))end
     |Lift2 ds=>let val low=topFrontier arguments
        in Rep2(low,low,map topRepresentation(map(uncurryDomain arguments)ds))end
     |_=>raise Match)|_=>raise Match)
 and bottomRoute domain:route=D.delay(fn()=>case force domain of
    Two=>Zero|Lift1 _=>Stop1|Lift2 _=>Stop2|Func _=>Rep(bottomRepresentation domain))
 and bottomFrontier arguments=makeFrontier(length arguments)(F.empty())
     (singleton(cell(MkFrel(map topRoute arguments))))
 and bottomRepresentation domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,result)=>(case force result of Two=>RepTwo(bottomFrontier arguments)
     |Lift1 ds=>let val low=bottomFrontier arguments
        in Rep1(low,map bottomRepresentation(map(uncurryDomain arguments)ds))end
     |Lift2 ds=>let val low=bottomFrontier arguments
        in Rep2(low,low,map bottomRepresentation(map(uncurryDomain arguments)ds))end
     |_=>raise Match)|_=>raise Match)
 fun isBottomRoute route=case force route of Zero=>true|Stop1=>true|Stop2=>true
   |One=>false|Up1 _=>false|Up2=>false|UpUp2 _=>false|Rep rep=>isBottomRepresentation rep
 and isBottomRepresentation rep=
   let val low=case force rep of RepTwo low=>low|Rep1(low,_)=>low|Rep2(low,_,_)=>low
       val Min1Max0(_,ones,_)=force low
   in null ones end
 fun isTopRoute route=case force route of Zero=>false|One=>true|Stop1=>false
   |Up1 rs=>all isTopRoute rs|Stop2=>false|Up2=>false|UpUp2 rs=>all isTopRoute rs
   |Rep rep=>isTopRepresentation rep
 and isTopRepresentation rep=case force rep of
    RepTwo f=>let val Min1Max0(_,_,zeros)=force f in null zeros end
   |Rep1(_,highs)=>all isTopRepresentation highs|Rep2(_,_,highs)=>all isTopRepresentation highs

(* abstract-order: portable source translation. *)
 fun belowRoute left right=case force left of
    Zero=>true|Stop1=>true|Stop2=>true
   |One=>(case force right of One=>true|Zero=>false|_=>raise Match)
   |Up1 xs=>(case force right of Up1 ys=>belowRouteList xs ys|_=>false)
   |Up2=>(case force right of Stop2=>false|_=>true)
   |UpUp2 xs=>(case force right of UpUp2 ys=>belowRouteList xs ys|_=>false)
   |Rep r=>(case force right of Rep s=>belowRepresentation r s|_=>raise Match)
 and belowRouteList xs ys=
   let fun mismatch()=panic"avLEQR_list: unequal lists"
   in case(force xs,force ys)of(F.Nil,F.Nil)=>true
     |(F.Cons(a,at),F.Cons(b,bt))=>(case(force at,force bt)of
        (F.Nil,F.Nil)=>belowRoute a b
       |(F.Cons(c,ct),F.Cons(d,dt))=>(case(force ct,force dt)of
          (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d
         |(F.Cons(e,et),F.Cons(f,ft))=>(case(force et,force ft)of
            (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f
           |(F.Cons(g,gt),F.Cons(h,ht))=>(case(force gt,force ht)of
              (F.Nil,F.Nil)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f andalso belowRoute g h
             |(F.Cons _,F.Cons _)=>belowRoute a b andalso belowRoute c d andalso belowRoute e f
                    andalso belowRoute g h andalso belowRouteList gt ht
             |_=>mismatch())
           |_=>mismatch())
         |_=>mismatch())
       |_=>mismatch())
     |_=>mismatch()end
 and belowFrel left right=let val MkFrel xs=force left val MkFrel ys=force right
   in belowRouteList xs ys end
 and belowFrontier left right=
   let val Min1Max0(_,ones,_)=force left val Min1Max0(_,targets,_)=force right
       fun inner y values=case force values of F.Nil=>false|F.Cons(z,rest)=>
          if belowFrel z y then true else inner y rest
       fun outer values=case force values of F.Nil=>true|F.Cons(x,rest)=>
          if inner x targets then outer rest else false
   in outer ones end
 and belowRepresentation left right=
   let fun exact xs ys=case(force xs,force ys)of(F.Nil,F.Nil)=>true
          |(F.Cons(x,xt),F.Cons(y,yt))=>belowRepresentation x y andalso exact xt yt
          |_=>panic"myAndWith2: unequal lists"
   in case(force left,force right)of
       (RepTwo x,RepTwo y)=>belowFrontier x y
      |(Rep1(x,xs),Rep1(y,ys))=>belowFrontier x y andalso exact xs ys
      |(Rep2(x,z,xs),Rep2(y,w,ys))=>belowFrontier x y andalso belowFrontier z w andalso exact xs ys
      |_=>raise Match end
 fun minimumAdd below x ys=F.defer(fn()=>if any(fn y=>below y x)ys then ys
   else F.cons(x,filter(fn y=>not(below x y))ys))
 fun maximumAdd below x ys=F.defer(fn()=>if any(fn y=>below x y)ys then ys
   else F.cons(x,filter(fn y=>not(below y x))ys))
 fun minimal below values=foldRight(minimumAdd below)(F.empty())values
 fun maximal below values=foldRight(maximumAdd below)(F.empty())values

(* abstract-lattice: portable source translation. *)
 fun joinRoute left right:route=D.delay(fn()=>case force left of
    Zero=>force right|One=>force left|Stop1=>force right|Stop2=>force right
   |Up1 xs=>(case force right of Stop1=>force left|Up1 ys=>Up1(zipExact joinRoute xs ys)|_=>raise Match)
   |Up2=>(case force right of Stop2=>force left|_=>force right)
   |UpUp2 xs=>(case force right of UpUp2 ys=>UpUp2(zipExact joinRoute xs ys)|_=>force left)
   |Rep x=>(case force right of Rep y=>Rep(joinRepresentation x y)|_=>raise Match))
 and joinFrel left right:frontierElem=D.delay(fn()=>
   let val MkFrel xs=force left val MkFrel ys=force right in MkFrel(zipExact joinRoute xs ys)end)
 and joinFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force left val Min1Max0(_,otherOnes,otherZeros)=force right
       val minimum=insertionSort compareFrel(foldRight(minimumAdd belowFrel)ones otherOnes)
       val products=flatMap(fn x=>map(meetFrel x)otherZeros)zeros
       val maximum=insertionSort compareFrel(maximal belowFrel products)
   in Min1Max0(arity,minimum,maximum)end)
 and joinRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(joinFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(joinFrontier x y,zipExact joinRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(joinFrontier x y,joinFrontier z w,zipExact joinRepresentation xs ys)
   |_=>raise Match)
 and meetRoute left right:route=D.delay(fn()=>case force left of
    Zero=>force left|One=>force right|Stop1=>force left|Stop2=>force left
   |Up1 xs=>(case force right of Up1 ys=>Up1(zipExact meetRoute xs ys)|_=>force right)
   |Up2=>(case force right of Stop2=>force right|_=>force left)
   |UpUp2 xs=>(case force right of UpUp2 ys=>UpUp2(zipExact meetRoute xs ys)|_=>force right)
   |Rep x=>(case force right of Rep y=>Rep(meetRepresentation x y)|_=>raise Match))
 and meetFrel left right:frontierElem=D.delay(fn()=>
   let val MkFrel xs=force left val MkFrel ys=force right in MkFrel(zipExact meetRoute xs ys)end)
 and meetFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force left val Min1Max0(_,otherOnes,otherZeros)=force right
       val maximum=insertionSort compareFrel(foldRight(maximumAdd belowFrel)zeros otherZeros)
       val products=flatMap(fn x=>map(joinFrel x)otherOnes)ones
       val minimum=insertionSort compareFrel(minimal belowFrel products)
   in Min1Max0(arity,minimum,maximum)end)
 and meetRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(meetFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(meetFrontier x y,zipExact meetRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(meetFrontier x y,meetFrontier z w,zipExact meetRepresentation xs ys)
   |_=>raise Match)

(* domain-expressions: portable source translation. *)
 fun defaultDomain expression:domain=D.delay(fn()=>case force expression of DXTwo=>Two|DXVar _=>Two
   |DXLift1 expressions=>if null expressions then Two else Lift1(map defaultDomain expressions)
   |DXLift2 expressions=>if null expressions then Lift1(singleton(cell Two))else Lift2(map defaultDomain expressions)
   |DXFunc(arguments,result)=>Func(map defaultDomain arguments,defaultDomain result))
 fun applyDomainSubstitution substitutions expression:domain=D.delay(fn()=>case force expression of
    DXTwo=>Two|DXVar n=>force(sureLookup equalName substitutions"dxApplySubst"n)
   |DXLift1 expressions=>if null expressions then Two else Lift1(map(applyDomainSubstitution substitutions)expressions)
   |DXLift2 expressions=>if null expressions then Lift1(singleton(cell Two))
      else Lift2(map(applyDomainSubstitution substitutions)expressions)
   |DXFunc(arguments,result)=>Func(map(applyDomainSubstitution substitutions)arguments,applyDomainSubstitution substitutions result))
 fun normalizeDomainExpression expression:dexpr=D.delay(fn()=>case force expression of
    DXTwo=>DXTwo|DXVar n=>DXVar n
   |DXLift1 expressions=>DXLift1(map normalizeDomainExpression expressions)
   |DXLift2 expressions=>DXLift2(map normalizeDomainExpression expressions)
   |DXFunc(arguments,result)=>(case force result of DXFunc(more,result)=>
        force(normalizeDomainExpression(cell(DXFunc(F.append arguments more,result))))
       |_=>DXFunc(map normalizeDomainExpression arguments,normalizeDomainExpression result)))
 fun expressionContainsFunctions expression=case force expression of DXTwo=>false|DXVar _=>false
   |DXLift1 expressions=>any expressionContainsFunctions expressions
   |DXLift2 expressions=>any expressionContainsFunctions expressions|DXFunc _=>true
 fun expressionContainsSubsidiaryFunctions expression=case force expression of DXTwo=>false|DXVar _=>false
   |DXLift1 expressions=>any expressionContainsFunctions expressions
   |DXLift2 expressions=>any expressionContainsFunctions expressions
   |DXFunc(arguments,result)=>any expressionContainsFunctions arguments orelse expressionContainsFunctions result
 type domainDifferenceState=integer*(name*domain)F.seq
 type domainDifferenceResult=(dexpr*domainDifferenceState)L.delay
 fun differenceAux smaller big state:domainDifferenceResult=L.delay(fn()=>case(force smaller,force big)of
    (Two,Two)=>(cell DXTwo,state)
   |(Two,_)=>let val(n,substitutions)=state
        val variable=singleton(cell(Char.chr(small n)))
      in(cell(DXVar variable),(add n(int 1),F.cons(pair variable big,substitutions)))end
   |(Lift1 xs,Lift1 ys)=>let val result=differenceList xs ys state
        val expressions=F.defer(fn()=> #1(L.force result))
        val next= #2(L.force result)
      in(cell(DXLift1 expressions),next)end
   |(Lift2 xs,Lift2 ys)=>let val result=differenceList xs ys state
        val expressions=F.defer(fn()=> #1(L.force result))
      in(cell(DXLift2 expressions),#2(L.force result))end
   |(Func(xs,x),Func(ys,y))=>
      let val args=differenceList xs ys state
          val arguments=F.defer(fn()=> #1(L.force args))
          val result=differenceAux x y(#2(L.force args))
          val expression=D.delay(fn()=>force(#1(L.force result)))
      in(cell(DXFunc(arguments,expression)),#2(L.force result))end
   |_=>panic"dxDiff_aux")
 and differenceList xs ys state=L.delay(fn()=>case(force xs,force ys)of
    (F.Nil,F.Nil)=>(F.empty(),state)
   |(F.Cons(x,xt),F.Cons(y,yt))=>let val first=differenceAux x y state
        val rest=differenceList xt yt(#2(L.force first))
        val expression=D.delay(fn()=>force(#1(L.force first)))
      in(F.cons(expression,F.defer(fn()=> #1(L.force rest))),#2(L.force rest))end
   |_=>panic"dxDiff_list: unequal lists")
 fun domainDifference big small=
   let val result=differenceAux small big(int 97,F.empty())
       val(expression,(_,substitutions))=L.force result
   in(expression,substitutions)end

(* abstract-eval: portable source translation. *)
 fun andWith predicate xs ys=case(force xs,force ys)of(F.Nil,F.Nil)=>true
   |(F.Cons(x,xt),F.Cons(y,yt))=>predicate x y andalso andWith predicate xt yt
   |_=>panic"myAndWith2: unequal lists"
 fun foldRight1 f xs=D.delay(fn()=>case force xs of F.Nil=>raise Empty|F.Cons(x,rest)=>
   if null rest then force x else force(f x(foldRight1 f rest)))
 fun partialFrontier count frontier arguments:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier
       fun trim value=let val MkFrel routes=force value in cell(MkFrel(drop count routes))end
       val ones=insertionSort compareFrel(minimal belowFrel(map trim
         (filter(fn value=>let val MkFrel routes=force value
            in andWith belowRoute(take count routes)arguments end)ones)))
       val zeros=insertionSort compareFrel(maximal belowFrel(map trim
         (filter(fn value=>let val MkFrel routes=force value
            in andWith belowRoute arguments(take count routes)end)zeros)))
   in if leq count arity then Min1Max0(subtract arity count,ones,zeros)else panic"apPap_2"end)
 fun partialRepresentation rep arguments:representation=D.delay(fn()=>case force rep of
    RepTwo frontier=>RepTwo(partialFrontier(length arguments)frontier arguments)
   |Rep1(low,highs)=>Rep1(partialFrontier(length arguments)low arguments,
        map(fn rep=>partialRepresentation rep arguments)highs)
   |Rep2(low,middle,highs)=>Rep2(partialFrontier(length arguments)low arguments,
        partialFrontier(length arguments)middle arguments,map(fn rep=>partialRepresentation rep arguments)highs))
 fun constantRepresentation rep:route=D.delay(fn()=>case force rep of
    RepTwo frontier=>let val Min1Max0(arity,ones,zeros)=force frontier
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Zero
         else if not(null ones)andalso null zeros then One else panic"apPapConst(1)"end
   |Rep1(low,highs)=>let val Min1Max0(arity,ones,zeros)=force low
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Stop1
         else if not(null ones)andalso null zeros then Up1(map constantRepresentation highs)
         else panic"apPapConst(2)"end
   |Rep2(low,middle,highs)=>let val Min1Max0(arity,ones,zeros)=force low
          val Min1Max0(_,middleOnes,middleZeros)=force middle
      in if less(int 0)arity then Rep rep
         else if null ones andalso not(null zeros)then Stop2
         else if null middleOnes andalso not(null middleZeros)then Up2
         else if not(null middleOnes)andalso null middleZeros then UpUp2(map constantRepresentation highs)
         else panic"apPapConst(3)"end)
 fun applyRoute function arguments:route=D.delay(fn()=>case force function of Rep rep=>
   force(constantRepresentation(partialRepresentation rep arguments))|_=>raise Match)
 fun evaluateAbstract(expression:hexpr):hexpr=D.delay(fn()=>case force expression of
    HVar _=>panic"aeEval(1)"|HLam _=>panic"aeEval(2)"|HTable _=>panic"aeEval(3)"
   |HPoint _=>force expression
   |HMeet expressions=>HPoint(foldRight1 joinRoute(map evaluateConstant expressions))
   |HVAp(f,args)=>(case force f of HPoint function=>HPoint(applyRoute function(map evaluateConstant args))
       |_=>panic"aeEval(4)")
   |HApp(f,arg)=>(case force f of HTable table=>
         force(evaluateAbstract(sureLookup equalRoute table"aeEval(5)"(evaluateConstant arg)))
      |HApp _=>force(evaluateAbstract(cell(HApp(evaluateAbstract f,arg))))
      |HPoint _=>force(evaluateAbstract(cell(HVAp(f,singleton arg))))
      |_=>panic"aeEval(4)"))
 and evaluateConstant expression:route=D.delay(fn()=>case force(evaluateAbstract expression)of
    HPoint point=>force point|_=>panic"aeEvalConst")
 fun substituteAbstract rho(expression:hexpr):hexpr=D.delay(fn()=>case force expression of
    HVar n=>force(sureLookup equalName rho"aeSubst"n)
   |HPoint _=>force expression|HLam _=>panic"aeSubst(1)"
   |HMeet expressions=>HMeet(map(substituteAbstract rho)expressions)
   |HTable entries=>HTable(mapSecond(substituteAbstract rho)entries)
   |HApp(a,b)=>HApp(substituteAbstract rho a,substituteAbstract rho b)
   |HVAp(f,args)=>HVAp(substituteAbstract rho f,map(substituteAbstract rho)args))
 fun evaluateExact expression arguments:route=D.delay(fn()=>case force expression of
    HLam(variables,body)=>force(evaluateConstant(substituteAbstract(zipExact pair variables arguments)body))
   |_=>raise Match)
 fun makeAbstractMeet bottom expressions:hexpr=D.delay(fn()=>case force expressions of
    F.Nil=>force bottom|F.Cons(x,rest)=>if null rest then force x else HMeet expressions)

(* adjacent: portable source translation. *)
 fun isSingletonList values=case force values of F.Nil=>false|F.Cons(_,rest)=>null rest
 fun joinZeroFrontiers xs ys=insertionSort compareFrel(maximal belowFrel(flatMap(fn x=>map(meetFrel x)ys)xs))
 fun meetOneFrontiers xs ys=insertionSort compareFrel(minimal belowFrel(flatMap(fn x=>map(joinFrel x)ys)xs))
 fun successors domain point=F.defer(fn()=>case(force domain,force point)of
    (Two,Zero)=>singleton(cell One)|(Two,One)=>F.empty()
   |(Lift1 ds,Stop1)=>singleton(cell(Up1(map bottomRoute ds)))
   |(Lift1 ds,Up1 rs)=>
      if isSingletonList ds andalso isSingletonList rs
      then map(fn r=>cell(Up1(singleton r)))(successors(head ds)(head rs))
      else map(fn values=>cell(Up1 values))(listVariants(map bottomRoute ds)(zipExact successors ds rs))
   |(Lift2 ds,Stop2)=>singleton(cell Up2)
   |(Lift2 ds,Up2)=>singleton(cell(UpUp2(map bottomRoute ds)))
   |(Lift2 ds,UpUp2 rs)=>
      if isSingletonList ds andalso isSingletonList rs
      then map(fn r=>cell(UpUp2(singleton r)))(successors(head ds)(head rs))
      else map(fn values=>cell(UpUp2 values))(listVariants(map bottomRoute ds)(zipExact successors ds rs))
   |(Func _,Rep r)=>map(fn r=>cell(Rep r))(successorRepresentations domain r)
   |_=>raise Match)
 and successorRepresentations domain rep=F.defer(fn()=>case(force domain,force rep)of
    (Func(arguments,result),RepTwo frontier)=>(case force result of Two=>
      let val Min1Max0(arity,_,zeros)=force frontier
      in map(fn x=>cell(RepTwo(makeFrontier arity(singleton x)
           (insertionSort compareFrel(predecessorFrels arguments x)))))zeros end|_=>raise Match)
   |(Func(arguments,result),Rep1(low,highs))=>(case force result of Lift1 targets=>
      let val highDomains=map(uncurryDomain arguments)targets
          val bottoms=map bottomRepresentation highDomains
          val tops=map topRoute arguments
          val lowSucc=successorRepresentations(cell(Func(arguments,cell Two)))(cell(RepTwo low))
          val embedded=flatMap(fn rep=>case force rep of RepTwo f=>singleton(cell(Rep1(f,bottoms)))|_=>F.empty())lowSucc
          val variants=listVariants bottoms(zipExact successorRepresentations highDomains highs)
          val lifted=map(lowerLift tops arguments highDomains)variants
      in minimal belowRepresentation(F.append embedded lifted)end|_=>raise Match)
   |(Func(arguments,result),Rep2(low,middle,highs))=>(case force result of Lift2 targets=>
      let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
          val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
      in map isoRepresentationInverse(successorRepresentations isoDomain isoRoute)end|_=>raise Match)
   |_=>raise Match)
 and predecessorFrels domains value=
   let val MkFrel routes=force value
   in if isSingletonList domains andalso isSingletonList routes
       then map(fn r=>cell(MkFrel(singleton r)))(predecessors(head domains)(head routes))
      else map(fn values=>cell(MkFrel values))(listVariants(map topRoute domains)(zipExact predecessors domains routes))end
 and successorFrels domains value=
   let val MkFrel routes=force value
   in if isSingletonList domains andalso isSingletonList routes
       then map(fn r=>cell(MkFrel(singleton r)))(successors(head domains)(head routes))
      else map(fn values=>cell(MkFrel values))(listVariants(map bottomRoute domains)(zipExact successors domains routes))end
 and predecessors domain point=F.defer(fn()=>case(force domain,force point)of
    (Two,Zero)=>F.empty()|(Two,One)=>singleton(cell Zero)
   |(Lift1 _,Stop1)=>F.empty()
   |(Lift1 ds,Up1 rs)=>
      if isSingletonList ds andalso isSingletonList rs
        then if isBottomRoute(head rs)then singleton(cell Stop1)
          else map(fn r=>cell(Up1(singleton r)))(predecessors(head ds)(head rs))
        else if all isBottomRoute rs then singleton(cell Stop1)
          else map(fn values=>cell(Up1 values))(listVariants(map topRoute ds)(zipExact predecessors ds rs))
   |(Lift2 _,Stop2)=>F.empty()|(Lift2 _,Up2)=>singleton(cell Stop2)
   |(Lift2 ds,UpUp2 rs)=>
      if isSingletonList ds andalso isSingletonList rs
        then if isBottomRoute(head rs)then singleton(cell Up2)
          else map(fn r=>cell(UpUp2(singleton r)))(predecessors(head ds)(head rs))
        else if all isBottomRoute rs then singleton(cell Up2)
          else map(fn values=>cell(UpUp2 values))(listVariants(map topRoute ds)(zipExact predecessors ds rs))
   |(Func _,Rep r)=>map(fn r=>cell(Rep r))(predecessorRepresentations domain r)|_=>raise Match)
 and predecessorRepresentations domain rep=F.defer(fn()=>case(force domain,force rep)of
    (Func(arguments,result),RepTwo frontier)=>(case force result of Two=>
      let val Min1Max0(arity,ones,_)=force frontier
      in map(fn x=>cell(RepTwo(makeFrontier arity(insertionSort compareFrel(successorFrels arguments x))
          (singleton x))))ones end|_=>raise Match)
   |(Func(arguments,result),Rep1(low,highs))=>(case force result of Lift1 targets=>
      let val highDomains=map(uncurryDomain arguments)targets
          val tops=map topRepresentation highDomains
          val lowDomain=cell(Func(arguments,cell Two))
          val lowTop=topFrontier arguments
          val lowPred=predecessorRepresentations lowDomain(cell(RepTwo low))
          val embedded=flatMap(fn rep=>case force rep of RepTwo f=>singleton(greaterEmbed f targets)|_=>F.empty())lowPred
          val variants=listVariants tops(zipExact predecessorRepresentations highDomains highs)
          val lifted=map(fn reps=>cell(Rep1(lowTop,reps)))variants
      in maximal belowRepresentation(F.append embedded lifted)end|_=>raise Match)
   |(Func(arguments,result),Rep2(low,middle,highs))=>(case force result of Lift2 targets=>
      let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
          val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
      in map isoRepresentationInverse(predecessorRepresentations isoDomain isoRoute)end|_=>raise Match)
   |_=>raise Match)
 and isoRepresentationInverse rep=D.delay(fn()=>case force rep of Rep1(low,values)=>
      if isSingletonList values then(case force(head values)of Rep1(middle,highs)=>Rep2(low,middle,highs)|_=>raise Match)
        else raise Match|_=>raise Match)
 and lowerLift tops arguments domains reps:representation=D.delay(fn()=>
   let val arity=length tops
       val reduced=zipExact(lowerLiftAux arity tops arguments)domains reps
       val low=case force(foldRight1 joinRepresentation reduced)of RepTwo low=>low|_=>raise Match
   in Rep1(low,reps)end)
 and lowerLiftAux arity tops arguments domain rep=
   case force domain of Func(_,result)=>(case(force result,force rep)of
      (Two,_)=>reduceArity arity tops arguments rep
     |(Lift1 _,Rep1(low,_))=>reduceArity arity tops arguments(cell(RepTwo low))
     |(Lift2 _,Rep2(low,_,_))=>reduceArity arity tops arguments(cell(RepTwo low))
     |_=>raise Match)|_=>raise Match
 and reduceArity arity tops arguments rep:representation=D.delay(fn()=>case force rep of RepTwo frontier=>
   let val Min1Max0(oldArity,ones,zeros)=force frontier
   in if equalInt oldArity arity then force rep else if less arity oldArity then
       let val shortened=map(fn value=>let val MkFrel rs=force value in cell(MkFrel(take arity rs))end)ones
           val zeros=maxZeroFromMinOneAux tops arguments shortened
       in RepTwo(makeFrontier arity shortened zeros)end else raise Match end|_=>raise Match)
 and greaterEmbed frontier targets:representation=cell(Rep1(frontier,map(greaterEmbedAux frontier)targets))
 and greaterEmbedAux frontier domain:representation=D.delay(fn()=>case force domain of Two=>RepTwo frontier
   |Lift1 ds=>Rep1(frontier,map(greaterEmbedAux frontier)ds)
   |Lift2 ds=>Rep2(frontier,frontier,map(greaterEmbedAux frontier)ds)
   |Func(arguments,result)=>let val extended=case force(increaseArity frontier arguments)of RepTwo f=>f|_=>raise Match
       in force(greaterEmbedAux extended result)end)
 and increaseArity frontier domains:representation=D.delay(fn()=>if null domains then RepTwo frontier else
   let val Min1Max0(arity,ones,zeros)=force frontier
       val tops=map topRoute domains val bottoms=map bottomRoute domains
       fun extend suffix value=let val MkFrel rs=force value in cell(MkFrel(F.append rs suffix))end
   in RepTwo(makeFrontier(add arity(length domains))(map(extend bottoms)ones)(map(extend tops)zeros))end)
 and maxZeroFromMinOneAux tops domains ones=
   insertionSort compareFrel(foldRight joinZeroFrontiers(singleton(cell(MkFrel tops)))(map(predecessorFrels domains)ones))
 and minOneFromMaxZeroAux bottoms domains zeros=
   insertionSort compareFrel(foldRight meetOneFrontiers(singleton(cell(MkFrel bottoms)))(map(successorFrels domains)zeros))

(* abstract-misc: portable source translation. *)
 fun immediateAbove domain point=map(joinRoute point)(successors domain point)
 fun immediateBelow domain point=map(meetRoute point)(predecessors domain point)
 fun pushUp domain points=F.defer(fn()=>if null points then F.empty()
   else unique equalRoute(concat(map(immediateAbove domain)points)))
 fun pushDown domain points=F.defer(fn()=>if null points then F.empty()
   else unique equalRoute(concat(map(immediateBelow domain)points)))
 fun slices step initial=
   let fun produce slice=C.defer(fn()=>C.cons(L.delay(fn()=>slice),produce(step slice)))
       fun consume values=F.defer(fn()=>case L.force values of C.Nil=>F.empty()
         |C.Cons(slice,rest)=>let val slice=L.force slice
           in if null slice then F.empty()else F.cons(slice,consume rest)end)
   in consume(produce initial)end
 fun allUpSlices domain=slices(pushUp domain)(singleton(bottomRoute domain))
 fun allDownSlices domain=slices(pushDown domain)(singleton(topRoute domain))
 fun allRoutes domain=F.defer(fn()=>case force domain of Two=>F.fromList[Zero,One]
   |Lift1 ds=>F.cons(cell Stop1,map(fn routes=>cell(Up1 routes))(cartesianProduct(map allRoutes ds)))
   |Lift2 ds=>F.cons(cell Stop2,F.cons(cell Up2,
        map(fn routes=>cell(UpUp2 routes))(cartesianProduct(map allRoutes ds))))
   |Func(arguments,result)=>concat(allUpSlices(cell(Func(arguments,result)))))
 fun upwardClosure domain points=F.defer(fn()=>case force points of F.Nil=>F.empty()
   |F.Cons(x,_)=>F.cons(x,upwardClosure domain(minimal belowRoute(
       flatMap(fn y=>map(joinRoute y)(successors domain x))points))))
 fun downwardClosure domain points=F.defer(fn()=>case force points of F.Nil=>F.empty()
   |F.Cons(x,_)=>F.cons(x,downwardClosure domain(maximal belowRoute(
       flatMap(fn y=>map(meetRoute y)(predecessors domain x))points))))
 fun allRoutesMinusTop domain=downwardClosure domain(predecessors domain(topRoute domain))
 fun equalPoints(a,x)(b,y)=if equalDomain a b then equalRoute x y else panic"Comparing points in different domains."
 fun containsFunctions domain=case force domain of Two=>false
   |Lift1 ds=>any containsFunctions ds|Lift2 ds=>any containsFunctions ds|Func _=>true
 fun isHigherOrderFunction domain=case force domain of Func(args,result)=>
    containsFunctions result orelse any containsFunctions args|_=>raise Match
 fun isDataFunction domain=case force domain of Func(_,result)=>not(containsFunctions result)|_=>raise Match
 fun representationArity rep=let val low=case force rep of RepTwo low=>low|Rep1(low,_)=>low|Rep2(low,_,_)=>low
      val Min1Max0(arity,_,_)=force low
   in arity end
 fun strongNormalize domain:domain=D.delay(fn()=>case force domain of Two=>Two
   |Lift1 ds=>Lift1(map strongNormalize ds)|Lift2 ds=>Lift2(map strongNormalize ds)
   |Func(arguments,result)=>(case force result of Func(more,result)=>
       force(strongNormalize(cell(Func(F.append arguments more,result))))
      |_=>Func(map strongNormalize arguments,strongNormalize result)))
 fun meetIrreducibleRoutes domain=F.defer(fn()=>case force domain of Two=>singleton(cell Zero)
   |Lift1 ds=>F.cons(cell Stop1,map(fn routes=>cell(Up1 routes))
       (listVariants(map topRoute ds)(map meetIrreducibleRoutes ds)))
   |Lift2 ds=>F.cons(cell Stop2,F.cons(cell Up2,map(fn routes=>cell(UpUp2 routes))
       (listVariants(map topRoute ds)(map meetIrreducibleRoutes ds))))
   |_=>raise Match)

(* type-domains: portable source translation. *)
 fun typeToDomainExpression groups expression:dexpr=
   let val variables=insertionSort compareTVName(unique equalTVName(typeVariables expression))
       val letters=F.fromList(List.map(fn c=>F.Cons(cell c,F.empty()))(String.explode"abcdefghijklmnopqrstuvwxyz"))
       val env=zip variables letters
       fun convert expression=D.delay(fn()=>case force expression of
          TVar v=>DXVar(sureLookup equalTVName env"tx2dx_aux(1)"v)
         |TArr(a,b)=>DXFunc(singleton(convert a),convert b)
         |TCons(n,args)=>if null args andalso(equalName n(name"int")orelse equalName n(name"char"))
              then DXTwo
            else if isRecursiveType groups n then DXLift2(map convert args)
            else DXLift1(map convert args))
   in if less(int 26)(length variables)then panic"tx2dx"else normalizeDomainExpression(convert expression)end
 fun typedToDomainTree groups tree=mapAnnotation(typeToDomainExpression groups)tree
 fun getDomainInstantiations simplest usage=
   let
     fun get basis usage=F.defer(fn()=>case(force basis,force usage)of
        (DXVar n,_)=>singleton(pair n(defaultDomain usage))
       |(DXTwo,DXTwo)=>F.empty()
       |(DXLift1 xs,DXLift1 ys)=>concat(zipExact get xs ys)
       |(DXLift2 xs,DXLift2 ys)=>concat(zipExact get xs ys)
       |(DXFunc(args,result),DXFunc(others,res))=>
          let val arity=length args val usedArity=length others
              val supplied=F.defer(fn()=>if less arity usedArity then take arity others else others)
              val resultUsage=D.delay(fn()=>force(if less arity usedArity
                then cell(DXFunc(drop arity others,res))else res))
          in F.append(get result resultUsage)(concat(zipExact get args supplied))end
       |_=>raise Match)
     fun consistent acc substitutions=case force substitutions of F.Nil=>acc|F.Cons(entry,rest)=>
        let val(n,domain)=force entry
            fun find acc=case force acc of F.Nil=>NONE|F.Cons(entry,rest)=>
              let val(k,value)=force entry in if equalName k n then SOME value else find rest end
        in case find acc of NONE=>consistent(F.cons(entry,acc))rest
          |SOME other=>if equalDomain domain other then consistent acc rest else panic"txGetInstantiations"end
   in consistent(F.empty())(get simplest usage)end

(* inverse: portable source translation. *)
 fun normalizeInverse maxima minima=
   let val maxima=filter(fn x=>any(fn y=>belowFrel y x)minima)maxima
       val minima=filter(fn x=>any(fn y=>belowFrel x y)maxima)minima
   in(maxima,minima)end
 fun intersectInverse(max1,min1)(max2,min2)=
   let val maxima=maximal belowFrel(flatMap(fn x=>map(meetFrel x)max2)max1)
       val minima=minimal belowFrel(flatMap(fn x=>map(joinFrel x)min2)min1)
   in normalizeInverse maxima minima end
 fun inverseEnumerated arguments function result=
   let val actualArguments=F.defer(fn()=>case force result of Rep resultRep=>
          take(subtract(representationArity function)(representationArity resultRep))arguments|_=>arguments)
       val combinations=cartesianProduct(map allRoutes actualArguments)
   in map(fn args=>cell(MkFrel args))
       (filter(fn args=>equalRoute(applyRoute(cell(Rep function))args)result)combinations)end
 fun inverseMindless domain function result=L.delay(fn()=>case force domain of Func(arguments,_)=>
   let val image=inverseEnumerated arguments function result
   in(maximal belowFrel image,minimal belowFrel image)end|_=>raise Match)
 fun inverseMMI domain function result=L.delay(fn()=>case(force domain,force function,force result)of
    (Func(arguments,_),RepTwo f,Zero)=>let val Min1Max0(_,_,zeros)=force f
       val minima=F.defer(fn()=>if null zeros then F.empty()else singleton(cell(MkFrel(map bottomRoute arguments))))
     in(zeros,minima)end
   |(Func(arguments,target),RepTwo f,One)=>(case force target of Two=>
      let val Min1Max0(_,ones,_)=force f
          val maxima=F.defer(fn()=>if null ones then F.empty()else singleton(cell(MkFrel(map topRoute arguments))))
      in(maxima,ones)end|_=>L.force(inverseMindless domain function result))
   |(Func(arguments,target),Rep1(low,highs),point)=>(case(force target,point)of
      (Lift1 _,Stop1)=>let val Min1Max0(_,_,zeros)=force low
         val minima=F.defer(fn()=>if null zeros then F.empty()else singleton(cell(MkFrel(map bottomRoute arguments))))
        in(zeros,minima)end
     |(Lift1 targets,Up1 routes)=>
        let val Min1Max0(_,ones,_)=force low
            val inverse=if isSingletonList targets andalso isSingletonList highs andalso isSingletonList routes
              then inverseMMI(uncurryDomain arguments(head targets))(head highs)(head routes)
              else L.delay(fn()=>let val domains=map(uncurryDomain arguments)targets
                  val results=zip3Exact(fn d=>fn f=>fn r=>D.delay(fn()=>L.force(inverseMMI d f r)))domains highs routes
                  val combined=foldRight1(fn a=>fn b=>D.delay(fn()=>intersectInverse(force a)(force b)))results
                in force combined end)
            val maxima=F.defer(fn()=> #1(L.force inverse))
            val minima=F.defer(fn()=> #2(L.force inverse))
            val minima=minimal belowFrel(flatMap(fn x=>map(joinFrel x)ones)minima)
        in normalizeInverse maxima minima end
     |_=>L.force(inverseMindless domain function result))
   |(Func(arguments,target),Rep2(low,middle,highs),_) =>(case force target of Lift2 targets=>
       let val isoDomain=cell(Func(arguments,cell(Lift1(singleton(cell(Lift1 targets))))))
           val isoRoute=cell(Rep1(low,singleton(cell(Rep1(middle,highs)))))
           val isoResult=D.delay(fn()=>case force result of Stop2=>Stop1
              |Up2=>Up1(singleton(cell Stop1))|UpUp2 rs=>Up1(singleton(cell(Up1 rs)))|_=>raise Match)
       in L.force(inverseMMI isoDomain isoRoute isoResult)end
       |_=>L.force(inverseMindless domain function result))
   |_=>L.force(inverseMindless domain function result))
 fun minimumInverse mindless domain point result=F.defer(fn()=>case force point of Rep rep=>
     let val answer=if mindless then inverseMindless domain rep result else inverseMMI domain rep result
     in #2(L.force answer)end|_=>raise Match)
 fun maximumInverse mindless domain point result=F.defer(fn()=>case force point of Rep rep=>
     let val answer=if mindless then inverseMindless domain rep result else inverseMMI domain rep result
     in #1(L.force answer)end|_=>raise Match)

(* constructor-functions: portable source translation. *)
 fun maxZeroFromMinOne domains ones=maxZeroFromMinOneAux(map topRoute domains)domains ones
 fun minOneFromMaxZero domains zeros=minOneFromMaxZeroAux(map bottomRoute domains)domains zeros
 fun joinOneFrontiers xs ys=insertionSort compareFrel(foldRight(minimumAdd belowFrel)xs ys)
 fun constructorInstance mindless arguments simplestInitial usage:route=D.delay(fn()=>
   let val isCAF=case force simplestInitial of DXFunc _=>false|_=>true
       val simplest=if isCAF then cell(DXFunc(F.empty(),simplestInitial))else simplestInitial
       val recursive=case force simplest of DXFunc(_,result)=>(case force result of DXLift1 _=>false|DXLift2 _=>true
             |_=>panic"coMakeConstructorInstance:recursive")|_=>panic"coMakeConstructorInstance:recursive"
       val actual=applyDomainSubstitution usage simplest
       val(sources,target)=case force actual of Func(args,result)=>(args,result)|_=>raise Match
       val products=L.delay(fn()=>case(recursive,force target)of
          (true,Lift2 ds)=>ds|(false,Lift1 ds)=>ds
         |(true,Lift1 _)=>panic"cMCI(1)"|(false,Two)=>panic"cMCI(2)"|_=>raise Match)
       val below=case(recursive,force target)of
          (true,Lift2 _)=>F.fromList[Stop2,Up2]
         |(true,Lift1 _)=>let val point=cell(Up1(singleton(cell Zero)))
             in F.cons(cell Stop1,singleton point)end
         |(false,Lift1 _)=>singleton(cell Stop1)|(false,Two)=>singleton(cell Zero)|_=>raise Match
       val above=F.defer(fn()=>case(recursive,force target)of
          (true,Lift2 _)=>map(fn rs=>cell(UpUp2 rs))(cartesianProduct(map allRoutes(L.force products)))
         |(true,Lift1 _)=>let val point=cell(Up1(singleton(cell One)))in singleton point end
         |(false,Lift1 _)=>map(fn rs=>cell(Up1 rs))(cartesianProduct(map allRoutes(L.force products)))
         |(false,Two)=>singleton(cell One)|_=>raise Match)
       fun components point=case force point of UpUp2 rs=>if recursive then rs else raise Match
         |Up1 rs=>if not recursive then rs else raise Match|_=>raise Match
       fun magic point argument=case force argument of ConstrRec=>point
         |ConstrVar n=>nth(components point)n
       val bottoms=singleton(cell(MkFrel(map bottomRoute sources)))
       val table=F.append(map(fn p=>pair p bottoms)below)
         (map(fn p=>pair p(singleton(cell(MkFrel(map(magic p)arguments)))))above)
       val rep=generateConstructor mindless table actual
   in if isCAF then force(constantRepresentation rep)else Rep rep end)
 and generateConstructor mindless table domain:representation=D.delay(fn()=>case force domain of
    Func(arguments,target)=>(case force target of
      Two=>let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(1)"(cell One))
          val zeros=maxZeroFromMinOne arguments ones
          val arity=case force(head(F.append ones zeros))of MkFrel rs=>length rs
        in RepTwo(makeFrontier arity ones zeros)end
     |Lift1 targets=>
        let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(2)"(cell(Up1(map bottomRoute targets))))
            val zeros=maxZeroFromMinOne arguments ones
            val newTable=flatMap(fn entry=>let val(point,values)=force entry
              in case force point of Up1 rs=>singleton(pair rs values)|_=>F.empty()end)table
        in Rep1(makeFrontier(length arguments)ones zeros,generateConstructorCross mindless newTable arguments targets)end
     |Lift2 targets=>
        let val ones=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(2)"(cell Up2))
            val zeros=maxZeroFromMinOne arguments ones
            val middleOnes=insertionSort compareFrel(sureLookup equalRoute table"coCGen_aux(3)"(cell(UpUp2(map bottomRoute targets))))
            val middleZeros=maxZeroFromMinOne arguments middleOnes
            val newTable=flatMap(fn entry=>let val(point,values)=force entry
              in case force point of UpUp2 rs=>singleton(pair rs values)|_=>F.empty()end)table
        in Rep2(makeFrontier(length arguments)ones zeros,makeFrontier(length arguments)middleOnes middleZeros,
              generateConstructorCross mindless newTable arguments targets)end
     |Func(more,result)=>
        let val newTable=map(fn point=>
              let val values=minimal belowFrel(flatMap(fn entry=>let val(g,minimumArgs)=force entry
                    in flatMap(fn x=>let val MkFrel xs=force x
                       in map(fn y=>let val MkFrel ys=force y in cell(MkFrel(F.append xs ys))end)
                         (minimumInverse mindless target g point)end)minimumArgs end)table)
              in pair point values end)(allRoutes result)
        in force(generateConstructor mindless newTable(cell(Func(F.append arguments more,result))))end)
   |_=>raise Match)
 and generateConstructorCross mindless table arguments targets=
   let val dimensions=length targets
       fun dimension n=
         let fun add point values acc=F.defer(fn()=>case force acc of F.Nil=>singleton(pair point(singleton values))
               |F.Cons(entry,rest)=>let val(p,groups)=force entry
                  in if equalRoute point p then F.cons(pair p(F.cons(values,groups)),rest)
                     else F.cons(entry,add point values rest)end)
             fun allRows rows acc=case force rows of F.Nil=>acc|F.Cons(entry,rest)=>
                let val(points,values)=force entry
                in allRows rest(add(nth points n)values acc)end
             val grouped=allRows table(F.empty())
             val fixed=mapSecond(fn values=>foldRight joinOneFrontiers
                 (singleton(cell(MkFrel(map topRoute arguments))))values)grouped
         in generateConstructor mindless fixed(cell(Func(arguments,nth targets n)))end
   in map dimension(intsFromTo(int 0)(subtract dimensions(int 1)))end

(* concretize: portable source translation. *)
 fun uncurryWithRespect small big:domain=D.delay(fn()=>case(force small,force big)of
    (Two,_)=>force big
   |(Lift1 xs,Lift1 ys)=>Lift1(zipExact uncurryWithRespect xs ys)
   |(Lift2 xs,Lift2 ys)=>Lift2(zipExact uncurryWithRespect xs ys)
   |(Func(xs,x),Func(ys,y))=>
      let val smallArity=length xs val bigArity=length ys
          val(fixedArgs,fixedResult)=if equalInt smallArity bigArity then(ys,y)
            else if less smallArity bigArity then(take smallArity ys,cell(Func(drop smallArity ys,y)))
            else panic"acUncurryWRT"
      in Func(zipExact uncurryWithRespect xs fixedArgs,uncurryWithRespect x fixedResult)end
   |_=>raise Match)
 fun compatible big small=case force small of Two=>true|_=>
   (case(force big,force small)of(Lift1 xs,Lift1 ys)=>andWith compatible xs ys
     |(Lift2 xs,Lift2 ys)=>andWith compatible xs ys
     |(Func(xs,x),Func(ys,y))=>compatible x y andalso andWith compatible xs ys|_=>false)
 fun concretize mode big small point:route=D.delay(fn()=>
   if equalDomain big small then force point else
     let val function=case force small of Func _=>true|_=>false
         val normalized=if function then strongNormalize big else big
         val curried=if function then uncurryWithRespect small normalized else big
     in if not(compatible curried small)then panic"acConc: incompatible domains\n\n"
       else if function then case force point of Rep rep=>
          let val source=concretizeSource mode normalized small rep
              val sourceDomain=strongNormalize(concretizedSourceDomain curried small)
              val target=case force curried of Func(_,target)=>target|_=>raise Match
          in Rep(concretizeTarget mode target sourceDomain source)end|_=>raise Match
       else force(concretizeData mode normalized small point)end)
 and concretizeData mode big small point:route=D.delay(fn()=>case(force big,force small,force point)of
    (_,Two,One)=>force(topRoute big)|(_,Two,Zero)=>force(bottomRoute big)
   |(Lift1 _,Lift1 _,Stop1)=>Stop1
   |(Lift1 xs,Lift1 ys,Up1 rs)=>Up1(zip3Exact(concretize mode)xs ys rs)
   |(Lift2 _,Lift2 _,Stop2)=>Stop2|(Lift2 _,Lift2 _,Up2)=>Up2
   |(Lift2 xs,Lift2 ys,UpUp2 rs)=>UpUp2(zip3Exact(concretize mode)xs ys rs)|_=>raise Match)
 and concretizeTarget mode target current rep:representation=D.delay(fn()=>
   let val(arguments,result)=case force current of Func(args,result)=>(args,result)|_=>raise Match
   in case(force target,force result,force rep)of
      (Two,Two,RepTwo _)=>force rep
     |(Lift1 ds,Two,RepTwo f)=>Rep1(f,map(fn d=>concretizeTarget mode d current rep)ds)
     |(Lift2 ds,Two,RepTwo f)=>Rep2(f,f,map(fn d=>concretizeTarget mode d current rep)ds)
     |(Func(more,result),Two,RepTwo f)=>
        let val increase=length more val newDomain=cell(Func(F.append arguments more,cell Two))
            val increased=increaseArityMode mode increase arguments more f
        in force(concretizeTarget mode result newDomain increased)end
     |(Lift1 targets,Lift1 smallerTargets,Rep1(low,highs))=>
        Rep1(low,concretizeTargetHighs mode arguments smallerTargets targets highs)
     |(Lift2 targets,Lift2 smallerTargets,Rep2(low,middle,highs))=>
        Rep2(low,middle,concretizeTargetHighs mode arguments smallerTargets targets highs)
     |_=>raise Match end)
 and concretizeTargetHighs mode arguments smaller larger highs=
   let val smallDomains=map(uncurryDomain arguments)smaller
       val bigDomains=map(uncurryDomain arguments)larger
       fun required small big:domain=D.delay(fn()=>case(force small,force big)of
           (Func(xs,_),Func(ys,result))=>let val extra=drop(length xs)ys
             in if null extra then force result else Func(extra,result)end|_=>raise Match)
       val targets=zipExact required smallDomains bigDomains
   in zip3Exact(concretizeTarget mode)targets smallDomains highs end
 and increaseArityMode mode increase arguments extra frontier:representation=D.delay(fn()=>
   let val finalArguments=F.append arguments extra
       val rep=cell(RepTwo frontier)
       val special=case mode of Safe=>isBottomRepresentation rep|Live=>isTopRepresentation rep
   in if special then force(case mode of Safe=>bottomRepresentation(cell(Func(finalArguments,cell Two)))
         |Live=>topRepresentation(cell(Func(finalArguments,cell Two))))
      else let val points=case mode of Safe=>map bottomRoute extra|Live=>map topRoute extra
               val Min1Max0(arity,ones,zeros)=force frontier
               fun extend value=let val MkFrel rs=force value in cell(MkFrel(F.append rs points))end
               val newOnes=F.defer(fn()=>case mode of Safe=>minOneFromMaxZero finalArguments(map extend zeros)|Live=>map extend ones)
               val newZeros=F.defer(fn()=>case mode of Safe=>map extend zeros|Live=>maxZeroFromMinOne finalArguments(map extend ones))
           in RepTwo(makeFrontier(add arity increase)newOnes newZeros)end end)
 and concretizeSourceFrontier mode bigArgs smallArgs frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier val used=take arity bigArgs
       fun point mode value=let val MkFrel points=force value
         in cell(MkFrel(zip3Exact(concretize mode)used smallArgs points))end
       val newOnes=F.defer(fn()=>case mode of Safe=>minOneFromMaxZero used(map(point Safe)zeros)|Live=>map(point Live)ones)
       val newZeros=F.defer(fn()=>case mode of Safe=>map(point Safe)zeros|Live=>maxZeroFromMinOne used(map(point Live)ones))
   in Min1Max0(arity,newOnes,newZeros)end)
 and concretizeSource mode big small rep:representation=D.delay(fn()=>case(force big,force small,force rep)of
    (Func(bigArgs,_),Func(smallArgs,result),RepTwo f)=>(case force result of
       Two=>RepTwo(concretizeSourceFrontier mode bigArgs smallArgs f)|_=>raise Match)
   |(Func(bigArgs,bigResult),Func(smallArgs,smallResult),Rep1(low,highs))=>
      (case(force bigResult,force smallResult)of(Lift1 bigTargets,Lift1 smallTargets)=>
        let val highDomainsBig=map(uncurryDomain bigArgs)bigTargets
            val highDomainsSmall=map(uncurryDomain smallArgs)smallTargets
        in Rep1(concretizeSourceFrontier mode bigArgs smallArgs low,
             zip3Exact(concretizeSource mode)highDomainsBig highDomainsSmall highs)end|_=>raise Match)
   |(Func(bigArgs,bigResult),Func(smallArgs,smallResult),Rep2(low,middle,highs))=>
      (case(force bigResult,force smallResult)of(Lift2 bigTargets,Lift2 smallTargets)=>
        let val highDomainsBig=map(uncurryDomain bigArgs)bigTargets
            val highDomainsSmall=map(uncurryDomain smallArgs)smallTargets
        in Rep2(concretizeSourceFrontier mode bigArgs smallArgs low,
             concretizeSourceFrontier mode bigArgs smallArgs middle,
             zip3Exact(concretizeSource mode)highDomainsBig highDomainsSmall highs)end|_=>raise Match)
   |_=>raise Match)
 and concretizedSourceDomain big small:domain=D.delay(fn()=>case(force big,force small)of
    (Func(bigArgs,_),Func(_,result))=>(case force result of Two=>Func(bigArgs,cell Two)
      |Lift1 targets=>let
           val smallArgs=case force small of Func(args,_)=>args|_=>raise Match
           val arity=length smallArgs
           val bigDomains=map(uncurryDomain bigArgs)targets
           val smallDomains=map(uncurryDomain smallArgs)targets
           val results=zipExact concretizedSourceDomain bigDomains smallDomains
           fun dropLow domain:domain=D.delay(fn()=>case force domain of Func(args,result)=>
               let val extra=drop arity args in if null extra then force result else Func(extra,result)end|_=>raise Match)
         in Func(bigArgs,cell(Lift1(map dropLow results)))end
      |Lift2 targets=>let val bigTargets=case force big of Func(_,target)=>target|_=>raise Match
           val bigTargets=case force bigTargets of Lift2 ds=>ds|_=>raise Match
           val smallArgs=case force small of Func(args,_)=>args|_=>raise Match
           val result=concretizedSourceDomain(cell(Func(bigArgs,cell(Lift1 bigTargets))))
               (cell(Func(smallArgs,cell(Lift1 targets))))
         in case force result of Func(args,target)=>(case force target of Lift1 ds=>Func(args,cell(Lift2 ds))|_=>raise Match)|_=>raise Match end
      |_=>raise Match)|_=>raise Match)
 fun makeAbstractInstance mode simplest substitution point=
   let val final=strongNormalize(applyDomainSubstitution substitution simplest)
       val basic=defaultDomain simplest
   in concretize mode final basic point end

(* exceptions: portable source translation. *)
 fun addException a b=D.delay(fn()=>let val MkExInt(n,xs)=force a val MkExInt(m,ys)=force b
   in MkExInt(add n m,F.append xs ys)end)
 fun multiplyException a b=D.delay(fn()=>let val MkExInt(n,xs)=force a val MkExInt(m,ys)=force b
   in MkExInt(multiply n m,F.append xs ys)end)

(* lattice-sizes: portable source translation. *)
 val exceptionOne:domainInt=cell(MkExInt(int 1,F.empty()))
 val exceptionTwo:domainInt=cell(MkExInt(int 2,F.empty()))
 fun isTwo value=case force value of Two=>true|_=>false
 fun singletonValue values=case force values of F.Cons(x,rest)=>if null rest then SOME x else NONE|F.Nil=>NONE
 fun normalizeSizeDomain domain:domain=D.delay(fn()=>case force domain of Two=>Two
   |Lift1 ds=>(case singletonValue ds of SOME value=>(case force value of Lift1 values=>Lift2(map normalizeSizeDomain values)
       |_=>Lift1(map normalizeSizeDomain ds))|NONE=>Lift1(map normalizeSizeDomain ds))
   |Lift2 ds=>(case singletonValue ds of SOME value=>(case force value of Lift1 values=>
          let val inner=cell(Lift2(map normalizeSizeDomain values))in Lift1(singleton inner)end
         |_=>Lift2(map normalizeSizeDomain ds))|NONE=>Lift2(map normalizeSizeDomain ds))
   |Func(arguments,result)=>
      let fun fallback()=Func(insertionSort compareDomain(map normalizeSizeDomain arguments),normalizeSizeDomain result)
          val two=cell Two
      in case singletonValue arguments of NONE=>fallback()|SOME argument=>
        case(force argument,force result)of
          (Two,Two)=>Lift1(singleton two)
         |(Lift1 ds,Two)=>if isSingletonList ds andalso isTwo(head ds)then Lift2(singleton two)else fallback()
         |(Lift2 ds,Two)=>if isSingletonList ds andalso isTwo(head ds)then
              let val inner=cell(Lift2(singleton two))in Lift1(singleton inner)end else fallback()
         |(Two,Lift1 ds)=>if isSingletonList ds andalso isTwo(head ds)then Func(F.fromList[Two,Two],two)else fallback()
         |(Two,Lift2 ds)=>if isSingletonList ds andalso isTwo(head ds)then
              let val inner=cell(Lift1(singleton two))in Func(singleton inner,inner)end else fallback()
         |_=>fallback()
      end)
 fun latticeCardinality table domain:domainInt=D.delay(fn()=>case force domain of
    Two=>force exceptionTwo
   |Lift1 ds=>force(addException exceptionOne(foldLeft multiplyException exceptionOne(map(latticeCardinality table)ds)))
   |Lift2 ds=>force(addException exceptionTwo(foldLeft multiplyException exceptionOne(map(latticeCardinality table)ds)))
   |Func(arguments,result)=>
      let fun fix x=let val y=normalizeSizeDomain x in if equalDomain x y then x else fix y end
          val normalized=fix(cell(Func(arguments,result)))
          fun lookup rows=case force rows of F.Nil=>MkExInt(int 0,singleton normalized)
            |F.Cons(entry,rest)=>let val(d,n)=force entry
              in if equalDomain d normalized then MkExInt(n,F.empty())else lookup rest end
      in case force normalized of Func _=>lookup table|_=>force(latticeCardinality table normalized)end)
 fun reduceDomain domain=F.defer(fn()=>case force domain of
    Two=>F.empty()
   |Lift1 ds=>let val alternatives=zipExact(fn d=>fn choices=>F.cons(d,choices))ds(map reduceDomain ds)
      in F.append(map(fn reduced=>cell(Lift1 reduced))(tail(cartesianProduct alternatives)))(singleton(cell Two))end
   |Lift2 ds=>let val alternatives=zipExact(fn d=>fn choices=>F.cons(d,choices))ds(map reduceDomain ds)
      in F.append(map(fn reduced=>cell(Lift2 reduced))(tail(cartesianProduct alternatives)))(singleton(cell Two))end
   |Func(arguments,result)=>
      let val argReductions=map reduceDomain arguments
          val resultReduced=reduceDomain result
          val originals=F.cons(result,arguments)
          val reduced=F.cons(resultReduced,argReductions)
          val choices=zipExact(fn d=>fn variants=>F.cons(d,variants))originals reduced
          val variants=tail(cartesianProduct choices)
          val functions=map(fn values=>cell(Func(tail values,head values)))variants
      in F.append functions(singleton(cell Two))end)

(* size-sequence: portable source translation. *)

 fun recoverRelation equal leq values=
   let fun insert value others=F.defer(fn()=>if any(fn other=>leq other value)others then others
         else F.cons(value,filter(fn other=>not(leq value other))others))
       fun above value=foldRight insert(F.empty())
           (filter(fn other=>leq value other andalso not(equal value other))values)
   in map(fn value=>pair value(above value))values end
 fun shortestPath equal roads start finish=
   let fun aux considered=F.defer(fn()=>if null considered then panic"Dijkstra failed"else
         let fun minimum left right=let val(_,a,_)=force left val(_,b,_)=force right
               in if less a b then left else right end
             val bestEntry=foldLeft minimum(head considered)(tail considered)
             val(best,cost,_)=force bestEntry
             val outgoing=map(fn road=>let val(_,target,localCost)=force road
                 in triple target(add localCost cost)best end)
                 (filter(fn road=>let val(source,_,_)=force road in equal source best end)roads)
             val without=filter(fn entry=>let val(place,_,_)=force entry in not(equal place best)end)considered
             fun update entry old=F.defer(fn()=>case force old of F.Nil=>singleton entry
               |F.Cons(current,rest)=>let val(place,newCost,back)=force entry
                    val(other,oldCost,oldBack)=force current
                 in if not(equal place other)then F.cons(current,update entry rest)
                    else if leq oldCost newCost then old else F.cons(triple other newCost back,rest)end)
             fun updateAll old new=F.defer(fn()=>case force new of F.Nil=>old
               |F.Cons(entry,rest)=>updateAll(update entry old)rest)
         in if equal best finish then singleton bestEntry
            else F.cons(bestEntry,aux(updateAll without outgoing))end)
       val costs=aux(singleton(triple start(int 0)start))
       fun unlink here=F.defer(fn()=>
         let val entry=head(filter(fn entry=>let val(place,_,_)=force entry in equal place here end)costs)
             val(place,cost,back)=force entry
         in if equal start here then singleton(pair start(int 0))
            else F.cons(pair place cost,unlink back)end)
   in reverse(unlink finish)end
 fun oneSizeSequence table scale domains=
   let val crossed=cell(Lift1 domains)
       val candidates=F.cons(crossed,init(reduceDomain crossed))
       val counted=map(fn d=>pair d(latticeCardinality table d))candidates
       fun collect values=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
         |F.Cons(entry,rest)=>let val(d,size)=force entry val MkExInt(n,missing)=force size
              val future=collect rest
              val errors=F.defer(fn()=>F.append missing(#1(L.force future)))
              val sizes=F.cons(pair d(subtract n(int 1)),F.defer(fn()=> #2(L.force future)))
           in(errors,sizes)end)
       val allSizes=collect counted
       val sizes=F.defer(fn()=>let val(errors,sizes)=L.force allSizes
         in if null errors then sizes
            else panic"slMakeOneSequence: no size for domain"end)
       fun equal x y=let val(d,n)=force x val(e,m)=force y
         in equalDomain d e andalso equalInt n m end
       fun leq x y=let val(d,_)=force x val(e,_)=force y in compatible e d end
       val above=recoverRelation equal leq sizes
       val edges=flatMap(fn entry=>let val(from,targets)=force entry
         in map(fn target=>pair from target)targets end)above
       fun absolute value=if less value(int 0)then negative value else value
       val costed=map(fn edge=>let val(from,target)=force edge
            val(_,n)=force from val(_,m)=force target
            val difference=subtract(divide(multiply m(int 10))n)scale
            val factor=divide m(int 10)
         in triple from target(multiply factor(absolute difference))end)edges
   in shortestPath equal costed(last sizes)(head sizes)end
 fun transpose values=F.defer(fn()=>if null values then F.empty()else
   let val rows=filter(fn row=>not(null row))values
   in if null rows then F.empty()else F.cons(map head rows,transpose(map tail rows))end)
 fun takeWhile predicate values=F.defer(fn()=>case force values of F.Nil=>F.empty()
   |F.Cons(x,rest)=>if predicate x then F.cons(x,takeWhile predicate rest)else F.empty())
 fun sizeSequence table scale groups low high=L.delay(fn()=>
   let fun clean value=let val(sized,_)=force value val(domain,size)=force sized
         in case force domain of Lift1 domains=>pair size domains|_=>raise Match end
       val initial=map(fn domains=>reverse(map clean(oneSizeSequence table scale domains)))groups
       fun minimum a b=if less a b then a else b
       fun maximum a b=if less a b then b else a
       val limit=foldLeft minimum(length(head initial))(map length(tail initial))
       val equalLengths=map(fn values=>reverse(take limit values))initial
       val together=transpose equalLengths
       val maxima=map(fn values=>
           let val numbers=map(fn value=> #1(force value))values
           in foldLeft maximum(head numbers)(tail numbers)end)together
       val lowDrop=minimum(length(takeWhile(fn n=>less n low)maxima))(subtract limit(int 1))
       val limit2=subtract limit lowDrop
       val adjusted=drop lowDrop together
       val maxima2=reverse(drop lowDrop maxima)
       val highDrop=minimum(length(takeWhile(fn n=>less high n)maxima2))(subtract limit2(int 1))
       val used=subtract limit2 highDrop
   in(take used adjusted,drop used adjusted)end)

(* frontier-misc: portable source translation. *)
 fun splitBy predicate values=L.delay(fn()=>case force values of F.Nil=>(F.empty(),F.empty())
   |F.Cons(x,rest)=>let val(yes,no)=L.force(splitBy predicate rest)
     in if predicate x then(F.cons(x,yes),no)else(yes,F.cons(x,no))end)
 fun combineBounds upper lower:representation=D.delay(fn()=>case(force upper,force lower)of
    (RepTwo x,RepTwo y)=>RepTwo(combineFrontierBounds x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(combineFrontierBounds x y,zipExact combineBounds xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(combineFrontierBounds x y,combineFrontierBounds z w,zipExact combineBounds xs ys)
   |_=>raise Match)
 and combineFrontierBounds upper lower:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force upper val Min1Max0(_,ones,_)=force lower
   in Min1Max0(arity,ones,zeros)end)
 fun selectFrontier random upSpace downSpace fromTop=
   let
     fun inner mi values rest=C.defer(fn()=>case force values of F.Nil=>rest()
       |F.Cons(ma,tail)=>if belowFrel mi ma then
          C.cons(L.delay(fn()=>pair mi ma),inner mi tail rest)else inner mi tail rest)
     fun outer values=C.defer(fn()=>case force values of F.Nil=>C.empty()
       |F.Cons(mi,tail)=>inner mi downSpace(fn()=>outer tail))
     val pairs=fromControl(C.take 30(outer upSpace))
   in if null pairs then NONE else
     let val index=modulo random(length pairs)val(mi,ma)=force(nth pairs index)
     in SOME(if fromTop then ma else mi)end end
 fun frontierMaximumIntersection xs ys=maximal belowFrel(flatMap(fn x=>map(meetFrel x)ys)xs)
 fun frontierMinimumIntersection xs ys=minimal belowFrel(flatMap(fn x=>map(joinFrel x)ys)xs)
 fun reviseMinimum domains minimum point=
   let val partition=splitBy(fn x=>belowFrel x point)minimum
       val(underneath,others)=L.force partition
       val changed=frontierMinimumIntersection underneath(successorFrels domains point)
   in if less(length changed)(length others)then foldRight(minimumAdd belowFrel)changed others
      else foldRight(minimumAdd belowFrel)others changed end
 fun reviseMaximum domains maximum point=
   let val(above,others)=L.force(splitBy(fn y=>belowFrel point y)maximum)
       val changed=frontierMaximumIntersection above(predecessorFrels domains point)
   in if less(length changed)(length others)then foldRight(maximumAdd belowFrel)others changed
      else foldRight(maximumAdd belowFrel)changed others end
 val randomModulus1=cell(0w2147483563:W.word)
 val randomModulus2=cell(0w2147483399:W.word)
 val randomLimit1=cell(0w2147483562:W.word)
 val randomLimit2=cell(0w2147483398:W.word)
 fun randomIntegers seed1 seed2=
   let fun rands a b=C.defer(fn()=>
         let val k=divide a(int 53668)
             val nextA=subtract(multiply(int 40014)(subtract a(multiply k(int 53668))))(multiply k(int 12211))
             val a=D.delay(fn()=>force(if less nextA(int 0)then add nextA randomModulus1 else nextA))
             val k=divide b(int 52774)
             val nextB=subtract(multiply(int 40692)(subtract b(multiply k(int 52774))))(multiply k(int 3791))
             val b=D.delay(fn()=>force(if less nextB(int 0)then add nextB randomModulus2 else nextB))
             val z=subtract a b
             val result=if less z(int 1)then add z randomLimit1 else z
         in C.cons(L.delay(fn()=>result),C.defer(fn()=>rands a b))end)
   in if leq(int 1)seed1 andalso leq seed1 randomLimit1 andalso leq(int 1)seed2 andalso leq seed2 randomLimit2
       then rands seed1 seed2 else panic"utRandomInts: bad seeds"end

(* frontier-data: portable source translation. *)

 type memo=(routeNode F.seq*route)F.seq
 fun dataIsZero point=case force point of Zero=>true|One=>false|_=>raise Match
 fun dataLow1 point:route=D.delay(fn()=>case force point of Stop1=>Zero|Up1 _=>One|_=>raise Match)
 fun dataLow2 point:route=D.delay(fn()=>case force point of Stop2=>Zero|Up2=>One|UpUp2 _=>One|_=>raise Match)
 fun dataMiddle2 point:route=D.delay(fn()=>case force point of Stop2=>Zero|Up2=>Zero|UpUp2 _=>One|_=>raise Match)
 fun dataHigh1 bottom n point:route=D.delay(fn()=>case force point of Stop1=>force bottom|Up1 rs=>force(nth rs n)|_=>raise Match)
 fun dataHigh2 bottom n point:route=D.delay(fn()=>case force point of Stop2=>force bottom|Up2=>force bottom
   |UpUp2 rs=>force(nth rs n)|_=>raise Match)
 fun improveData coerce memo domains naive maxZero minOne=L.delay(fn()=>
   let val(zeros,ones)=L.force(splitBy(fn entry=>let val(_,result)=force entry in dataIsZero(coerce result)end)memo)
       val zeroMaximum=maximal belowFrel(map(fn entry=>let val(args,_)=force entry in cell(MkFrel args)end)zeros)
       val oneMinimum=minimal belowFrel(map(fn entry=>let val(args,_)=force entry in cell(MkFrel args)end)ones)
       val zeroBase=if naive then singleton(cell(MkFrel(map topRoute domains)))else maxZero
       val oneBase=if naive then singleton(cell(MkFrel(map bottomRoute domains)))else minOne
       val newZero=insertionSort compareFrel(frontierMaximumIntersection zeroBase(maxZeroFromMinOne domains oneMinimum))
       val newOne=insertionSort compareFrel(frontierMinimumIntersection oneBase(minOneFromMaxZero domains zeroMaximum))
   in(newZero,newOne)end)
 fun searchData mode expression small big previousOne previousZero coerce=L.delay(fn()=>
   let fun loop trialZero trialOne fromTop memo randoms=L.delay(fn()=>
         let val random=L.force(headControl randoms)
         in case selectFrontier random trialOne trialZero fromTop of
           NONE=>(insertionSort compareFrel trialZero,insertionSort compareFrel trialOne,memo)
          |SOME chosen=>
            let val MkFrel args=force chosen
                val proper=zip3Exact(concretize mode)big small args
                val evaluated=evaluateExact expression(map(fn point=>cell(HPoint point))proper)
                val result=coerce evaluated
                val newMemo=F.cons(pair args evaluated,memo)
                val next=tailControl randoms
            in case force result of
                One=>L.force(loop(reviseMaximum small trialZero chosen)trialOne false newMemo next)
               |Zero=>L.force(loop trialZero(reviseMinimum small trialOne chosen)true newMemo next)
               |_=>panic"fdFs_aux"end end)
       val result=loop previousZero previousOne true(F.empty())(randomIntegers(int 1)(int 2))
       val(zero,one,memo)=L.force result
   in(makeFrontier(length small)one zero,memo)end)
 and headControl values=case L.force values of C.Nil=>raise Empty|C.Cons(x,_)=>x
 and tailControl values=C.defer(fn()=>case L.force values of C.Nil=>raise Empty|C.Cons(_,rest)=>rest)
 fun findData mode expression domain small big previous coerce naive inherited memo=L.delay(fn()=>
   let val(_,target)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       fun low previous coerce memo=L.delay(fn()=>
         let val Min1Max0(_,ones,zeros)=force previous
             val(betterZero,betterOne)=L.force(improveData coerce memo small naive zeros ones)
         in L.force(searchData mode expression small big betterOne betterZero coerce)end)
   in case(force target,force previous)of
       (Two,RepTwo frontier)=>let val(result,more)=L.force(low frontier coerce memo)
          in(cell(RepTwo result),more)end
      |(Lift1 targets,Rep1(frontier,highs))=>
         let fun lowCoerce x=dataLow1(coerce x)
             val(lo,more)=L.force(low frontier lowCoerce memo)
             val useful=filter(fn entry=>let val(_,result)=force entry in not(dataIsZero(lowCoerce result))end)(F.append more memo)
             val Min1Max0(_,ones,_)=force lo
             val(newHighs,highMemo)=L.force(findDataHigh mode expression small big targets highs coerce useful false(fn()=>ones)naive)
         in(cell(Rep1(lo,newHighs)),F.append more highMemo)end
      |(Lift2 targets,Rep2(frontier,middle,highs))=>
         let fun lowCoerce x=dataLow2(coerce x)
             val(lo,more)=L.force(low frontier lowCoerce memo)
             val useful=filter(fn entry=>let val(_,result)=force entry in not(dataIsZero(lowCoerce result))end)(F.append more memo)
             fun middleCoerce x=dataMiddle2(coerce x)
             val(mid,middleMore)=L.force(low middle middleCoerce useful)
             val usefulMiddle=filter(fn entry=>let val(_,result)=force entry
               in not(dataIsZero(middleCoerce result))end)(F.append middleMore useful)
             val Min1Max0(_,ones,_)=force mid
             val(newHighs,highMemo)=L.force(findDataHigh mode expression small big targets highs coerce usefulMiddle true(fn()=>ones)naive)
         in(cell(Rep2(lo,mid,newHighs)),F.append more(F.append middleMore highMemo))end
      |_=>raise Match end)
 and findDataHigh mode expression small big targets previous coerce initial double inherited naive=L.delay(fn()=>
   let val domains=map(uncurryDomain small)targets
       val indices=intsFromTo(int 0)(subtract(length targets)(int 1))
       val first=zip3Exact(fn index=>fn rep=>fn bottom=>triple index rep bottom)indices previous(map bottomRoute targets)
       val tuples=zipExact(fn first=>fn domain=>let val(n,rep,bottom)=force first
          in cell(domain,n,rep,bottom)end)first domains
       fun one added tuple=
         let val(domain,n,previous,bottom)=force tuple
             fun high point=if double then dataHigh2 bottom n(coerce point)else dataHigh1 bottom n(coerce point)
             val result=findData mode expression domain small big previous high naive inherited(F.append added initial)
             val more=F.defer(fn()=> #2(L.force result))
             val rep=D.delay(fn()=>force(#1(L.force result)))
         in(F.append more added,rep)end
       val(result,highs)=L.force(mapAccumulate one(F.empty())tuples)
   in(highs,result)end)

(* frontier-generic: portable source translation. *)

 fun evaluateSearchConstant expression arguments:route=D.delay(fn()=>case force expression of
    HLam _=>force(evaluateExact expression arguments)
   |HPoint point=>if null arguments then force point else force(evaluateConstant(cell(HVAp(expression,arguments))))
   |_=>raise Match)
 fun applySearch info arguments expression:route=D.delay(fn()=>case force info of F.Nil=>raise Match
   |F.Cons(entry,rest)=>(case force entry of
       A2=>if null rest then force(evaluateSearchConstant expression arguments)else raise Match
      |ALo1=>if null rest then force(dataLow1(evaluateSearchConstant expression arguments))else raise Match
      |ALo2=>if null rest then force(dataLow2(evaluateSearchConstant expression arguments))else raise Match
      |AMid2=>if null rest then force(dataMiddle2(evaluateSearchConstant expression arguments))else raise Match
      |AHi1(n,index,target)=>
        let val result=evaluateSearchConstant expression(take n arguments)
            val high=dataHigh1(bottomRoute target)index result
        in force(applySearch rest(drop n arguments)(cell(HPoint high)))end
      |AHi2(n,index,target)=>
        let val result=evaluateSearchConstant expression(take n arguments)
            val high=dataHigh2(bottomRoute target)index result
        in force(applySearch rest(drop n arguments)(cell(HPoint high)))end))
 fun searchGeneric mode expression small big bounds info naive:frontier=D.delay(fn()=>
   let val Min1Max0(_,ones,zeros)=force bounds
       val initialZero=if naive then singleton(cell(MkFrel(map topRoute small)))else zeros
       val initialOne=if naive then singleton(cell(MkFrel(map bottomRoute small)))else ones
       fun makeBigger routes small big=F.defer(fn()=>case(force small,force big)of(F.Nil,F.Nil)=>routes
         |(F.Cons(s,ss),F.Cons(b,bs))=>(case force routes of F.Cons(r,rs)=>
              F.cons(concretize mode b s r,makeBigger rs ss bs)|_=>raise Match)
         |_=>raise Match)
       fun loop trialZero trialOne fromTop randoms=L.delay(fn()=>
         case selectFrontier(L.force(headControl randoms))trialOne trialZero fromTop of
           NONE=>(insertionSort compareFrel trialZero,insertionSort compareFrel trialOne)
          |SOME chosen=>
            let val MkFrel args=force chosen
                val proper=makeBigger args small big
                val evaluated=applySearch info(map(fn point=>cell(HPoint point))proper)expression
                val next=tailControl randoms
            in case force evaluated of
                One=>L.force(loop(reviseMaximum small trialZero chosen)trialOne false next)
               |Zero=>L.force(loop trialZero(reviseMinimum small trialOne chosen)true next)
               |_=>panic"fsFs_aux"end)
       val(finalZero,finalOne)=L.force(loop initialZero initialOne true(randomIntegers(int 1)(int 2)))
   in Min1Max0(length small,finalOne,finalZero)end)
 fun findGeneric mode expression domain small big bounds n info naive:representation=D.delay(fn()=>
   let val(arguments,target)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       fun high targets previous double=
         let val domains=map(uncurryDomain arguments)targets
             val arity=length arguments
             val indices=intsFromTo(int 0)(subtract(length targets)(int 1))
             val entries=zip3Exact(fn d=>fn target=>fn previous=>triple d target previous)domains targets previous
         in zipExact(fn entry=>fn index=>let val(d,target,previous)=force entry
               val step=cell(if double then AHi2(arity,index,target)else AHi1(arity,index,target))
            in findGeneric mode expression d small big previous arity(F.append info(singleton step))naive end)entries indices end
   in case(force target,force bounds)of
       (Two,RepTwo frontier)=>RepTwo(searchGeneric mode expression small big frontier(F.append info(singleton(cell A2)))naive)
      |(Lift1 targets,Rep1(frontier,previous))=>
          Rep1(searchGeneric mode expression small big frontier(F.append info(singleton(cell ALo1)))naive,
            high targets previous false)
      |(Lift2 targets,Rep2(frontier,middle,previous))=>
          Rep2(searchGeneric mode expression small big frontier(F.append info(singleton(cell ALo2)))naive,
            searchGeneric mode expression small big middle(F.append info(singleton(cell AMid2)))naive,
            high targets previous true)
      |_=>raise Match end)
 fun makeFrontierRepresentation mode naive expression domain big lower upper=L.delay(fn()=>
   let val caf=case force domain of Func(args,_)=>null args|_=>true
   in if caf then
       let val result=evaluateConstant expression
           val normalized=D.delay(fn()=>case force result of Rep rep=>force(constantRepresentation rep)|_=>force result)
       in(normalized,int 0)end
      else
       let val small=case force domain of Func(args,_)=>args|_=>raise Match
           val upper=case force upper of Rep rep=>rep|_=>raise Match
           val lower=case force lower of Rep rep=>rep|_=>raise Match
           val bounds=combineBounds upper lower
       in if isDataFunction domain then
          let val result=findData mode expression domain small big bounds(fn x=>x)naive
               (fn()=>panic"no inherited min1")(F.empty())
              val route=D.delay(fn()=>Rep(#1(L.force result)))
              val count=D.delay(fn()=>force(length(#2(L.force result))))
          in(route,count)end
          else(cell(Rep(findGeneric mode expression domain small big bounds(int 0)(F.empty())naive)),int ~1)
       end end)

(* baraki-meet: portable source translation. *)

 fun barakiBelow left right=case force left of
    Zero=>true|One=>(case force right of One=>true|Zero=>false|_=>raise Match)
   |Stop1=>true|Up1 xs=>(case force right of Up1 ys=>andWith barakiBelow xs ys|_=>false)
   |Stop2=>true|Up2=>(case force right of Stop2=>false|_=>true)
   |UpUp2 xs=>(case force right of UpUp2 ys=>andWith barakiBelow xs ys|_=>false)
   |Rep x=>(case force right of Rep y=>barakiBelowRepresentation x y|_=>raise Match)
 and barakiBelowRepresentation left right=case(force left,force right)of
    (RepTwo x,RepTwo y)=>barakiBelowFrontier x y
   |(Rep1(x,xs),Rep1(y,ys))=>barakiBelowFrontier x y andalso andWith barakiBelowRepresentation xs ys
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>barakiBelowFrontier x y andalso barakiBelowFrontier z w
        andalso andWith barakiBelowRepresentation xs ys
   |_=>raise Match
 and barakiBelowFrontier left right=
   let val Min1Max0(_,_,xs)=force left val Min1Max0(_,_,ys)=force right
   in all(fn y=>any(fn x=>barakiBelowFrel y x)xs)ys end
 and barakiBelowFrel left right=
   let val MkFrel xs=force left val MkFrel ys=force right in andWith barakiBelow xs ys end
 fun barakiMaximumAdd x others=F.defer(fn()=>if any(barakiBelowFrel x)others then others
    else F.cons(x,filter(fn y=>not(barakiBelowFrel y x))others))
 fun barakiMeetFrontier left right:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force left val Min1Max0(_,_,others)=force right
   in Min1Max0(arity,F.empty(),foldRight barakiMaximumAdd zeros others)end)
 fun barakiMeetRepresentation left right:representation=D.delay(fn()=>case(force left,force right)of
    (RepTwo x,RepTwo y)=>RepTwo(barakiMeetFrontier x y)
   |(Rep1(x,xs),Rep1(y,ys))=>Rep1(barakiMeetFrontier x y,zipExact barakiMeetRepresentation xs ys)
   |(Rep2(x,z,xs),Rep2(y,w,ys))=>Rep2(barakiMeetFrontier x y,barakiMeetFrontier z w,zipExact barakiMeetRepresentation xs ys)
   |_=>raise Match)
 fun barakiMeet left right:route=D.delay(fn()=>case(force left,force right)of
    (Rep x,Rep y)=>Rep(barakiMeetRepresentation x y)|_=>raise Match)
 fun normalizeBaraki domain point:route=D.delay(fn()=>case(force domain,force point)of
    (Two,_)=>force point|(Lift1 _,Stop1)=>force point
   |(Lift1 ds,Up1 rs)=>Up1(zipExact normalizeBaraki ds rs)
   |(Lift2 _,Stop2)=>force point|(Lift2 _,Up2)=>force point
   |(Lift2 ds,UpUp2 rs)=>UpUp2(zipExact normalizeBaraki ds rs)
   |(_,Rep rep)=>Rep(normalizeBarakiRepresentation domain rep)|_=>raise Match)
 and normalizeBarakiRepresentation domain rep:representation=D.delay(fn()=>case(force domain,force rep)of
    (Func(args,result),RepTwo f)=>(case force result of Two=>RepTwo(normalizeBarakiFrontier args f)|_=>raise Match)
   |(Func(args,result),Rep1(f,highs))=>(case force result of Lift1 targets=>
        Rep1(normalizeBarakiFrontier args f,zipExact normalizeBarakiRepresentation(map(uncurryDomain args)targets)highs)|_=>raise Match)
   |(Func(args,result),Rep2(f,m,highs))=>(case force result of Lift2 targets=>
        Rep2(normalizeBarakiFrontier args f,normalizeBarakiFrontier args m,
          zipExact normalizeBarakiRepresentation(map(uncurryDomain args)targets)highs)|_=>raise Match)
   |_=>raise Match)
 and normalizeBarakiFrontier arguments frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force frontier
       fun norm value=let val MkFrel routes=force value in cell(MkFrel(zipExact normalizeBaraki arguments routes))end
       val normalized=insertionSort compareFrel(map norm zeros)
       (* The original deliberately computes min1 from the OLD max0. *)
       val ones=minOneFromMaxZero arguments zeros
   in Min1Max0(arity,ones,normalized)end)

(* baraki-concretize: portable source translation. *)

 type embeddingSubstitution=(name*(domain*route*route)D.t)F.seq
 fun embeddingDomain rho expression:domain=D.delay(fn()=>case force expression of
    DXTwo=>Two|DXLift1 xs=>Lift1(map(embeddingDomain rho)xs)
   |DXLift2 xs=>Lift2(map(embeddingDomain rho)xs)
   |DXFunc(xs,x)=>Func(map(embeddingDomain rho)xs,embeddingDomain rho x)
   |DXVar n=>let val(d,_,_)=force(sureLookup equalName rho"bcEApp_d"n)in force d end)
 fun applyEmbedding rho expression point:route=D.delay(fn()=>case(force expression,force point)of
    (DXTwo,Zero)=>Zero|(DXTwo,One)=>One|(DXLift1 _,Stop1)=>Stop1
   |(DXLift1 xs,Up1 rs)=>Up1(zipExact(applyEmbedding rho)xs rs)
   |(DXLift2 _,Stop2)=>Stop2|(DXLift2 _,Up2)=>Up2
   |(DXLift2 xs,UpUp2 rs)=>UpUp2(zipExact(applyEmbedding rho)xs rs)
   |(DXVar n,Zero)=>let val(_,r,_)=force(sureLookup equalName rho"bcEApp(1)"n)in force r end
   |(DXVar n,One)=>let val(_,_,t)=force(sureLookup equalName rho"bcEApp(2)"n)in force t end
   |(DXFunc(args,result),Rep rep)=>force(composeEmbeddingFunctionClosure rho result(defaultDomain expression)rep args)
   |_=>raise Match)
 and composeEmbeddingFunction rho target domain rep:representation=D.delay(fn()=>
   case(force target,force domain,force rep)of
      (DXTwo,Func(_,result),RepTwo _)=>(case force result of Two=>force rep|_=>raise Match)
     |(DXLift1 targets,Func(args,result),Rep1(low,highs))=>(case force result of Lift1 ds=>
         Rep1(low,zip3Exact(composeEmbeddingFunction rho)targets(map(uncurryDomain args)ds)highs)|_=>raise Match)
     |(DXLift2 targets,Func(args,result),Rep2(low,middle,highs))=>(case force result of Lift2 ds=>
         Rep2(low,middle,zip3Exact(composeEmbeddingFunction rho)targets(map(uncurryDomain args)ds)highs)|_=>raise Match)
     |(DXVar n,Func(args,result),RepTwo f)=>
       let val _=case force result of Two=>()|_=>raise Match
           val top=topFrontier args
           val topRep=cell(RepTwo top)
           fun base domain:representation=D.delay(fn()=>case force domain of
                Two=>force rep|Lift1 ds=>Rep1(f,map base ds)|Lift2 ds=>Rep2(f,f,map base ds)|_=>raise Match)
           fun value domain point:representation=D.delay(fn()=>case(force domain,force point)of
                (Two,Zero)=>force rep|(Two,One)=>force topRep
               |(Lift1 ds,Stop1)=>Rep1(f,map base ds)
               |(Lift1 ds,Up1 rs)=>Rep1(top,zipExact value ds rs)
               |(Lift2 ds,Stop2)=>Rep2(f,f,map base ds)
               |(Lift2 ds,Up2)=>Rep2(top,f,map base ds)
               |(Lift2 ds,UpUp2 rs)=>Rep2(top,top,zipExact value ds rs)|_=>raise Match)
           val(d,r,_)=force(sureLookup equalName rho"bcEdotF"n)
       in force(value d r)end
     |_=>raise Match)
 and mapBarakiZeros function arguments rep:representation=D.delay(fn()=>case force rep of
    RepTwo f=>RepTwo(mapBarakiZeroFrontier function arguments f)
   |Rep1(f,highs)=>Rep1(mapBarakiZeroFrontier function arguments f,map(mapBarakiZeros function arguments)highs)
   |Rep2(f,m,highs)=>Rep2(mapBarakiZeroFrontier function arguments f,mapBarakiZeroFrontier function arguments m,
        map(mapBarakiZeros function arguments)highs))
 and mapBarakiZeroFrontier function arguments frontier:frontier=D.delay(fn()=>
   let val Min1Max0(arity,_,zeros)=force frontier in Min1Max0(arity,F.empty(),map function zeros)end)
 and composeEmbeddingFunctionClosure rho target domain rep closures:route=D.delay(fn()=>
   let val(_,result)=case force domain of Func(args,target)=>(args,target)|_=>raise Match
       val newArgs=map(embeddingDomain rho)closures
       fun apply value=let val MkFrel routes=force value
         in cell(MkFrel(zipExact(applyEmbedding rho)closures routes))end
       val functionClosure=mapBarakiZeros apply newArgs rep
       val finalDomain=cell(Func(newArgs,result))
   in Rep(composeEmbeddingFunction rho target finalDomain functionClosure)end)
 fun cleanDomainExpression expression:dexpr=D.delay(fn()=>case force expression of
    DXTwo=>DXTwo|DXVar _=>force expression
   |DXLift1 xs=>if null xs then DXTwo else DXLift1(map cleanDomainExpression xs)
   |DXLift2 xs=>if null xs then DXLift1(singleton(cell DXTwo))else DXLift2(map cleanDomainExpression xs)
   |DXFunc(args,result)=>DXFunc(map cleanDomainExpression args,cleanDomainExpression result))
 fun makePolymorphicInstance useBaraki threshold mode dirty rho point:route=D.delay(fn()=>
   case(force dirty,force point)of(DXFunc _,Rep rep)=>
     let val simplest=cleanDomainExpression dirty
         val(args,target)=case force simplest of DXFunc(args,result)=>(args,result)|_=>raise Match
         val domains=map(fn entry=> #2(force entry))rho
         val base=all(fn d=>case force d of Two=>true|_=>false)domains
         val applicable=all(fn d=>not(containsFunctions d))domains andalso not(expressionContainsFunctions target)
             andalso all(fn d=>not(expressionContainsSubsidiaryFunctions d))args
         val optimize=all(fn d=>not(expressionContainsFunctions d))args
         fun baraki()=
           let
         val limit=if less threshold(int 1)then int 1 else threshold
         (* The finite strict variant must not construct the unused tail
            of the Cartesian product beyond the original take limit. *)
         fun controlFlatMap function values=C.defer(fn()=>case L.force values of C.Nil=>C.empty()
            |C.Cons(x,rest)=>C.append(function x)(controlFlatMap function rest))
         fun controlProduct xss=C.defer(fn()=>case force xss of F.Nil=>C.cons(L.delay(fn()=>F.empty()),C.empty())
           |F.Cons(xs,rest)=>controlFlatMap(fn suffix=>
               let fun loop values=C.defer(fn()=>case force values of F.Nil=>C.empty()
                    |F.Cons(x,xt)=>C.cons(L.delay(fn()=>F.cons(x,L.force suffix)),loop xt))
               in loop xs end)(controlProduct rest))
         val indices=map(fn d=>if optimize then meetIrreducibleRoutes d else allRoutesMinusTop d)domains
         val choices=fromControl(C.take(Int.max(1,small limit))(controlProduct indices))
         val tops=map topRoute domains
         val names=map(fn entry=> #1(force entry))rho
         val dsAndTops=zipExact pair domains tops
         fun substitution routes=zip3Exact(fn n=>fn info=>fn r=>
           let val(d,t)=force info in pair n(triple d r t)end)names dsAndTops routes
         val substitutions=map substitution choices
         val simpleDomain=defaultDomain simplest
         val compositions=map(fn rho=>composeEmbeddingFunctionClosure rho target simpleDomain rep args)substitutions
         val meet=foldLeft barakiMeet(head compositions)(tail compositions)

           in normalizeBaraki(applyDomainSubstitution rho simplest)meet end
     in if base then force point
        else if not useBaraki orelse not applicable then force(makeAbstractInstance mode simplest rho point)
        else force(baraki())end
    |_=>force(makeAbstractInstance mode dirty rho point))

(* simplify: portable source translation. *)

 fun equalAbstract left right=case(force left,force right)of
    (HVar a,HVar b)=>equalName a b|(HPoint a,HPoint b)=>equalRoute a b
   |(HApp(a,b),HApp(c,d))=>equalAbstract a c andalso equalAbstract b d
   |(HVAp(a,xs),HVAp(b,ys))=>equalAbstract a b andalso equalLists equalAbstract xs ys
   |(HLam(xs,a),HLam(ys,b))=>equalLists equalName xs ys andalso equalAbstract a b
   |(HMeet xs,HMeet ys)=>equalLists equalAbstract xs ys
   |(HTable xs,HTable ys)=>equalLists(fn x=>fn y=>
        let val(a,b)=force x val(c,d)=force y in equalRoute a c andalso equalAbstract b d end)xs ys
   |_=>false
 fun vectorizeAbstract expression:hexpr=D.delay(fn()=>case force expression of
    HLam(variables,body)=>(case force body of HLam(more,body)=>
         force(vectorizeAbstract(cell(HLam(F.append variables more,body))))
       |_=>HLam(variables,vectorizeAbstract body))
   |HApp(f,arg)=>(case force f of HTable table=>
         HApp(cell(HTable(mapSecond vectorizeAbstract table)),vectorizeAbstract arg)
       |_=>case force(vectorizeAbstract f)of
          HVAp(function,args)=>HVAp(function,F.append args(singleton(vectorizeAbstract arg)))
         |HPoint point=>HVAp(cell(HPoint point),singleton(vectorizeAbstract arg))
         |HVar variable=>HVAp(cell(HVar variable),singleton(vectorizeAbstract arg))
         |other=>HApp(cell other,vectorizeAbstract arg))
   |HVar _=>force expression|HPoint _=>force expression
   |HMeet expressions=>HMeet(map vectorizeAbstract expressions)|_=>raise Match)
 fun optimizeAbstract expression:hexpr=D.delay(fn()=>case force expression of
    HMeet expressions=>force(optimizeAbstractMeet expressions)
   |HApp(a,b)=>force(optimizeAbstractApplication(optimizeAbstract a)(optimizeAbstract b))
   |HPoint _=>force expression|HVar _=>force expression
   |HLam(variables,body)=>HLam(variables,optimizeAbstract body)
   |HTable table=>HTable(mapSecond optimizeAbstract table)|_=>raise Match)
 and optimizeAbstractMeet expressions:hexpr=D.delay(fn()=>
   let val simplified=map optimizeAbstract expressions
       fun split state expression=let val(literals,other)=force state
         in case force expression of HPoint p=>pair(F.cons(p,literals))other
          |_=>pair literals(F.cons(expression,other))end
       val(literals,other)=force(foldLeft split(pair(F.empty())(F.empty()))simplified)
       val literal=foldRight1 joinRoute literals
   in if null literals then HMeet simplified
      else if isTopRoute literal then HPoint literal
      else if isBottomRoute literal then force(makeAbstractMeet(cell(HPoint literal))other)
      else force(makeAbstractMeet(cell(HPoint literal))(F.cons(cell(HPoint literal),other)))end)
 and optimizeAbstractApplication left right:hexpr=D.delay(fn()=>case(force left,force right)of
    (HTable table,HPoint p)=>force(optimizeAbstract(sureLookup equalRoute table"siHOpt_app"p))
   |(HPoint f,HPoint x)=>HPoint(applyRoute f(singleton x))|_=>HApp(left,right))
 fun simplifyAbstract expression:hexpr=D.delay(fn()=>
   let val next=optimizeAbstract expression
   in if equalAbstract expression next then force expression else force(simplifyAbstract next)end)

(* analysis-support: portable source translation. *)
 fun lookupAssociation equal entries key=D.delay(fn()=>case force entries of F.Nil=>Nothing
   |F.Cons(entry,rest)=>let val(k,v)=force entry
      in if equal key k then Just v else force(lookupAssociation equal rest key)end)

 type analysisSequence=(oneFuncSize F.node F.seq*oneFuncSize F.node F.seq)L.delay
 fun staticExpressions((xs,_,_,_,_,_,_):static)=xs
 fun staticDomains((_,xs,_,_,_,_,_):static)=xs
 fun staticConstructors((_,_,xs,_,_,_,_):static)=xs
 fun staticFreeVariables((_,_,_,xs,_,_,_):static)=xs
 fun staticFlags((_,_,_,_,xs,_,_):static)=xs
 fun staticLimits((_,_,_,_,_,xs,_):static)=xs
 fun staticSizes((_,_,_,_,_,_,xs):static)=xs
 fun hasFlag statics flag=any(equalFlag(cell flag))(staticFlags statics)
 fun zip4Exact f as_ bs cs ds=zipExact(fn triple=>fn d=>
    let val(a,b,c)=force triple in f a b c d end)(zip3Exact triple as_ bs cs)ds
 fun zip5Exact f as_ bs cs ds es=zipExact(fn first=>fn e=>
    let val(a,b,c,d)=force first in f a b c d e end)
      (zip4Exact(fn a=>fn b=>fn c=>fn d=>cell(a,b,c,d))as_ bs cs ds)es
 fun cafDomain domain:domain=D.delay(fn()=>case force domain of Func _=>force domain|_=>Func(F.empty(),domain))
 fun uncafDomain domain:domain=D.delay(fn()=>case force domain of Func(args,target)=>
    if null args then force target else force domain|_=>force domain)
 fun makeFunction arguments target:domain=D.delay(fn()=>if null arguments then force target else Func(arguments,target))
 fun functionArguments domain=F.defer(fn()=>case force domain of Func(args,_)=>args|_=>raise Match)
 fun functionResult domain:domain=D.delay(fn()=>case force domain of Func(_,target)=>force target|_=>raise Match)
 fun sequenceEmpty sequence=let val(used,unused)=L.force sequence in null used end
 fun nextRecursive sequence=let val(used,unused)=L.force sequence in head used end
 fun nextNonRecursive sequence=head(nextRecursive sequence)
 fun sequenceTail sequence=L.delay(fn()=>let val(used,unused)=L.force sequence in(tail used,unused)end)
 fun sequenceGaveUp sequence=let val(used,unused)=L.force sequence in not(null unused)end
 fun isAnalysisResult value=case force value of SAResult _=>true|_=>false
 fun analysisResult value:route=D.delay(fn()=>case force value of SAResult(_,_,r)=>force r|_=>raise Match)
 fun makeSizeInformation sequence names=
   let val(used,unused)=L.force sequence
       val usedT=transpose used
       val unusedT=F.defer(fn()=>if null unused then map(fn _=>F.empty())usedT else transpose unused)
   in zip3Exact(fn name=>fn used=>fn unused=>cell(SASizes(name,used,unused)))names usedT unusedT end
 fun substituteAnalysis rho expression:hexpr=D.delay(fn()=>case force expression of
    HVar v=>if force(head v)= #"_"then HPoint(sureLookup equalName rho"sa(8)"v)else force expression
   |HPoint _=>force expression|HApp(a,b)=>HApp(substituteAnalysis rho a,substituteAnalysis rho b)
   |HMeet xs=>HMeet(map(substituteAnalysis rho)xs)|HLam(vs,e)=>HLam(vs,substituteAnalysis rho e)
   |HTable t=>HTable(mapSecond(substituteAnalysis rho)t)|HVAp(f,args)=>HVAp(substituteAnalysis rho f,map(substituteAnalysis rho)args))
 fun analysisGroups tree=F.defer(fn()=>let val(_,expression)=force tree
   in case force expression of ALet(recursive,defs,body)=>F.cons(pair recursive defs,analysisGroups body)|_=>F.empty()end)
 fun constructorArguments definitions=flatMap(fn definition=>
   let val(_,variables,alternatives)=force definition
       fun find v values=case force values of F.Nil=>raise Match|F.Cons(x,rest)=>
           if equalName v x then int 0 else add(int 1)(find v rest)
       fun oneExpression expr=case force expr of TDefVar v=>cell(ConstrVar(find v variables))|TDefCons _=>cell ConstrRec
   in mapSecond(map oneExpression)alternatives end)definitions

(* analysis-expression: portable source translation. *)

 fun analyzeExpression statics beta tree:hexpr=D.delay(fn()=>
   let val(dtau,expression)=force tree
   in case force expression of AConstr _=>panic"sa: AConstr encountered"|ALet _=>panic"sa: ALet encountered"
      |ANum _=>HPoint(cell One)
      |AAp(a,b)=>HApp(analyzeExpression statics beta a,analyzeExpression statics beta b)
      |ALam(variables,body)=>HLam(variables,analyzeExpression statics beta body)
      |AVar v=>
        let val first=force(head v)
            val constructor=Char.isUpper first val variable=Char.isLower first val function=first= #"_"
            val lookup=lookupAssociation equalName beta v
            val accounted=case force lookup of Just _=>true|Nothing=>false
            fun lookupResult()=case force lookup of Just e=>e|_=>raise Match
            fun instantiatedConstructor()=
              let val simple=sureLookup equalName(staticExpressions statics)"sa(5)"v
                  val usage=getDomainInstantiations simple dtau
              in constructorInstance(hasFlag statics SimpleInv)
                  (sureLookup equalName(staticConstructors statics)"sa(7)"v)simple usage end
            fun instantiatedFunction()=
              let val simple=sureLookup equalName(staticExpressions statics)"sa(5)"v
                  val usage=getDomainInstantiations simple dtau
                  val(poly,_,_,_,_)=staticLimits statics
                  val point=D.delay(fn()=>case force(lookupResult())of HPoint p=>force p|_=>raise Match)
              in makePolymorphicInstance(not(hasFlag statics NoBaraki))poly Safe simple usage point end
        in if constructor then HPoint(instantiatedConstructor())
           else if variable then if accounted then force(lookupResult())else HVar v
           else if function then if accounted then
              HPoint(instantiatedFunction())
             else HVar v
           else panic"sa(var)"end
      |ACase(switch,alternatives)=>
        let val(swtype,swexpr)=force switch
            val known=case force swexpr of AVar v=>Char.isLower(force(head v))andalso
                any(equalName v)(map(fn entry=> #1(force entry))beta)|_=>false
            fun knownPoint()=D.delay(fn()=>case force swexpr of AVar v=>
                (case force(sureLookup equalName beta"sa(??)"v)of HPoint p=>force p|_=>raise Match)|_=>raise Match)
            val swdomain=defaultDomain swtype
            val points=allRoutes swdomain
            val top=topRoute swdomain
            val bottom=cell(HPoint(bottomRoute(defaultDomain dtau)))
            val names=map(fn entry=> #1(force entry))alternatives
            val simple=map(sureLookup equalName(staticExpressions statics)"sa(9)")names
            val simpleTargets=map(fn d=>D.delay(fn()=>case force d of DXFunc(_,target)=>force target|_=>force d))simple
            val instances=map(fn d=>getDomainInstantiations d swtype)simpleTargets
            val domains=zipExact applyDomainSubstitution instances simple
            val components=map(sureLookup equalName(staticConstructors statics)"sa(10)")names
            val actual=zip3Exact(constructorInstance(hasFlag statics SimpleInv))components simple instances
            val indices=intsFromTo(int 0)(subtract(length alternatives)(int 1))
            val info=map(fn n=>
              let val con=nth actual n val domain=nth domains n
                  val(_,alternative)=force(nth alternatives n)
                  val(params,rhs)=force alternative
                  val caf=cell(case force con of Rep _=>false|_=>true)
              in cell(con,domain,caf,params,rhs)end)indices
            fun inverse con domain caf point=F.defer(fn()=>if force caf then
                if equalRoute point top then singleton(F.empty())else F.empty()
              else map(fn frel=>let val MkFrel args=force frel in args end)
                (maximumInverse(hasFlag statics SimpleInv)domain con point))
            fun outval point=
              let fun one n=
                    let val(con,domain,caf,params,rhs)=force(nth info n)
                        val envs=map(fn args=>zipExact pair params(map(fn p=>cell(HPoint p))args))(inverse con domain caf point)
                    in map(fn env=>analyzeExpression statics(F.append env beta)rhs)envs end
                  val value=makeAbstractMeet bottom(flatMap one indices)
              in pair point value end
        in if known andalso not(hasFlag statics NoCaseOpt)then
              force(#2(force(outval(knownPoint()))))
           else HApp(cell(HTable(map outval points)),analyzeExpression statics beta switch)end
   end)

(* analysis-search: portable source translation. *)

 fun finalExpansion statics finalDomains currentDomains safe=
   let val(_,mono,_,_,_)=staticLimits statics
       val differences=zipExact(fn final=>fn current=>
           let val(expression,substitution)=domainDifference final current in pair expression substitution end)finalDomains currentDomains
   in zipExact(fn info=>fn point=>let val(expression,substitution)=force info
       in makePolymorphicInstance false mono Safe expression substitution point end)differences safe end
 fun nonRecursiveSearch statics name sequence oldArgs target finalArgs oldSafe oldLive tree=F.defer(fn()=>
   let val finished=sequenceEmpty(sequenceTail sequence)
       val(size,args)=force(nextNonRecursive sequence)
       val domain=makeFunction args target
       val finalDomain=makeFunction finalArgs target
       val oldDomain=makeFunction oldArgs target
       val safeInitializer=concretize Live domain oldDomain oldSafe
       val liveInitializer=concretize Safe domain oldDomain oldLive
       val safe=makeFrontierRepresentation Safe false tree domain finalArgs liveInitializer safeInitializer
       val live=makeFrontierRepresentation Live false tree domain finalArgs liveInitializer safeInitializer
       val nextSafe=D.delay(fn()=>force(#1(L.force safe)))
       val nextLive=D.delay(fn()=>force(#1(L.force live)))
       val safeEvals=D.delay(fn()=>force(#2(L.force safe)))
       val liveEvals=D.delay(fn()=>force(#2(L.force live)))
       val commentary=F.fromList[SASearch(Safe,name,size,safeEvals),SASearch(Live,name,size,liveEvals)]
       val done=F.defer(fn()=>if sequenceGaveUp sequence then
           let val expanded=head(finalExpansion statics(singleton finalDomain)(singleton oldDomain)(singleton oldSafe))
               val result=cell(SAResult(name,finalDomain,expanded))
           in F.cons(cell(SAGiveUp(singleton name)),singleton result)end
         else singleton(cell(SAResult(name,finalDomain,nextSafe))))
       val rest=F.defer(fn()=>if finished then done else
           nonRecursiveSearch statics name(sequenceTail sequence)args target finalArgs nextSafe nextLive tree)
   in F.append commentary rest end)
 fun nonRecursiveStartup statics name domain tree=F.defer(fn()=>
   let val args=functionArguments domain
       val(_,_,low,high,scale)=staticLimits statics
       val sequence=sizeSequence(staticSizes statics)scale(singleton args)low high
       val(_,initialArgs)=force(nextNonRecursive sequence)
       val target=functionResult domain
       val initial=makeFunction initialArgs target
       val result=nonRecursiveSearch statics name sequence initialArgs target args(bottomRoute initial)(topRoute initial)tree
   in F.append(makeSizeInformation sequence(singleton name))result end)
 fun fixAtSizeLive statics live names domains bigArgs targets trees minOne maxZero sizes level=F.defer(fn()=>
   let val bigDomains=zipExact makeFunction bigArgs targets
       val bigLive=zip3Exact(concretize Live)bigDomains domains live
       val beta=zipExact pair names bigLive
       val treesOriginal=trees
       val trees=map(substituteAnalysis beta)trees
       val nextWithCounts=zip5Exact(fn tree=>fn domain=>fn args=>fn lower=>fn upper=>
            let val result=makeFrontierRepresentation Live(equalInt level(int 0))tree domain args lower upper
            in pair(D.delay(fn()=>force(#1(L.force result))))(D.delay(fn()=>force(#2(L.force result))))end)
               trees domains bigArgs minOne live
       val(next,counts)=unzip nextWithCounts
       val fixed=andWith equalRoute next live
       val commentary=zip3Exact(fn name=>fn size=>fn count=>cell(SASearch(Live,name,size,count)))names sizes counts
       val rest=F.defer(fn()=>if fixed then fixAtSizeSafe statics next next names domains bigArgs targets treesOriginal minOne maxZero sizes level
              else fixAtSizeLive statics next names domains bigArgs targets treesOriginal minOne maxZero sizes level)
       (* Keep the unsubstituted trees for the next fixed-point iteration. *)
   in F.append commentary rest end)
 and fixAtSizeSafe statics safe liveFixes names domains bigArgs targets trees minOne maxZero sizes level=F.defer(fn()=>
   let val bigDomains=zipExact makeFunction bigArgs targets
       val bigSafe=zip3Exact(concretize Safe)bigDomains domains safe
       val beta=zipExact pair names bigSafe
       val changed=map(substituteAnalysis beta)trees
       val nextWithCounts=zip5Exact(fn tree=>fn domain=>fn args=>fn lower=>fn upper=>
            let val result=makeFrontierRepresentation Safe(equalInt level(int 0))tree domain args lower upper
            in pair(D.delay(fn()=>force(#1(L.force result))))(D.delay(fn()=>force(#2(L.force result))))end)
               changed domains bigArgs minOne safe
       val(next,counts)=unzip nextWithCounts
       val fixed=andWith equalRoute next safe
       val commentary=zip3Exact(fn name=>fn size=>fn count=>cell(SASearch(Safe,name,size,count)))names sizes counts
       val rest=F.defer(fn()=>if fixed then singleton(cell(SASL(safe,liveFixes)))
           else fixAtSizeSafe statics next liveFixes names domains bigArgs targets trees minOne maxZero sizes level)
   in F.append commentary rest end)
 fun fixMain statics names sequence previousArgs targets finalArgs previousSafe previousLive trees level=F.defer(fn()=>
   let val previousDomains=zipExact makeFunction previousArgs targets
       val finalDomains=zipExact makeFunction finalArgs targets
   in if sequenceEmpty sequence then
       let val gaveUp=sequenceGaveUp sequence
           val points=if gaveUp then finalExpansion statics finalDomains previousDomains previousSafe else previousSafe
           val results=zip3Exact(fn name=>fn domain=>fn route=>cell(SAResult(name,domain,route)))names finalDomains points
       in if gaveUp then F.cons(cell(SAGiveUp names),results)else results end
      else
       let val sizesAndArgs=nextRecursive sequence
           val args=map(fn entry=> #2(force entry))sizesAndArgs
           val sizes=map(fn entry=> #1(force entry))sizesAndArgs
           val domains=zipExact makeFunction args targets
           val currentSafe=zip3Exact(concretize Safe)domains previousDomains previousSafe
           val currentLive=zip3Exact(concretize Live)domains previousDomains previousLive
           val info=fixAtSizeLive statics currentLive names domains finalArgs targets trees currentSafe currentLive sizes level
           val fixes=L.delay(fn()=>case force(last info)of SASL(safe,live)=>(safe,live)|_=>raise Match)
           val safe=F.defer(fn()=> #1(L.force fixes))
           val live=F.defer(fn()=> #2(L.force fixes))
           val rest=fixMain statics names(sequenceTail sequence)args targets finalArgs safe live trees(add level(int 1))
       in F.append(init info)rest end end)
 fun fixStartup statics names domains trees=F.defer(fn()=>
   let val finalArgs=map functionArguments domains
       val(_,_,low,high,scale)=staticLimits statics
       val sequence=sizeSequence(staticSizes statics)scale finalArgs low high
       val initialArgs=map(fn entry=> #2(force entry))(nextRecursive sequence)
       val targets=map functionResult domains
       val initialDomains=zipExact makeFunction initialArgs targets
       val bottoms=map bottomRoute initialDomains
       val result=fixMain statics names sequence initialArgs targets finalArgs bottoms bottoms trees(int 0)
   in F.append(makeSizeInformation sequence names)result end)
 fun analyzeGroups statics beta groups=F.defer(fn()=>case force groups of F.Nil=>F.empty()
   |F.Cons(group,rest)=>
     let val(recursive,definitions)=force group
         fun optimize expr=if hasFlag statics Simp then simplifyAbstract expr else expr
     in if not(force recursive)then
        let val(defname,rhs)=force(head definitions)
            val _=if null(tail definitions)then()else raise Match
            val tree=vectorizeAbstract(optimize(analyzeExpression statics beta rhs))
            val domain=cafDomain(sureLookup equalName(staticDomains statics)"sa(2)"defname)
            val search=nonRecursiveStartup statics defname domain tree
            val route=analysisResult(last search)
            val augmented=F.cons(pair defname(cell(HPoint route)),beta)
            val following=analyzeGroups statics augmented rest
            val commentary=if hasFlag statics ShowHExpr then singleton(cell(SAHExpr(defname,tree)))else F.empty()
        in F.append commentary(F.append search following)end
       else
        let val names=map(fn entry=> #1(force entry))definitions
            val rhss=map(fn entry=> #2(force entry))definitions
            val trees=map(fn rhs=>vectorizeAbstract(optimize(analyzeExpression statics beta rhs)))rhss
            val domains=map(sureLookup equalName(staticDomains statics)"sa(4)")names
            val result=fixStartup statics names(map cafDomain domains)trees
            val fixes=map analysisResult(filter isAnalysisResult result)
            val augmented=F.append(zipExact(fn name=>fn point=>pair name(cell(HPoint point)))names fixes)beta
            val following=analyzeGroups statics augmented rest
            val commentary=if hasFlag statics ShowHExpr then
                zipExact(fn name=>fn tree=>cell(SAHExpr(name,tree)))names trees else F.empty()
        in F.append commentary(F.append result following)end end)
 fun undoCAFInformation values=flatMap(fn value=>case force value of
    SAResult(name,domain,point)=>singleton(cell(SAResult(name,uncafDomain domain,point)))
   |SASearch(_,_,size,_)=>if less size(int 2)then F.empty()else singleton value
   |SASizes(_,used,unused)=>
       if null unused andalso isSingletonList used then
          let val(_,args)=force(head used)in if null args then F.empty()else singleton value end
       else singleton value
   |SAHExpr _=>singleton value|SAGiveUp _=>singleton value|_=>raise Match)values

(* render: portable source translation. *)

 fun text s=name s
 fun appendText xs ys=F.append xs ys
 fun textConcat xs=concat(List.foldr(fn(x,rest)=>F.cons(x,rest))(F.empty())xs)
 fun renderList render values=textConcat[text"[",interleave(text",")(map render values),text"]"]
 fun parenthesize depth value=if depth>10 then textConcat[text"(",value,text")"]else value
 fun renderInteger value=name(signed value)
 fun renderQuoted value=
   let fun escape c=case force c of #"\""=>text"\\\""| #"\\"=>text"\\\\"| #"\n"=>text"\\n"
         | #"\r"=>text"\\r"| #"\t"=>text"\\t"|c=>singleton(cell c)
   in textConcat[text"\"",flatMap escape value,text"\""]end
 fun renderDomain depth domain=F.defer(fn()=>case force domain of Two=>text"Two"
   |Lift1 ds=>parenthesize depth(textConcat[text"Lift1 ",renderList(renderDomain 0)ds])
   |Lift2 ds=>parenthesize depth(textConcat[text"Lift2 ",renderList(renderDomain 0)ds])
   |Func(ds,result)=>parenthesize depth(textConcat[text"Func ",renderList(renderDomain 0)ds,text" ",renderDomain 11 result]))
 fun renderRoute depth point=F.defer(fn()=>case force point of
    Zero=>text"Zero"|One=>text"One"|Stop1=>text"Stop1"|Stop2=>text"Stop2"|Up2=>text"Up2"
   |Up1 rs=>parenthesize depth(textConcat[text"Up1 ",renderList(renderRoute 0)rs])
   |UpUp2 rs=>parenthesize depth(textConcat[text"UpUp2 ",renderList(renderRoute 0)rs])
   |Rep rep=>parenthesize depth(textConcat[text"Rep ",renderRepresentation 11 rep]))
 and renderRepresentation depth rep=F.defer(fn()=>case force rep of
    RepTwo f=>parenthesize depth(textConcat[text"RepTwo ",renderFrontier 11 f])
   |Rep1(f,highs)=>parenthesize depth(textConcat[text"Rep1 ",renderFrontier 11 f,text" ",renderList(renderRepresentation 0)highs])
   |Rep2(f,m,highs)=>parenthesize depth(textConcat[text"Rep2 ",renderFrontier 11 f,text" ",renderFrontier 11 m,
        text" ",renderList(renderRepresentation 0)highs]))
 and renderFrontier depth frontier=F.defer(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier
   in parenthesize depth(textConcat[text"Min1Max0 ",renderInteger arity,text" ",renderList(renderFrel 0)ones,
       text" ",renderList(renderFrel 0)zeros])end)
 and renderFrel depth frel=F.defer(fn()=>let val MkFrel rs=force frel
   in parenthesize depth(textConcat[text"MkFrel ",renderList(renderRoute 0)rs])end)
 fun renderAbstract depth expression=F.defer(fn()=>case force expression of
    HVar v=>parenthesize depth(textConcat[text"HVar ",renderQuoted v])
   |HPoint p=>parenthesize depth(textConcat[text"HPoint ",renderRoute 11 p])
   |HLam(vs,e)=>parenthesize depth(textConcat[text"HLam ",renderList renderQuoted vs,text" ",renderAbstract 11 e])
   |HApp(a,b)=>parenthesize depth(textConcat[text"HApp ",renderAbstract 11 a,text" ",renderAbstract 11 b])
   |HVAp(f,args)=>parenthesize depth(textConcat[text"HVAp ",renderAbstract 11 f,text" ",renderList(renderAbstract 0)args])
   |HMeet es=>parenthesize depth(textConcat[text"HMeet ",renderList(renderAbstract 0)es])
   |HTable entries=>parenthesize depth(textConcat[text"HTable ",renderList(fn entry=>
      let val(point,e)=force entry in textConcat[text"(",renderRoute 0 point,text",",renderAbstract 0 e,text")"]end)entries]))
 type outputSequence=integer->integer->name
 type indentSequence=outputSequence->outputSequence
 fun emptyOutput indent column=F.empty()
 fun emptyIndent rest=rest
 fun appendIndent left right rest=left(right rest)
 fun indentCharacter character rest indent column=F.defer(fn()=>case character of #"\n"=>
     F.cons(cell character,rest indent(int 0))
   |_=>if leq indent column then F.cons(cell character,rest indent(add column(int 1)))
       else F.append(copy(subtract indent column)(cell #" "))
          (F.cons(cell character,rest indent(add indent(int 1)))))
 fun indentText chars rest indent column=F.defer(fn()=>case force chars of F.Nil=>rest indent column
   |F.Cons(c,cs)=>indentCharacter(force c)(indentText cs rest)indent column)
 fun indentString s=indentText(text s)
 fun indentBlock block rest indent column=
   let val base=if less indent column then column else indent
       fun after _ finalColumn=rest indent finalColumn
   in block after base column end
 fun indentInterleave separator blocks rest indent column=
   let fun join blocks=case force blocks of F.Nil=>emptyIndent|F.Cons(block,others)=>
       if null others then force block else appendIndent(force block)(appendIndent separator(join others))
   in join blocks rest indent column end
 fun renderIndent block=block emptyOutput(int 0)(int 0)

 fun combineIndent blocks=List.foldr(fn(a,b)=>appendIndent a b)emptyIndent blocks
 fun prettyCore expression:indentSequence=fn rest=>fn indent=>fn column=>
   let fun run blocks=combineIndent blocks rest indent column
       fun parens e=combineIndent[indentString"(",prettyCore e,indentString")"]
       fun right e=case force e of EVar _=>prettyCore e|ENum _=>prettyCore e|EConstr _=>prettyCore e|_=>parens e
       fun left e=case force e of EAp _=>prettyCore e|_=>right e
   in case force expression of EVar n=>run[indentText n]|EConstr n=>run[indentText n]
      |ENum n=>run[indentText(renderInteger n)]
      |EAp(a,b)=>run[left a,indentString" ",right b]
      |ELam(vs,body)=>run[indentString"\\",
          indentInterleave(indentString" ")(map(fn n=>cell(indentText n))vs),
          indentString" -> ",indentBlock(prettyCore body)]
      |ELet(recursive,defs,body)=>
        let val recText=if force recursive then"rec\n  "else"\n  "
            val blocks=map(fn entry=>let val(n,e)=force entry
                in cell(combineIndent[indentText n,indentString" = ",prettyCore e])end)defs
        in run[indentString"let",indentString recText,
             indentBlock(indentInterleave(indentString";\n")blocks),indentString"\nin ",prettyCore body]end
      |ECase(sw,alts)=>
        let val blocks=map(fn entry=>let val(n,alternative)=force entry val(args,e)=force alternative
          in cell(combineIndent[indentString"  ",indentText n,indentString" ",
             indentInterleave(indentString" ")(map(fn n=>cell(indentText n))args),
             indentString" -> ",indentBlock(prettyCore e)])end)alts
        in run[indentString"case ",prettyCore sw,indentString" of\n",
           indentBlock(indentInterleave(indentString";\n")blocks),indentString"\nend"]end
   end
 fun prettyTypeExpression expression:indentSequence=fn rest=>fn indent=>fn column=>
   case force expression of TDefVar n=>indentText n rest indent column
     |TDefCons(n,args)=>combineIndent[indentString"(",indentText n,indentString" ",
        indentInterleave(indentString" ")(map(fn e=>cell(prettyTypeExpression e))args),indentString")"]rest indent column
 fun prettyTypeDefinition definition=
   let val(n,variables,constructors)=force definition
       val alternatives=map(fn alternative=>let val(n,args)=force alternative
         in cell(combineIndent[indentText n,indentString" ",
              indentInterleave(indentString" ")(map(fn e=>cell(prettyTypeExpression e))args)])end)constructors
   in renderIndent(combineIndent[indentText n,indentString" ",
      indentInterleave(indentString" ")(map(fn v=>cell(indentText v))variables),
      indentString" ::= ",indentBlock(indentInterleave(indentString" |\n")alternatives)])end
 fun prettyParsed types expression=F.append(flatMap(fn t=>textConcat[text"\n",prettyTypeDefinition t,text";\n\n"])types)
    (F.append(text";;\n\n")(renderIndent(prettyCore expression)))

(* print-results: portable source translation. *)

 fun justify width chars=F.append(copy(subtract width(length chars))(cell #" "))chars
 fun numberedLines values=
   let fun loop n values=F.defer(fn()=>case force values of F.Nil=>F.empty()
         |F.Cons(x,rest)=>textConcat[justify(int 4)(renderInteger n),text") ",x,text"\n",loop(add n(int 1))rest])
   in loop(int 1)values end
 fun minInteger a b=if less a b then a else b
 fun maxInteger a b=if less a b then b else a
 fun listMinimum values=foldLeft minInteger(head values)(tail values)
 fun listMaximum values=foldLeft maxInteger(head values)(tail values)
 fun liftPrintedDomain points=
   let val width=length(head points)
       val bottom=subtract(listMinimum(concat points))(int 1)
   in F.cons(copy width bottom,points)end
 fun crossPrintedDomain xs ys=flatMap(fn x=>map(fn y=>F.append x y)ys)xs
 fun crossPrintedDomains values=F.defer(fn()=>case force values of F.Nil=>singleton(singleton(int 0))
   |F.Cons(x,rest)=>if null rest then x else crossPrintedDomain x(crossPrintedDomains rest))
 (* Preserve source [[-1],[0]], product order, and repeated lifting. *)
 fun printedDomain domain=F.defer(fn()=>case force domain of
    Two=>F.cons(singleton(int ~1),singleton(singleton(int 0)))
   |Lift1 ds=>liftPrintedDomain(crossPrintedDomains(map printedDomain ds))
   |Lift2 ds=>liftPrintedDomain(liftPrintedDomain(crossPrintedDomains(map printedDomain ds)))|_=>raise Match)
 fun printAllPoints domain=
   let val points=printedDomain domain
       val minimum=listMinimum(concat points)
       fun character n=cell(Char.chr(small(add n(int 48))))
       val normalized=map(fn row=>map(fn n=>subtract n minimum)row)points
       val rows=map(map character)normalized
   in textConcat[text"{",interleave(text" ")rows,text"}"]end
 fun printedWidth domain:integer=D.delay(fn()=>case force domain of Two=>force(int 1)
   |Lift1 ds=>force(foldLeft add(int 0)(map printedWidth ds))
   |Lift2 ds=>force(foldLeft add(int 0)(map printedWidth ds))|_=>raise Match)
 fun printedLifts domain:integer=D.delay(fn()=>case force domain of Two=>force(int 2)
   |Lift1 ds=>force(add(int 1)(listMaximum(map printedLifts ds)))
   |Lift2 ds=>force(add(int 2)(listMaximum(map printedLifts ds)))|_=>raise Match)
 fun printedRoute domain route=F.defer(fn()=>case(force domain,force route)of
    (Two,Zero)=>singleton(int 0)|(Two,One)=>singleton(int 1)
   |(Lift1 _,Stop1)=>copy(printedWidth domain)(int 0)
   |(Lift1 ds,Up1 rs)=>map(add(int 1))(printedCrossRoutes ds rs)
   |(Lift2 _,Stop2)=>copy(printedWidth domain)(int 0)
   |(Lift2 _,Up2)=>copy(printedWidth domain)(int 1)
   |(Lift2 ds,UpUp2 rs)=>map(add(int 2))(printedCrossRoutes ds rs)|_=>raise Match)
 and printedCrossRoutes domains routes=
   let val unadjusted=zipExact printedRoute domains routes
       val factors=map printedLifts domains
       val maximum=listMaximum factors
       val normalized=map(subtract maximum)factors
       val fixed=zipExact(fn n=>fn route=>map(add n)route)normalized unadjusted
   in concat fixed end
 fun printRoute domain route=map(fn n=>cell(Char.chr(small(add n(int 48)))))(printedRoute domain route)
 fun printFunction mindless statics fname domain point=F.defer(fn()=>
   case(force domain,force point)of(Func(args,target),Rep rep)=>
     if isHigherOrderFunction domain orelse hasFlag statics NoFormat then
       textConcat[text"\nFunction ",renderQuoted fname,text" has input domains:\n",
          numberedLines(map(renderDomain 0)args),text"   and output domain\n      ",
          renderDomain 0 target,text"\n\nwith value:\n\n",renderRepresentation 0 rep,text"\n\n"]
     else
       let val params=sureLookup equalName(staticFreeVariables statics)"prPrintFunction"fname
           val prettyArgs=map printAllPoints args
           fun labelled params domains=F.defer(fn()=>case force domains of F.Nil=>F.empty()
             |F.Cons(domain,rest)=>case force params of F.Nil=>F.cons(domain,labelled params rest)
                |F.Cons(n,ns)=>F.cons(if null n then domain else
                     textConcat[domain,text" (free ",renderQuoted n,text")"],labelled ns rest))
           val numbered=numberedLines(labelled params prettyArgs)
           val outputs=reverse(insertionSort compareRoute(allRoutes target))
           fun row output=
             let val inverses=minimumInverse mindless domain(cell(Rep rep))output
                 val column=printRoute target output
                 fun lower value=let val MkFrel routes=force value
                    in interleave(text" ")(zipExact printRoute args routes)end
             in textConcat[copy(subtract(int 8)(length column))(cell #" "),column,text"   |  ",
                  interleave(text" and ")(map lower inverses),text"\n"]end
       in textConcat[text"\nFunction ",renderQuoted fname,text" has input domains:\n",numbered,
           text"   and output domain\n      ",printAllPoints target,
           text"\n\n   Output  |  Lower frontier\n   --------+----------------\n",flatMap row outputs,text"\n\n"]end
    |_=>
       if containsFunctions domain then
          textConcat[text"\nFunction ",renderQuoted fname,text" is a higher-order constant (yuck) in domain\n\n",
            renderDomain 0 domain,text"\n\nof value\n\n",renderRoute 0 point,text"\n\n"]
       else textConcat[text"\nFunction ",renderQuoted fname,text" is a constant point ",printRoute domain point,
          text" in domain \n    ",printAllPoints domain,text"\n\n"])
 fun printSizeRows used values=flatMap(fn value=>let val(size,domains)=force value
   in textConcat[justify(int 8)(renderInteger size),text" ",text(if used then" "else"*"),text" ",
       renderList(renderDomain 0)domains,text"\n"]end)values
 fun printAnalysisInformation statics mindless info=F.defer(fn()=>case force info of
    SAResult(name,domain,point)=>printFunction mindless statics name domain point
   |SASearch(mode,name,size,count)=>textConcat[text"Evaluated at size ",justify(int 7)(renderInteger size),
       text" using ",justify(int 4)(renderInteger count),text" evals ",text(case mode of Safe=>"safe"|Live=>"live"),
       text" ",renderQuoted name,text"\n"]
   |SASizes(name,used,unused)=>textConcat[text"\nDomains for ",renderQuoted name,text" are\n",
       printSizeRows true used,printSizeRows false unused,text"\n"]
   |SAHExpr(name,tree)=>textConcat[text"\nAbstract tree for ",renderQuoted name,text" is\n\n",renderAbstract 0 tree,text"\n\n"]
   |SAGiveUp names=>textConcat[text"Giving up on ",interleave(text" and ")(map renderQuoted names),text".\n"]
   |_=>raise Match)
 fun settingInformation poly mono low high scale mindless baraki=
   textConcat[text"\n================\n=== Settings ===\n================\n\nScaleup ratio = ",renderInteger scale,
     text"/10\nLower lattice size limit = ",renderInteger low,text"\nUpper lattice size limit = ",renderInteger high,
     if baraki then textConcat[text"\nPolymorphic generalisation limit = ",renderInteger poly]
       else text"\nNot using Gebreselassie Baraki's generalisation technique.",
     text(if mindless then"\nUsing inefficient inverses"else""),
     text"\n\n\n==================\n=== Strictness ===\n==================\n"]

(* analysis-prepare: portable source translation. *)

 val baseAnnotations:(name*hexpr)F.seq=
   let fun frel rs=cell(MkFrel(F.fromList rs))
       fun point arity ones zeros=
          let val frontier=makeFrontier(int arity)ones zeros
              val representation=cell(RepTwo frontier)
              val route=cell(Rep representation)
          in cell(HPoint route)end
       val unary=point 1(singleton(frel[One]))(singleton(frel[Zero]))
       val binary=point 2(singleton(frel[One,One]))(F.cons(frel[Zero,One],singleton(frel[One,Zero])))
       val parallelOr=point 2(F.cons(frel[Zero,One],singleton(frel[One,Zero])))(singleton(frel[Zero,Zero]))
       val items=[("_not",unary),("_+",binary),("_-",binary),("_*",binary),("_/",binary),("_%",binary),
          ("_<",binary),("_<=",binary),("_==",binary),("_~=",binary),("_>=",binary),("_>",binary),
          ("_|",binary),("_&",binary),("_#",parallelOr),("False",cell(HPoint(cell One))),("True",cell(HPoint(cell One)))]
   in F.fromList(List.map(fn(n,value)=>(name n,value))items)end
 val defaultSettings:flags=F.fromList[PolyLim(int 10000),MonoLim(int 10000),LowerLim(int 0),UpperLim(int 1000000),ScaleUp(int 20)]
 fun prepareAnalysisDetailed contents table flags=
   let val(dar,atomic)=parseCore contents
       val(types,expression)=force atomic
       val builtins=map(fn entry=> #1(force entry))baseAnnotations
       val lifted=lambdaLift builtins expression(not(member equalFlag(cell NoPretty)flags))
       val(program,parameters)=L.force lifted
       val(words,checked)=checkTypes baseTypes(singleton(int 1),singleton(int 0))(pair types program)
       val(tree,environment)=case L.force checked of Ok value=>force value|_=>panic"maStrictAn: Typecheck failed -- cannot proceed."
       val typed=etaAbstract tree
       val boolDefinition=cell(name"bool",F.empty(),
           F.fromList[(name"True",F.empty()),(name"False",F.empty())])
       val definitions=F.cons(boolDefinition,types)
       val groups=F.cons(pair(cell false)(singleton(name"bool")),dar)
       val fullEnv=F.append environment(mapSecond(fn scheme=>D.delay(fn()=>case force scheme of Scheme(_,t)=>force t))baseTypes)
       val simple=mapSecond(typeToDomainExpression groups)fullEnv
       val domains=mapSecond defaultDomain simple
       fun flagValue predicate extract=extract(force(head(filter(fn f=>predicate(force f))flags)))
       val poly=flagValue(fn PolyLim _=>true|_=>false)(fn PolyLim n=>n|_=>raise Match)
       val mono=flagValue(fn MonoLim _=>true|_=>false)(fn MonoLim n=>n|_=>raise Match)
       val low=flagValue(fn LowerLim _=>true|_=>false)(fn LowerLim n=>n|_=>raise Match)
       val high=flagValue(fn UpperLim _=>true|_=>false)(fn UpperLim n=>n|_=>raise Match)
       val scale=flagValue(fn ScaleUp _=>true|_=>false)(fn ScaleUp n=>n|_=>raise Match)
       val statics:static=(simple,domains,constructorArguments definitions,parameters,flags,
          (poly,mono,low,high,scale),table)
       val recursiveGroups=analysisGroups(typedToDomainTree groups typed)
   in(statics,undoCAFInformation(analyzeGroups statics baseAnnotations recursiveGroups),
       prettyParsed types program,words)end
 fun prepareAnalysis contents table=
   let val(statics,result,_,_)=prepareAnalysisDetailed(input contents)table defaultSettings
   in(statics,result)end

(* main: portable source translation. *)

 val dryRunSettings:flags=F.fromList[NoBaraki,LowerLim(int 0),UpperLim(int 0),PolyLim(int 1),MonoLim(int 1),ScaleUp(int 20)]
 fun augmentFlags flags=if member equalFlag(cell DryRun)flags then
      F.append dryRunSettings(F.append flags defaultSettings)else F.append flags defaultSettings
 fun strictAnalyze table initialFlags contents=
   let val flags=augmentFlags initialFlags
       val prepared=L.delay(fn()=>prepareAnalysisDetailed contents table flags)
       fun statics()=let val(s,_,_,_)=L.force prepared in s end
       val pretty=F.defer(fn()=>let val(_,_,p,_)=L.force prepared in p end)
       val words=F.defer(fn()=>let val(_,_,_,w)=L.force prepared in w end)
       val analyzed=F.defer(fn()=>if member equalFlag(cell Typecheck)flags then F.empty()
          else let val(s,records,_,_)=L.force prepared
                   val(poly,mono,low,high,scale)=staticLimits s
                   val mindless=hasFlag s SimpleInv
                   val baraki=not(hasFlag s NoBaraki)
               in F.append(settingInformation poly mono low high scale mindless baraki)
                     (flatMap(printAnalysisInformation s mindless)records)end)
   in textConcat[text"\nJules's Strictness Analyser, version 0.400",
      text"\nCopyright (c) Julian Seward 1992\nRead ",renderInteger(length table),text" lattice sizes.\n",
      text"\n\n=============\n=== Input ===\n=============\n",pretty,
      text"\n\n\n=============\n=== Types ===\n=============\n",words,text"\n\n",analyzed,text"\n"]end

(* benchmark: portable source translation. *)

 type input=char C.seq
 type table=(domain*integer)F.seq
 fun benchmark chars table=
   let val report=strictAnalyze table(F.empty())chars
       fun hash value chars=case force chars of F.Nil=>value
         |F.Cons(c,rest)=>hash(W.+(W.*(value,0w31),W.fromInt(Char.ord(force c))))rest
   in hash 0w0 report end
 fun signedHash word=signed(cell word)

end
